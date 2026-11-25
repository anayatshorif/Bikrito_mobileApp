import 'package:flutter_test/flutter_test.dart';

import 'package:bikrito/orders/courier_details.dart';

void main() {
  test('courier details use one clean labeled block', () {
    expect(
      buildCourierDetails(
        name: '  Amina Rahman ',
        phone: ' 8801712345678 ',
        address: ' Dhanmondi, Dhaka ',
        codAmount: 1250,
      ),
      'Name: Amina Rahman\n'
      'Phone: 8801712345678\n'
      'Address: Dhanmondi, Dhaka\n'
      'COD Amount: ৳1250',
    );
  });
}
