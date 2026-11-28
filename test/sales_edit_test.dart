import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bikrito/main.dart';
import 'package:bikrito/models/sale_record.dart';
import 'package:bikrito/models/shop_product.dart';
import 'package:bikrito/models/shop_profile.dart';
import 'package:bikrito/screens/sales_screen.dart';

SaleRecord _sale({
  int id = 20,
  double total = 800,
  double discount = 100,
  String buyerName = 'Old buyer',
  String buyerPhone = '',
  String paymentMethod = 'cash',
  String buyerAddress = '',
  double deliveryCharge = 0,
  double advancePaid = 0,
  double codDue = 0,
}) => SaleRecord(
  id: id,
  items: const [
    SaleItem(productId: 1, name: 'Shirt', unitPrice: 450, quantity: 2),
  ],
  subtotal: 900,
  discount: discount,
  total: total,
  paymentMethod: paymentMethod,
  createdAt: DateTime(2026, 11, 25),
  buyerName: buyerName,
  buyerPhone: buyerPhone,
  buyerAddress: buyerAddress,
  deliveryCharge: deliveryCharge,
  advancePaid: advancePaid,
  codDue: codDue,
);

void main() {
  testWidgets('home remaining metric opens remaining-payments page', (
    tester,
  ) async {
    var openedRemaining = false;
    await tester.pumpWidget(
      MaterialApp(
        home: HomeScreen(
          profile: const ShopProfile(owner: 'Amina', shop: 'Store', phone: ''),
          products: const [],
          sales: [_sale(paymentMethod: 'remaining')],
          bangla: false,
          t: (en, _) => en,
          onLanguage: () {},
          onAdd: () {},
          onDelete: (_) {},
          onEditProfile: () {},
          onLogout: () {},
          onNewSale: () {},
          onOrder: () {},
          onReports: () {},
          onOrders: () {},
          onShowRemaining: () => openedRemaining = true,
          onNavigate: (_) {},
          onOpenProduct: (_) {},
        ),
      ),
    );

    final remainingMetric = find.text('Remaining');
    await tester.ensureVisible(remainingMetric);
    await tester.tap(remainingMetric);

    expect(openedRemaining, isTrue);

    final menuButton = find.byTooltip('Open menu');
    await tester.ensureVisible(menuButton);
    await tester.tap(menuButton);
    await tester.pumpAndSettle();
    expect(find.text('Remaining payments'), findsOneWidget);

    openedRemaining = false;
    await tester.tap(find.text('Remaining payments'));
    await tester.pumpAndSettle();
    expect(openedRemaining, isTrue);
  });

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

  testWidgets('remaining page lists unpaid sales and removes a settled sale', (
    tester,
  ) async {
    final unpaidSale = _sale(
      id: 20,
      paymentMethod: 'remaining',
      buyerPhone: '01712345678',
    );
    final paidSale = _sale(id: 21, paymentMethod: 'cash');

    await tester.pumpWidget(
      MaterialApp(
        home: RemainingSalesScreen(
          sales: [unpaidSale, paidSale],
          profile: const ShopProfile(owner: 'Amina', shop: 'Store', phone: ''),
          t: (en, _) => en,
          onNavigate: (_) {},
          onEditSale: (sale) async =>
              _sale(id: sale.id!, total: sale.total, paymentMethod: 'cash'),
          onSettleSale: (sale) async => sale,
        ),
      ),
    );

    expect(find.text('Unpaid sales  ·  1'), findsOneWidget);
    expect(find.text('Sale #20'), findsOneWidget);
    expect(find.text('Sale #21'), findsNothing);
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Remind on WhatsApp'),
          )
          .onPressed,
      isNotNull,
    );
    expect(
      tester
          .widget<OutlinedButton>(
            find.widgetWithText(OutlinedButton, 'Mark paid & send thank-you'),
          )
          .onPressed,
      isNotNull,
    );

    await tester.tap(find.text('Sale #20'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit sale'));
    await tester.pumpAndSettle();

    expect(find.text('No remaining payments'), findsOneWidget);
  });

  testWidgets('reminder action stays visible but disabled without a phone', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: RemainingSalesScreen(
          sales: [_sale(paymentMethod: 'remaining')],
          profile: const ShopProfile(owner: 'Amina', shop: 'Store', phone: ''),
          t: (en, _) => en,
          onNavigate: (_) {},
          onEditSale: (sale) async => sale,
          onSettleSale: (sale) async => sale,
        ),
      ),
    );

    final reminderButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Remind on WhatsApp'),
    );
    expect(reminderButton.onPressed, isNull);
    final thankYouButton = tester.widget<OutlinedButton>(
      find.widgetWithText(OutlinedButton, 'Mark paid & send thank-you'),
    );
    expect(thankYouButton.onPressed, isNull);
    expect(
      find.text('Add a valid customer phone number to use WhatsApp actions.'),
      findsOneWidget,
    );
  });

  testWidgets('thank-you action records cash and removes the remaining sale', (
    tester,
  ) async {
    SaleRecord? settledSale;
    await tester.pumpWidget(
      MaterialApp(
        home: RemainingSalesScreen(
          sales: [
            _sale(
              paymentMethod: 'remaining',
              buyerPhone: '01712345678',
            ),
          ],
          profile: const ShopProfile(owner: 'Amina', shop: 'Store', phone: ''),
          t: (en, _) => en,
          onNavigate: (_) {},
          onEditSale: (sale) async => sale,
          onSettleSale: (sale) async {
            settledSale = _sale(
              id: sale.id!,
              total: sale.total,
              paymentMethod: 'cash',
              buyerPhone: sale.buyerPhone,
            );
            return settledSale!;
          },
        ),
      ),
    );

    await tester.tap(
      find.widgetWithText(OutlinedButton, 'Mark paid & send thank-you'),
    );
    await tester.pumpAndSettle();

    expect(settledSale?.paymentMethod, 'cash');
    expect(find.text('No remaining payments'), findsOneWidget);
  });
}
