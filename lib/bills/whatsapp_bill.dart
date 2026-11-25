import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/sale_record.dart';
import '../models/shop_profile.dart';

/// Normalises a Bangladesh mobile number to `8801XXXXXXXXX`.
String normaliseBdPhone(String input) {
  var digits = input.replaceAll(RegExp(r'\D'), '');
  if (digits.isEmpty) return '';
  if (digits.startsWith('880') && digits.length == 13) return digits;
  if (digits.startsWith('0') && digits.length == 11) {
    digits = digits.substring(1);
  }
  if (digits.startsWith('1') && digits.length == 10) {
    digits = '880$digits';
  }
  return digits;
}

String paymentLabel(String method, String Function(String, String) t) =>
    switch (method) {
      'bkash' => 'bKash',
      'nagad' => 'Nagad',
      'bank' => t('Bank', 'ব্যাংক'),
      'remaining' => t('Remaining', 'বাকি'),
      'cod' => t('Cash on delivery', 'ক্যাশ অন ডেলিভারি'),
      _ => t('Cash', 'নগদ'),
    };

double remainingSaleDue(SaleRecord sale) =>
    (sale.total - sale.advancePaid).clamp(0, double.infinity).toDouble();

String buildDueReminderText({
  required ShopProfile profile,
  required SaleRecord sale,
}) {
  final shop = profile.shop.trim().isEmpty ? 'Bikrito' : profile.shop.trim();
  final customer = sale.buyerName.trim().isEmpty
      ? 'ক্রেতা'
      : sale.buyerName.trim();
  final date = _billDate(sale.createdAt).split('  ').first;
  final total = sale.total < 0 ? 0.0 : sale.total;
  final paid = sale.advancePaid.clamp(0, total).toDouble();
  final due = remainingSaleDue(sale);
  final invoiceNumber = sale.id?.toString() ?? '';
  final contact = [
    profile.owner.trim(),
    profile.phone.trim(),
  ].where((part) => part.isNotEmpty).join('\n');

  return [
    'আসসালামু আলাইকুম,',
    '',
    'আপনার $shop দোকানের বাকি হিসাব:',
    'ক্রেতার নাম: $customer',
    'তারিখ: $date',
    'ইনভয়েস নং: #$invoiceNumber',
    'মোট বিল: ৳${_money(total)}',
    'পরিশোধ করেছেন: ৳${_money(paid)}',
    'বর্তমান বাকি: ৳${_money(due)}',
    '',
    'সুযোগমতো বাকি টাকা পরিশোধ করার অনুরোধ রইল।',
    '',
    'ধন্যবাদ ❤️',
    '',
    shop,
    if (contact.isNotEmpty) contact,
  ].join('\n');
}

String buildRemainingPaymentThankYouText({
  required ShopProfile profile,
  required SaleRecord sale,
}) {
  final shop = profile.shop.trim().isEmpty ? 'Bikrito' : profile.shop.trim();
  final customer = sale.buyerName.trim().isEmpty
      ? 'প্রিয় গ্রাহক'
      : 'প্রিয় ${sale.buyerName.trim()}';
  final contact = [
    profile.owner.trim(),
    profile.phone.trim(),
  ].where((part) => part.isNotEmpty).join('\n');

  return [
    'আসসালামু আলাইকুম,',
    '',
    '$customer,',
    '',
    'আপনার $shop দোকানের বাকি টাকা পরিশোধ করার জন্য আন্তরিক ধন্যবাদ।',
    'ইনভয়েস নং: #${sale.id ?? ''}',
    'পরিশোধের পরিমাণ: ৳${_money(remainingSaleDue(sale))}',
    '',
    'আপনার সহযোগিতার জন্য কৃতজ্ঞ।',
    '',
    'ধন্যবাদ ❤️',
    '',
    shop,
    if (contact.isNotEmpty) contact,
  ].join('\n');
}

String buildBillText({
  required ShopProfile profile,
  required SaleRecord sale,
  required String Function(String, String) t,
  bool showBranding = true,
}) {
  final lines = <String>[];
  lines.add(' *${profile.shop.trim().isEmpty ? 'Bikrito' : profile.shop.trim()}*');
  final ownerLine = [profile.owner.trim(), profile.phone.trim()]
      .where((part) => part.isNotEmpty)
      .join('  ·  ');
  if (ownerLine.isNotEmpty) lines.add(ownerLine);
  lines.add('');
  lines.add('📄 *${t('Bill', 'বিল')} #${sale.id ?? ''}*');
  lines.add(' ${_billDate(sale.createdAt)}');
  lines.add('━━━━━━━━━━━━━━━');
  for (final item in sale.items) {
    lines.add('▪️ ${item.name}  ×${item.quantity}  —  ৳${_money(item.lineTotal)}');
  }
  lines.add('━━━━━━━━━━━━━━━');
  lines.add('${t('Subtotal', 'উপমোট')}: ৳${_money(sale.subtotal)}');
  if (sale.discount > 0) {
    lines.add('${t('Discount', 'ছাড়')}: -৳${_money(sale.discount)}');
  }
  lines.add('💰 *${t('Total', 'মোট')}: ৳${_money(sale.total)}*');
  lines.add('');
  lines.add('💳 ${t('Payment', 'পেমেন্ট')}: ${paymentLabel(sale.paymentMethod, t)}');
  if (sale.buyerName.trim().isNotEmpty) {
    lines.add('👤 ${t('Buyer', 'ক্রেতা')}: ${sale.buyerName.trim()}');
  }
  if (sale.buyerPhone.trim().isNotEmpty) {
    lines.add('📞 ${t('Phone', 'ফোন')}: ${sale.buyerPhone.trim()}');
  }
  if (sale.buyerAddress.trim().isNotEmpty) {
    lines.add('🏠 ${t('Address', 'ঠিকানা')}: ${sale.buyerAddress.trim()}');
  }
  if (sale.paymentMethod == 'cod' || sale.deliveryCharge > 0 || sale.advancePaid > 0) {
    lines.add('');
    lines.add('🚚 ${t('Delivery charge', 'ডেলিভারি চার্জ')}: ৳${_money(sale.deliveryCharge)}');
    if (sale.advancePaid > 0) {
      lines.add('💵 ${t('Advance paid', 'আগাম পেইড')}: ৳${_money(sale.advancePaid)}');
    }
    lines.add('💰 *${t('COD due', 'COD বাকি')}: ৳${_money(sale.codDue)}*');
  }
  lines.add('');
  lines.add(t('Thank you for shopping!', 'কেনাকাটা করার জন্য ধন্যবাদ!'));
  if (showBranding) {
    lines.add('_${t('Bill by Bikrito', 'বিক্রিতো দিয়ে বিল')}_');
  }
  return lines.join('\n');
}

Future<void> openWhatsAppBill(
  BuildContext context, {
  required String phone,
  required String billText,
  required String Function(String, String) t,
}) async {
  final encoded = Uri.encodeComponent(billText);
  final target = phone.isEmpty
      ? 'https://wa.me/?text=$encoded'
      : 'https://wa.me/$phone?text=$encoded';
  if (kIsWeb) {
    await Clipboard.setData(ClipboardData(text: billText));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Bill copied to clipboard', 'বিল ক্লিপবোর্ডে কপি হয়েছে'),
          ),
        ),
      );
    }
    return;
  }
  try {
    final launched = await launchUrl(
      Uri.parse(target),
      mode: LaunchMode.externalApplication,
    );
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Could not open WhatsApp', 'হোয়াটসঅ্যাপ খোলা যায়নি'),
          ),
        ),
      );
    }
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Could not open WhatsApp', 'হোয়াটসঅ্যাপ খোলা যায়নি'),
          ),
        ),
      );
    }
  }
}

String _money(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

String _billDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
