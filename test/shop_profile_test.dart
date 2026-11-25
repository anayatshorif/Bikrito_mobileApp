import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';

import 'package:bikrito/main.dart';
import 'package:bikrito/models/shop_profile.dart';

void main() {
  test('business type fields survive profile serialization', () {
    const profile = ShopProfile(
      owner: 'Amina',
      shop: 'Amina Store',
      phone: '01700000000',
      businessType: 'other',
      businessTypeOther: 'Handmade pottery',
    );

    final restored = ShopProfile.fromJson(profile.toJson());

    expect(restored.businessType, 'other');
    expect(restored.businessTypeOther, 'Handmade pottery');
  });

  test('older profile data defaults business type fields to empty', () {
    final profile = ShopProfile.fromJson({
      'owner': 'Amina',
      'shop': 'Amina Store',
      'phone': '01700000000',
    });

    expect(profile.businessType, isEmpty);
    expect(profile.businessTypeOther, isEmpty);
  });

  testWidgets('selecting Other reveals a custom business type field', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: SetupScreen(
          bangla: false,
          t: (en, _) => en,
          onSave: (_) async {},
        ),
      ),
    );

    final businessTypeDropdown = find.byType(DropdownButtonFormField<String>);
    await tester.ensureVisible(businessTypeDropdown);
    await tester.tap(businessTypeDropdown);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Other').last);
    await tester.pumpAndSettle();

    expect(find.byKey(const ValueKey('business-type-other')), findsOneWidget);
  });
}
