import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

String buildCourierDetails({
  required String name,
  required String phone,
  required String address,
  required double codAmount,
}) =>
    'Name: ${name.trim()}\n'
    'Phone: ${phone.trim()}\n'
    'Address: ${address.trim()}\n'
    'COD Amount: ৳${_formatMoney(codAmount)}';

Future<void> copyCourierDetails({
  required BuildContext context,
  required String name,
  required String phone,
  required String address,
  required double codAmount,
  required String Function(String, String) t,
}) async {
  try {
    await Clipboard.setData(
      ClipboardData(
        text: buildCourierDetails(
          name: name,
          phone: phone,
          address: address,
          codAmount: codAmount,
        ),
      ),
    );
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Courier details copied', 'কুরিয়ারের তথ্য কপি হয়েছে'),
          ),
        ),
      );
    }
  } catch (error, stackTrace) {
    debugPrint('Copying Bikrito courier details failed: $error\n$stackTrace');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t('Could not copy courier details', 'কুরিয়ারের তথ্য কপি হয়নি')}: $error',
          ),
        ),
      );
    }
  }
}

String _formatMoney(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
