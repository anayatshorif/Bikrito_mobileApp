import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bikrito/models/sale_record.dart';
import 'package:bikrito/models/shop_product.dart';
import 'package:bikrito/models/shop_profile.dart';
import 'package:bikrito/screens/sales_screen.dart';

SaleRecord _sale({
  double total = 800,
  double discount = 100,
  String buyerName = 'Old buyer',
  String paymentMethod = 'cash',
  String buyerAddress = '',
  double deliveryCharge = 0,
  double advancePaid = 0,
  double codDue = 0,
}) => SaleRecord(
  id: 20,
  items: const [
    SaleItem(productId: 1, name: 'Shirt', unitPrice: 450, quantity: 2),
  ],
  subtotal: 900,
  discount: discount,
  total: total,
  paymentMethod: paymentMethod,
  createdAt: DateTime(2026, 11, 25),
  buyerName: buyerName,
  buyerAddress: buyerAddress,
  deliveryCharge: deliveryCharge,
  advancePaid: advancePaid,
  codDue: codDue,
);

void main() {
  testWidgets(
    'sale editor updates the existing sale and keeps its saved price',
    (tester) async {
      SaleRecord? updatedSale;
      final originalSale = _sale();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push<SaleRecord>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => SalesScreen(
                      products: const [
                        ShopProduct(id: 1, name: 'Renamed shirt', price: 500),
                      ],
                      profile: const ShopProfile(
                        owner: 'Amina',
                        shop: 'Store',
                        phone: '',
                      ),
                      bangla: false,
                      t: (en, _) => en,
                      onSave: (sale) async => sale,
                      onUpdate: (sale) async {
                        updatedSale = sale;
                        return sale;
                      },
                      initialSale: originalSale,
                      onNavigate: (_) {},
                    ),
                  ),
                ),
                child: const Text('Open editor'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open editor'));
      await tester.pumpAndSettle();
      expect(find.text('Edit sale'), findsOneWidget);

      await tester.tap(find.text('−').first);
      await tester.pump();
      await tester.drag(find.byType(ListView).first, const Offset(0, -700));
      await tester.pumpAndSettle();
      final discountField = find.byKey(const ValueKey('sale-discount'));
      await tester.ensureVisible(discountField);
      await tester.enterText(discountField, '50');
      await tester.tap(find.textContaining('Save changes'));
      await tester.pumpAndSettle();

      expect(updatedSale, isNotNull);
      expect(updatedSale!.id, originalSale.id);
      expect(updatedSale!.createdAt, originalSale.createdAt);
      expect(updatedSale!.items.single.quantity, 1);
      expect(updatedSale!.items.single.name, 'Shirt');
      expect(updatedSale!.items.single.unitPrice, 450);
      expect(updatedSale!.subtotal, 450);
      expect(updatedSale!.discount, 50);
      expect(updatedSale!.total, 400);
      expect(updatedSale!.buyerName, 'Old buyer');
    },
  );

  testWidgets('sales report exposes edit and refreshes the updated total', (
    tester,
  ) async {
    final originalSale = _sale(total: 800, discount: 100);
    SaleRecord? requestedSale;

    await tester.pumpWidget(
      MaterialApp(
        home: SalesReportsScreen(
          sales: [originalSale],
          profile: const ShopProfile(owner: 'Amina', shop: 'Store', phone: ''),
          bangla: false,
          t: (en, _) => en,
          onNavigate: (_) {},
          onNewSale: () {},
          onEditSale: (sale) async {
            requestedSale = sale;
            return _sale(total: 700, discount: 200);
          },
        ),
      ),
    );

    await tester.tap(find.text('Sale #20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit sale'));
    await tester.pumpAndSettle();

    expect(requestedSale?.id, originalSale.id);
    expect(find.text('৳700'), findsNWidgets(2));
  });

  testWidgets('editing a COD sale recalculates its due amount', (tester) async {
    SaleRecord? updatedSale;
    final originalSale = _sale(
      total: 950,
      paymentMethod: 'cod',
      buyerAddress: 'Dhanmondi, Dhaka',
      deliveryCharge: 150,
      advancePaid: 100,
      codDue: 850,
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: TextButton(
              onPressed: () => Navigator.push<SaleRecord>(
                context,
                MaterialPageRoute(
                  builder: (_) => SalesScreen(
                    products: const [
                      ShopProduct(id: 1, name: 'Shirt', price: 500),
                    ],
                    profile: const ShopProfile(
                      owner: 'Amina',
                      shop: 'Store',
                      phone: '',
                    ),
                    bangla: false,
                    t: (en, _) => en,
                    onSave: (sale) async => sale,
                    onUpdate: (sale) async {
                      updatedSale = sale;
                      return sale;
                    },
                    initialSale: originalSale,
                    onNavigate: (_) {},
                  ),
                ),
              ),
              child: const Text('Open COD editor'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open COD editor'));
    await tester.pumpAndSettle();
    await tester.drag(find.byType(ListView).first, const Offset(0, -700));
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const ValueKey('sale-discount')), '50');
    await tester.tap(find.textContaining('Save changes'));
    await tester.pumpAndSettle();

    expect(updatedSale?.paymentMethod, 'cod');
    expect(updatedSale?.buyerAddress, 'Dhanmondi, Dhaka');
    expect(updatedSale?.deliveryCharge, 150);
    expect(updatedSale?.advancePaid, 100);
    expect(updatedSale?.total, 1000);
    expect(updatedSale?.codDue, 900);
  });
}
