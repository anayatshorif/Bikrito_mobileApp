import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:bikrito/widgets/bikrito_bottom_navigation.dart';

void main() {
  testWidgets('sale button notch does not overlap the Orders navigation item', (
    tester,
  ) async {
    int? selectedTab;
    tester.view.physicalSize = const Size(320, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          bottomNavigationBar: BikritoBottomBar(
            selectedIndex: 2,
            t: (en, _) => en,
            onNavigate: (index) => selectedTab = index,
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          floatingActionButton: BikritoSaleButton(
            t: (en, _) => en,
            onPressed: () {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final saleButtonRect = tester.getRect(find.byType(FloatingActionButton));
    final productLabelRect = tester.getRect(find.text('Products'));
    final orderLabelRect = tester.getRect(find.text('Orders'));
    final dueLabelRect = tester.getRect(find.text('Due'));

    expect(productLabelRect.right, lessThan(saleButtonRect.left));
    expect(orderLabelRect.right, lessThan(saleButtonRect.left));
    expect(dueLabelRect.left, greaterThan(saleButtonRect.right));
    expect(tester.takeException(), isNull);

    await tester.tap(find.text('Due'));
    expect(selectedTab, 3);
  });
}
