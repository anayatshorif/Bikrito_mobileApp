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
      _ => t('Cash', 'নগদ'),
    };

String buildBillText({
  required ShopProfile profile,
  required SaleRecord sale,
  required String Function(String, String) t,
  bool showBranding = true,
}) {
  final lines = <String>[
    profile.shop.trim().isEmpty ? 'Bikrito' : profile.shop.trim(),
  ];
  final ownerLine = [profile.owner.trim(), profile.phone.trim()]
      .where((part) => part.isNotEmpty)
      .join('  ·  ');
  if (ownerLine.isNotEmpty) lines.add(ownerLine);
  lines.add('');
  lines.add('${t('Bill', 'বিল')} #${sale.id ?? ''}');
  lines.add(_billDate(sale.createdAt));
  lines.add('--------------------------');
  for (final item in sale.items) {
    lines.add('${item.name}  x${item.quantity}  ৳${_money(item.lineTotal)}');
  }
  lines.add('--------------------------');
  lines.add('${t('Subtotal', 'উপমোট')}: ৳${_money(sale.subtotal)}');
  if (sale.discount > 0) {
    lines.add('${t('Discount', 'ছাড়')}: -৳${_money(sale.discount)}');
  }
  lines.add('${t('Total', 'মোট')}: ৳${_money(sale.total)}');
  lines.add('');
  lines.add('${t('Payment', 'পেমেন্ট')}: ${paymentLabel(sale.paymentMethod, t)}');
  if (sale.buyerName.trim().isNotEmpty) {
    lines.add('${t('Buyer', 'ক্রেতা')}: ${sale.buyerName.trim()}');
  }
  lines.add('');
  if (showBranding) {
    lines.add(t('Bill by Bikrito', 'বিক্রিতো দিয়ে বিল'));
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
