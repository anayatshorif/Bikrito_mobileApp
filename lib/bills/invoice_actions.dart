import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderRepaintBoundary;
import 'package:gal/gal.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../models/sale_record.dart';
import '../models/shop_profile.dart';
import 'invoice_widget.dart';
import 'whatsapp_bill.dart';

const _actionsRed = Color(0xFFD83B3B);

Future<void> showInvoicePreview({
  required BuildContext context,
  required ShopProfile profile,
  required SaleRecord sale,
  required String Function(String, String) t,
}) {
  final key = GlobalKey();
  return showDialog<void>(
    context: context,
    builder: (dialogContext) {
      Future<Uint8List> capture() async {
        final boundary =
            key.currentContext!.findRenderObject() as RenderRepaintBoundary;
        final image = await boundary.toImage(pixelRatio: 3);
        final byteData = await image.toByteData(
          format: ui.ImageByteFormat.png,
        );
        return byteData!.buffer.asUint8List();
      }

      Future<void> save() async {
        final bytes = await capture();
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (!context.mounted) return;
        await _saveInvoice(bytes, t, context);
      }

      Future<void> share() async {
        final buyerPhone = sale.buyerPhone.trim();
        if (buyerPhone.isNotEmpty) {
          // Open the buyer's WhatsApp inbox directly with the invoice text.
          if (dialogContext.mounted) Navigator.pop(dialogContext);
          if (!context.mounted) return;
          await openWhatsAppBill(
            context,
            phone: buyerPhone,
            billText: buildBillText(profile: profile, sale: sale, t: t),
            t: t,
          );
          return;
        }

        // No buyer number: capture and share the invoice image.
        final bytes = await capture();
        if (dialogContext.mounted) Navigator.pop(dialogContext);
        if (!context.mounted) return;
        await _shareInvoice(bytes, sale, t, context);
      }

      return Dialog(
        backgroundColor: Colors.white,
        insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(22),
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(dialogContext).size.height * 0.82,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Flexible(
                  child: SingleChildScrollView(
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: RepaintBoundary(
                          key: key,
                          child: BikritoInvoice(
                            profile: profile,
                            sale: sale,
                            t: t,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: save,
                          icon: const Icon(Icons.save_alt_rounded),
                          label: Text(t('Save', 'সংরক্ষণ করুন')),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: _actionsRed,
                            side: const BorderSide(color: _actionsRed),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: share,
                          icon: const Icon(Icons.chat_outlined),
                          label: Text(
                            t('Send on WhatsApp', 'হোয়াটসঅ্যাপে পাঠান'),
                          ),
                          style: FilledButton.styleFrom(
                            backgroundColor: _actionsRed,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      );
    },
  );
}

Future<void> _saveInvoice(
  Uint8List bytes,
  String Function(String, String) t,
  BuildContext context,
) async {
  try {
    if (Platform.isAndroid) {
      await Gal.requestAccess();
    }
    await Gal.putImageBytes(bytes, album: 'Bikrito');
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            t('Invoice saved to gallery', 'ইনভয়েস গ্যালারিতে সংরক্ষিত হয়েছে'),
          ),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t('Could not save invoice', 'ইনভয়েস সংরক্ষণ হয়নি')}: $error',
          ),
        ),
      );
    }
  }
}

Future<void> _shareInvoice(
  Uint8List bytes,
  SaleRecord sale,
  String Function(String, String) t,
  BuildContext context,
) async {
  try {
    final dir = await getTemporaryDirectory();
    final file = File(
      p.join(dir.path, 'Bikrito_invoice_${sale.id ?? 'sale'}.png'),
    );
    await file.writeAsBytes(bytes);
    final buyer = sale.buyerName.trim();
    final text = buyer.isEmpty
        ? t('Invoice from Bikrito', 'বিক্রিতো থেকে ইনভয়েস')
        : t('Invoice for $buyer', '$buyer-এর ইনভয়েস');
    await Share.shareXFiles([XFile(file.path)], text: text);
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t('Could not share invoice', 'ইনভয়েস শেয়ার করা যায়নি')}: $error',
          ),
        ),
      );
    }
  }
}
