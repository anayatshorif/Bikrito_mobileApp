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
          onNewOrder: () async => null,
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

  testWidgets('orders page opens e-commerce order creation', (tester) async {
    var createOrderTapped = false;
    final navigatedTabs = <int>[];
    await tester.pumpWidget(
      MaterialApp(
        home: OrdersScreen(
          orders: const [],
          profile: const ShopProfile(owner: 'Amina', shop: 'Store', phone: ''),
          bangla: false,
          t: (en, _) => en,
          onNavigate: navigatedTabs.add,
          onNewOrder: () async {
            createOrderTapped = true;
            return SaleRecord(
              id: 8,
              items: const [],
              subtotal: 100,
              discount: 0,
              total: 100,
              paymentMethod: 'cod',
              createdAt: DateTime(2026, 11, 26),
              codDue: 100,
            );
          },
        ),
      ),
    );

    await tester.tap(find.text('E-Commerce order'));
    await tester.pumpAndSettle();
    expect(createOrderTapped, isTrue);
    expect(find.text('All orders  ·  1'), findsOneWidget);

    await tester.tap(find.text('Orders').last);
    expect(navigatedTabs, [2]);
  });
}
