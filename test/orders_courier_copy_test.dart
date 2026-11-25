import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bikrito/models/sale_record.dart';
import 'package:bikrito/models/shop_profile.dart';
import 'package:bikrito/screens/orders_screen.dart';

void main() {
  testWidgets('saved order card copies courier details without opening it', (
    tester,
  ) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText = (call.arguments as Map)['text'] as String;
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersScreen(
          orders: [
            SaleRecord(
              id: 7,
              items: const [],
              subtotal: 1000,
              discount: 0,
              total: 1150,
              paymentMethod: 'cod',
              createdAt: DateTime(2026, 11, 26),
              buyerName: 'Amina Rahman',
              buyerPhone: '8801712345678',
              buyerAddress: 'Dhanmondi, Dhaka',
              deliveryCharge: 150,
              codDue: 1150,
            ),
          ],
          profile: const ShopProfile(owner: 'Amina', shop: 'Store', phone: ''),
          bangla: false,
          t: (en, _) => en,
          onNavigate: (_) {},
        ),
      ),
    );

    await tester.tap(find.text('Copy for Courier'));
    await tester.pumpAndSettle();

    expect(find.text('Invoice'), findsNothing);
    expect(find.text('Courier details copied'), findsOneWidget);
    expect(
      copiedText,
      'Name: Amina Rahman\n'
      'Phone: 8801712345678\n'
      'Address: Dhanmondi, Dhaka\n'
      'COD Amount: ৳1150',
    );
  });
}
