import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bikrito/models/customer_history.dart';
import 'package:bikrito/models/shop_product.dart';
import 'package:bikrito/models/shop_profile.dart';
import 'package:bikrito/screens/order_screen.dart';

void main() {
  testWidgets(
    'phone lookup fills customer details and shows past order count',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: OrderScreen(
            products: const [ShopProduct(id: 1, name: 'Shirt', price: 500)],
            profile: const ShopProfile(
              owner: 'Amina',
              shop: 'Store',
              phone: '',
            ),
            bangla: false,
            t: (en, _) => en,
            onSave: (sale) async => sale,
            onFindCustomer: (phone) async {
              if (phone == '8801712345678') {
                return const CustomerHistory(
                  name: 'Amina Rahman',
                  address: 'Dhanmondi, Dhaka',
                  orderCount: 2,
                );
              }
              return null;
            },
            onNavigate: (_) {},
          ),
        ),
      );

      final phoneField = find.byKey(const ValueKey('order-customer-phone'));
      await tester.ensureVisible(phoneField);
      await tester.enterText(phoneField, '01712345678');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('order-customer-name')),
            )
            .controller!
            .text,
        'Amina Rahman',
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('order-customer-address')),
            )
            .controller!
            .text,
        'Dhanmondi, Dhaka',
      );
      expect(find.text('Past orders: 2'), findsOneWidget);

      await tester.enterText(phoneField, '01712345679');
      await tester.pump(const Duration(milliseconds: 400));
      await tester.pumpAndSettle();

      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('order-customer-name')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(
        tester
            .widget<TextField>(
              find.byKey(const ValueKey('order-customer-address')),
            )
            .controller!
            .text,
        isEmpty,
      );
      expect(find.text('Past orders: 0'), findsOneWidget);
    },
  );
}
