import 'package:flutter/material.dart';

import '../bills/invoice_actions.dart';
import '../models/sale_record.dart';
import '../models/shop_profile.dart';
import '../orders/courier_details.dart';
import '../widgets/bikrito_bottom_navigation.dart';
import '../bills/whatsapp_bill.dart' show paymentLabel;

const _ordersRed = Color(0xFFD83B3B);
const _ordersInk = Color(0xFF252525);
const _ordersMuted = Color(0xFF858585);

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({
    super.key,
    required this.orders,
    required this.profile,
    required this.bangla,
    required this.t,
    required this.onNavigate,
    required this.onNewOrder,
  });

  final List<SaleRecord> orders;
  final ShopProfile profile;
  final bool bangla;
  final String Function(String, String) t;
  final ValueChanged<int> onNavigate;
  final Future<SaleRecord?> Function() onNewOrder;

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  late List<SaleRecord> _orders;

  @override
  void initState() {
    super.initState();
    _orders = List<SaleRecord>.from(widget.orders);
  }

  String t(String en, String bn) => widget.t(en, bn);

  Future<void> _createOrder() async {
    final order = await widget.onNewOrder();
    if (!mounted || order == null) return;
    setState(() => _orders = [order, ..._orders]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Orders', 'অর্ডার'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: BikritoBottomBar(
        selectedIndex: 2,
        t: t,
        onNavigate: widget.onNavigate,
        showSaleButton: false,
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
            child: SizedBox(
              width: double.infinity,
              height: 50,
              child: FilledButton.icon(
                onPressed: _createOrder,
                icon: const Icon(Icons.add_shopping_cart_rounded),
                label: Text(t('E-Commerce order', 'ই-কমার্স অর্ডার')),
                style: FilledButton.styleFrom(backgroundColor: _ordersRed),
              ),
            ),
          ),
          Expanded(
            child: _orders.isEmpty
                ? _emptyState()
                : ListView(
                    padding: const EdgeInsets.all(20),
                    children: [
                      _summaryCard(),
                      const SizedBox(height: 24),
                      Text(
                        '${t('All orders', 'সব অর্ডার')}  ·  ${_orders.length}',
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: _ordersInk,
                        ),
                      ),
                      const SizedBox(height: 12),
                      ..._orders.map((order) => _orderCard(context, order)),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _emptyState() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(
          Icons.local_shipping_outlined,
          size: 48,
          color: _ordersRed,
        ),
        const SizedBox(height: 14),
        Text(
          t('No orders yet', 'এখনও কোনো অর্ডার নেই'),
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: _ordersInk,
          ),
        ),
        const SizedBox(height: 5),
        Text(
          t('COD orders will appear here.', 'COD অর্ডার এখানে দেখা যাবে।'),
          style: const TextStyle(color: _ordersMuted),
        ),
      ],
    ),
  );

  Widget _summaryCard() => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: const Color(0xFFFFEEEE),
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFF3D5D5)),
    ),
    child: Row(
      children: [
        const Icon(Icons.local_shipping_outlined, color: _ordersRed, size: 21),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                t('Total COD due', 'মোট COD বাকি'),
                style: const TextStyle(fontSize: 11, color: _ordersMuted),
              ),
              const SizedBox(height: 4),
              Text(
                '৳${_money(_orders.fold<double>(0, (sum, o) => sum + o.codDue))}',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: _ordersInk,
                ),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _orderCard(BuildContext context, SaleRecord order) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(15),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(17),
        border: Border.all(color: const Color(0xFFECEAE7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          InkWell(
            onTap: () => _showOrderDetails(context, order),
            borderRadius: BorderRadius.circular(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 42,
                      height: 42,
                      decoration: BoxDecoration(
                        color: const Color(0xFFFFEEEE),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.shopping_bag_outlined,
                        color: _ordersRed,
                        size: 21,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${t('Order', 'অর্ডার')} #${order.id ?? ''}',
                            style: const TextStyle(
                              fontWeight: FontWeight.w800,
                              color: _ordersInk,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${_orderDate(order.createdAt)}  ·  ${order.items.length} ${t('items', 'টি পণ্য')}',
                            style:
                                const TextStyle(fontSize: 11, color: _ordersMuted),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '৳${_money(order.codDue)}',
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w800,
                        color: _ordersRed,
                      ),
                    ),
                  ],
                ),
                if (order.buyerName.trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text(
                    '${t('Buyer', 'ক্রেতা')}: ${order.buyerName.trim()}',
                    style: const TextStyle(fontSize: 12, color: _ordersMuted),
                  ),
                ],
                if (order.buyerPhone.trim().isNotEmpty)
                  Text(
                    '${t('Phone', 'ফোন')}: ${order.buyerPhone.trim()}',
                    style: const TextStyle(fontSize: 12, color: _ordersMuted),
                  ),
                if (order.buyerAddress.trim().isNotEmpty)
                  Text(
                    '${t('Address', 'ঠিকানা')}: ${order.buyerAddress.trim()}',
                    style: const TextStyle(fontSize: 12, color: _ordersMuted),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: () => copyCourierDetails(
                context: context,
                name: order.buyerName,
                phone: order.buyerPhone,
                address: order.buyerAddress,
                codAmount: order.codDue,
                t: t,
              ),
              icon: const Icon(Icons.copy_rounded, size: 17),
              label: Text(t('Copy for Courier', 'কুরিয়ারের জন্য কপি')),
              style: OutlinedButton.styleFrom(
                foregroundColor: _ordersRed,
                side: const BorderSide(color: _ordersRed),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showOrderDetails(BuildContext context, SaleRecord order) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _OrderDetailsBottomSheet(
        order: order,
        profile: widget.profile,
        t: t,
      ),
    );
  }
}

class _OrderDetailsBottomSheet extends StatelessWidget {
  const _OrderDetailsBottomSheet({
    required this.order,
    required this.profile,
    required this.t,
  });

  final SaleRecord order;
  final ShopProfile profile;
  final String Function(String, String) t;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('Order', 'অর্ডার')} #${order.id ?? ''}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _ordersInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _orderDate(order.createdAt),
            style: const TextStyle(color: _ordersMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...order.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name}  ×  ${item.quantity}',
                      style: const TextStyle(color: _ordersInk),
                    ),
                  ),
                  Text(
                    '৳${_money(item.lineTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          _TotalLine(label: t('Subtotal', 'উপমোট'), amount: order.subtotal),
          if (order.deliveryCharge > 0)
            _TotalLine(
              label: t('Delivery charge', 'ডেলিভারি চার্জ'),
              amount: order.deliveryCharge,
            ),
          if (order.discount > 0)
            _TotalLine(
              label: t('Discount', 'ছাড়'),
              amount: -order.discount,
              isDiscount: true,
            ),
          const SizedBox(height: 8),
          _TotalLine(label: t('Total', 'মোট'), amount: order.total),
          if (order.advancePaid > 0)
            _TotalLine(
              label: t('Advance paid', 'আগাম পেইড'),
              amount: -order.advancePaid,
              isDiscount: true,
            ),
          const SizedBox(height: 8),
          _TotalLine(
            label: t('COD Due', 'COD বাকি'),
            amount: order.codDue,
            isGrandTotal: true,
          ),
          const SizedBox(height: 10),
          Text(
            '${t('Payment', 'পেমেন্ট')}: ${paymentLabel(order.paymentMethod, t)}',
            style: const TextStyle(color: _ordersMuted, fontSize: 13),
          ),
          if (order.buyerName.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${t('Buyer', 'ক্রেতা')}: ${order.buyerName}',
              style: const TextStyle(color: _ordersMuted, fontSize: 13),
            ),
          ],
          if (order.buyerAddress.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${t('Address', 'ঠিকানা')}: ${order.buyerAddress}',
              style: const TextStyle(color: _ordersMuted, fontSize: 13),
            ),
          ],
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 50,
            child: FilledButton.icon(
              onPressed: () => showInvoicePreview(
                context: context,
                profile: profile,
                sale: order,
                t: t,
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(t('Invoice', 'ইনভয়েস')),
              style: FilledButton.styleFrom(backgroundColor: _ordersRed),
            ),
          ),
        ],
      ),
    ),
  );
}

class _TotalLine extends StatelessWidget {
  const _TotalLine({
    required this.label,
    required this.amount,
    this.isDiscount = false,
    this.isGrandTotal = false,
  });
  final String label;
  final double amount;
  final bool isDiscount, isGrandTotal;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 4),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: TextStyle(
              fontSize: isGrandTotal ? 15 : 13,
              fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w500,
              color: isGrandTotal ? _ordersInk : _ordersMuted,
            ),
          ),
        ),
        Text(
          '${amount < 0 ? '−' : ''}৳${_money(amount.abs())}',
          style: TextStyle(
            fontSize: isGrandTotal ? 17 : 13,
            fontWeight: FontWeight.w800,
            color: isDiscount
                ? const Color(0xFF22865A)
                : (isGrandTotal ? _ordersRed : _ordersInk),
          ),
        ),
      ],
    ),
  );
}

String _money(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);

String _orderDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  '
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
