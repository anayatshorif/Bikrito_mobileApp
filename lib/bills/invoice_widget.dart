import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';

import '../models/sale_record.dart';
import '../models/shop_profile.dart';
import '../widgets/bikrito_logo.dart';
import 'whatsapp_bill.dart' show paymentLabel;

const _invoiceRed = Color(0xFFD83B3B);
const _invoiceInk = Color(0xFF252525);
const _invoiceMuted = Color(0xFF858585);
const _invoiceLine = Color(0xFFECEAE7);

class BikritoInvoice extends StatelessWidget {
  const BikritoInvoice({
    super.key,
    required this.profile,
    required this.sale,
    required this.t,
  });

  final ShopProfile profile;
  final SaleRecord sale;
  final String Function(String, String) t;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          _header(),
          Padding(
            padding: const EdgeInsets.fromLTRB(22, 20, 22, 22),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                _titleRow(),
                const SizedBox(height: 3),
                Text(
                  _invoiceDate(sale.createdAt),
                  style: const TextStyle(fontSize: 12, color: _invoiceMuted),
                ),
                if (sale.buyerName.trim().isNotEmpty) ...[
                  const SizedBox(height: 14),
                  _billTo(),
                ],
                const SizedBox(height: 18),
                _items(),
                _totals(),
                _paymentLine(),
                _footer(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _header() {
    final info = [profile.owner, profile.phone, profile.email]
        .where((part) => part.trim().isNotEmpty)
        .join(' · ');
    return Container(
      padding: const EdgeInsets.all(22),
      color: _invoiceRed,
      child: Row(
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(15),
            child: Container(
              width: 54,
              height: 54,
              color: Colors.white,
              child: _logoImage(),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  profile.shop,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    height: 1.15,
                  ),
                ),
                if (info.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(
                    info,
                    style: const TextStyle(
                      color: Color(0xFFFFE4E4),
                      fontSize: 12,
                      height: 1.35,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _logoImage() {
    final data = profile.logoData;
    final path = profile.logoPath;
    if (data != null && data.isNotEmpty) {
      return Image.memory(base64Decode(data), fit: BoxFit.cover);
    }
    if (path != null && path.isNotEmpty) {
      return Image.file(File(path), fit: BoxFit.cover);
    }
    return Image.asset('assets/logo.png', fit: BoxFit.cover);
  }

  Widget _titleRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      children: [
        Text(
          t('Invoice', 'ইনভয়েস').toUpperCase(),
          style: const TextStyle(
            fontSize: 12,
            letterSpacing: 1.6,
            fontWeight: FontWeight.w700,
            color: _invoiceMuted,
          ),
        ),
        Text(
          '#${(sale.id ?? 0).toString().padLeft(5, '0')}',
          style: const TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w800,
            color: _invoiceInk,
          ),
        ),
      ],
    );
  }

  Widget _billTo() {
    final parts = <String>[sale.buyerName.trim()];
    if (sale.buyerPhone.trim().isNotEmpty) parts.add(sale.buyerPhone.trim());
    if (sale.buyerAddress.trim().isNotEmpty) parts.add(sale.buyerAddress.trim());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: const Color(0xFFFAF9F7),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('Bill To', 'ক্রেতা')}: ${parts.first}',
            style: const TextStyle(fontSize: 13, color: _invoiceInk),
          ),
          if (parts.length > 1) ...[
            const SizedBox(height: 4),
            ...parts.skip(1).map(
              (part) => Text(
                part,
                style: const TextStyle(fontSize: 12, color: _invoiceMuted),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _items() {
    return Table(
      columnWidths: const {
        0: FlexColumnWidth(3),
        1: FlexColumnWidth(1),
        2: FlexColumnWidth(1.4),
        3: FlexColumnWidth(1.4),
      },
      border: const TableBorder(
        horizontalInside: BorderSide(color: _invoiceLine, width: 0.5),
      ),
      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
      children: [
        TableRow(
          children: [
            _th(t('Item', 'পণ্য')),
            _th(t('Qty', 'পরিমাণ'), align: TextAlign.center),
            _th(t('Price', 'দাম'), align: TextAlign.right),
            _th(t('Total', 'মোট'), align: TextAlign.right),
          ],
        ),
        ...sale.items.map(
          (item) => TableRow(
            children: [
              _td(item.name),
              _td('${item.quantity}', align: TextAlign.center),
              _td('৳${_money(item.unitPrice)}', align: TextAlign.right),
              _td('৳${_money(item.lineTotal)}', align: TextAlign.right),
            ],
          ),
        ),
      ],
    );
  }

  Widget _th(String text, {TextAlign align = TextAlign.left}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 6),
    child: Text(
      text,
      textAlign: align,
      style: const TextStyle(
        fontSize: 11,
        letterSpacing: 0.5,
        fontWeight: FontWeight.w700,
        color: _invoiceMuted,
      ),
    ),
  );

  Widget _td(String text, {TextAlign align = TextAlign.left}) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
    child: Text(
      text,
      textAlign: align,
      style: const TextStyle(fontSize: 13, color: _invoiceInk),
    ),
  );

  Widget _totals() {
    final isCod = sale.paymentMethod == 'cod' ||
        sale.deliveryCharge > 0 ||
        sale.advancePaid > 0;
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Column(
        children: [
          _totalRow(t('Subtotal', 'উপমোট'), '৳${_money(sale.subtotal)}'),
          if (sale.discount > 0)
            _totalRow(
              t('Discount', 'ছাড়'),
              '-৳${_money(sale.discount)}',
              discount: true,
            ),
          if (isCod) ...[
            _totalRow(
              t('Delivery charge', 'ডেলিভারি চার্জ'),
              '৳${_money(sale.deliveryCharge)}',
            ),
            if (sale.advancePaid > 0)
              _totalRow(
                t('Advance paid', 'আগাম পেইড'),
                '-৳${_money(sale.advancePaid)}',
                discount: true,
              ),
          ],
          Container(
            margin: const EdgeInsets.only(top: 8),
            padding: const EdgeInsets.only(top: 12),
            decoration: const BoxDecoration(
              border: Border(top: BorderSide(color: _invoiceLine)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Text(
                  isCod ? t('COD Due', 'COD বাকি') : t('Total', 'মোট'),
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: _invoiceInk,
                  ),
                ),
                Text(
                  '৳${_money(isCod ? sale.codDue : sale.total)}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: _invoiceRed,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _totalRow(String label, String value, {bool discount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(fontSize: 13, color: _invoiceMuted)),
          Text(
            value,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: discount ? const Color(0xFF22865A) : _invoiceInk,
            ),
          ),
        ],
      ),
    );
  }

  Widget _paymentLine() {
    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Text(
        '${t('Payment', 'পেমেন্ট')}: ${paymentLabel(sale.paymentMethod, t)}',
        style: const TextStyle(fontSize: 12, color: _invoiceInk),
      ),
    );
  }

  Widget _footer() {
    return Container(
      margin: const EdgeInsets.only(top: 18),
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: _invoiceLine)),
      ),
      child: Row(
        children: [
          const BikritoLogo(size: 36, borderRadius: 10),
          const SizedBox(width: 11),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                t('Bill by Bikrito', 'বিক্রিতো দিয়ে বিল'),
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w800,
                  color: _invoiceRed,
                ),
              ),
              const SizedBox(height: 1),
              Text(
                t(
                  'Free offline billing for your shop',
                  'আপনার দোকানের জন্য ফ্রি অফলাইন বিলিং',
                ),
                style: const TextStyle(fontSize: 11, color: _invoiceMuted),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

String _money(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

String _invoiceDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
