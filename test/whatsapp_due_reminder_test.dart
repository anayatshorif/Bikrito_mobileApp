import 'package:flutter_test/flutter_test.dart';

import 'package:bikrito/models/sale_record.dart';
import 'package:bikrito/models/shop_profile.dart';
import 'package:bikrito/bills/whatsapp_bill.dart';

void main() {
  final profile = const ShopProfile(
    owner: 'Amina Rahman',
    shop: 'Bikrito Boutique',
    phone: '01700000000',
  );
  final sale = SaleRecord(
    id: 42,
    items: const [],
    subtotal: 1000,
    discount: 0,
    total: 1000,
    paymentMethod: 'remaining',
    createdAt: DateTime(2026, 11, 25),
    buyerName: 'Nusrat Jahan',
    advancePaid: 700,
  );

  test(
    'Bangla reminder includes invoice, payment breakdown and shop contacts',
    () {
      expect(remainingSaleDue(sale), 300);
      expect(
        buildDueReminderText(profile: profile, sale: sale),
        'আসসালামু আলাইকুম,\n'
        '\n'
        'আপনার Bikrito Boutique দোকানের বাকি হিসাব:\n'
        'ক্রেতার নাম: Nusrat Jahan\n'
        'তারিখ: 25/11/2026\n'
        'ইনভয়েস নং: #42\n'
        'মোট বিল: ৳1000\n'
        'পরিশোধ করেছেন: ৳700\n'
        'বর্তমান বাকি: ৳300\n'
        '\n'
        'সুযোগমতো বাকি টাকা পরিশোধ করার অনুরোধ রইল।\n'
        '\n'
        'ধন্যবাদ ❤️\n'
        '\n'
        'Bikrito Boutique\n'
        'Amina Rahman\n'
        '01700000000',
      );
    },
  );

  test('payment thank-you message is Bangla and confirms the remaining amount', () {
    final text = buildRemainingPaymentThankYouText(
      profile: profile,
      sale: sale,
    );

    expect(text, contains('আসসালামু আলাইকুম,'));
    expect(text, contains('প্রিয় Nusrat Jahan,'));
    expect(text, contains('ইনভয়েস নং: #42'));
    expect(text, contains('পরিশোধের পরিমাণ: ৳300'));
    expect(text, contains('বাকি টাকা পরিশোধ করার জন্য আন্তরিক ধন্যবাদ।'));
    expect(text, contains('Amina Rahman\n01700000000'));
  });
}
