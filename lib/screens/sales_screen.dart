import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bills/whatsapp_bill.dart';
import '../bills/invoice_actions.dart';
import '../models/sale_record.dart';
import '../models/shop_product.dart';
import '../models/shop_profile.dart';
import '../widgets/bikrito_bottom_navigation.dart';

const _saleRed = Color(0xFFD83B3B);
const _saleInk = Color(0xFF252525);
const _saleMuted = Color(0xFF858585);

class SalesScreen extends StatefulWidget {
  const SalesScreen({
    super.key,
    required this.products,
    required this.profile,
    required this.bangla,
    required this.t,
    required this.onSave,
    required this.onNavigate,
  });

  final List<ShopProduct> products;
  final ShopProfile profile;
  final bool bangla;
  final String Function(String, String) t;
  final Future<SaleRecord> Function(SaleRecord) onSave;
  final ValueChanged<int> onNavigate;

  @override
  State<SalesScreen> createState() => _SalesScreenState();
}

class _SalesScreenState extends State<SalesScreen> {
  final _discountController = TextEditingController();
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _searchController = TextEditingController();
  String _searchQuery = '';
  final Map<int, int> _quantities = {};
  String _paymentMethod = 'cash';
  bool _saving = false;

  String t(String en, String bn) => widget.t(en, bn);

  List<ShopProduct> get _selectedProducts => widget.products
      .where(
        (product) => product.id != null && (_quantities[product.id] ?? 0) > 0,
      )
      .toList();

  int _quantity(ShopProduct product) =>
      product.id == null ? 0 : (_quantities[product.id] ?? 0);

  List<ShopProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    if (query.isEmpty) return widget.products;
    return widget.products
        .where((p) => p.name.toLowerCase().contains(query))
        .toList();
  }

  double get _subtotal => _selectedProducts.fold<double>(
    0,
    (sum, product) => sum + product.price * _quantity(product),
  );

  double get _discount => double.tryParse(_discountController.text.trim()) ?? 0;
  double get _total =>
      (_subtotal - _discount).clamp(0, double.infinity).toDouble();

  @override
  void dispose() {
    _discountController.dispose();
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _changeQuantity(ShopProduct product, int amount) {
    final id = product.id;
    if (id == null) return;
    final next = (_quantities[id] ?? 0) + amount;
    setState(() {
      if (next <= 0) {
        _quantities.remove(id);
      } else {
        _quantities[id] = next;
      }
    });
  }

  Future<void> _saveSale() async {
    if (_selectedProducts.isEmpty || _discount > _subtotal || _saving) return;
    setState(() => _saving = true);
    final items = _selectedProducts
        .map(
          (product) => SaleItem(
            productId: product.id,
            name: product.name,
            unitPrice: product.price,
            quantity: _quantity(product),
          ),
        )
        .toList();
    final sale = SaleRecord(
      items: items,
      subtotal: _subtotal,
      discount: _discount,
      total: _total,
      paymentMethod: _paymentMethod,
      createdAt: DateTime.now(),
      buyerName: _buyerNameController.text.trim(),
      buyerPhone: normaliseBdPhone(_buyerPhoneController.text),
    );
    try {
      final savedSale = await widget.onSave(sale);
      if (!mounted) return;
      await showInvoicePreview(
        context: context,
        profile: widget.profile,
        sale: savedSale,
        t: t,
      );
      if (!mounted) return;
      Navigator.pop(context);
    } catch (error, stackTrace) {
      debugPrint('Saving Bikrito sale failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t('Could not save sale', 'বিক্রি সংরক্ষণ হয়নি')}: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    final invalidDiscount = _discount > _subtotal;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('New sale', 'নতুন বিক্রি'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: BikritoBottomBar(
        selectedIndex: -1,
        t: t,
        onNavigate: widget.onNavigate,
        showSaleButton: false,
      ),
      body: SafeArea(
        child: widget.products.isEmpty
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.inventory_2_outlined,
                        color: _saleRed,
                        size: 48,
                      ),
                      const SizedBox(height: 14),
                      Text(
                        t('Add products first', 'আগে পণ্য যোগ করুন'),
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: _saleInk,
                        ),
                      ),
                      const SizedBox(height: 7),
                      Text(
                        t(
                          'Your product list is empty.',
                          'আপনার পণ্যের তালিকা খালি।',
                        ),
                        style: const TextStyle(color: _saleMuted),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle(
                                title: t('Select products', 'পণ্য নির্বাচন করুন'),
                                subtitle: t(
                                  'Search and tap + to add.',
                                  'খুঁজুন এবং + চাপুন।',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _searchController,
                                onChanged: (value) =>
                                    setState(() => _searchQuery = value),
                                decoration: InputDecoration(
                                  hintText: t(
                                    'Search products…',
                                    'পণ্য খুঁজুন…',
                                  ),
                                  prefixIcon: const Icon(Icons.search_rounded),
                                  filled: true,
                                  fillColor: const Color(0xFFFAF9F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECEAE7),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 8),
                              if (_filteredProducts.isEmpty)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                  child: Text(
                                    t(
                                      'No matching products',
                                      'কোনো পণ্য পাওয়া যায়নি',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: _saleMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else
                                ..._filteredProducts.map(_productTile),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        if (_selectedProducts.isNotEmpty) ...[
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      t('Sale items', 'বিক্রির পণ্য'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _saleInk,
                                      ),
                                    ),
                                    Text(
                                      '${_selectedProducts.length} ${t('items', 'টি পণ্য')}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _saleMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ..._selectedProducts.map(_saleItemTile),
                              ],
                            ),
                          ),
                          const SizedBox(height: 16),
                        ],
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle(
                                title: t('Buyer details', 'ক্রেতার তথ্য'),
                                subtitle: t(
                                  'Optional — used on the invoice.',
                                  'ঐচ্ছিক — ইনভয়েসে ব্যবহার হবে।',
                                ),
                              ),
                              const SizedBox(height: 12),
                              TextField(
                                controller: _buyerNameController,
                                textCapitalization: TextCapitalization.words,
                                decoration: InputDecoration(
                                  hintText: t('Buyer name', 'ক্রেতার নাম'),
                                  prefixIcon: const Icon(
                                    Icons.person_outline_rounded,
                                  ),
                                  filled: true,
                                  fillColor: const Color(0xFFFAF9F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECEAE7),
                                    ),
                                  ),
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _buyerPhoneController,
                                keyboardType: TextInputType.phone,
                                decoration: InputDecoration(
                                  hintText: t(
                                    'Buyer WhatsApp number (optional)',
                                    'ক্রেতার হোয়াটসঅ্যাপ নম্বর (ঐচ্ছিক)',
                                  ),
                                  prefixIcon: const Icon(Icons.chat_outlined),
                                  filled: true,
                                  fillColor: const Color(0xFFFAF9F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECEAE7),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle(
                                title: t('Payment method', 'পেমেন্ট পদ্ধতি'),
                              ),
                              const SizedBox(height: 10),
                              Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  _paymentChip(
                                    'cash',
                                    t('Cash', 'নগদ'),
                                    Icons.payments_outlined,
                                  ),
                                  _paymentChip(
                                    'bkash',
                                    'bKash',
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  _paymentChip(
                                    'nagad',
                                    'Nagad',
                                    Icons.account_balance_wallet_outlined,
                                  ),
                                  _paymentChip(
                                    'bank',
                                    t('Bank', 'ব্যাংক'),
                                    Icons.account_balance_outlined,
                                  ),
                                  _paymentChip(
                                    'remaining',
                                    t('Remaining', 'বাকি'),
                                    Icons.hourglass_bottom_rounded,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              _SectionTitle(
                                title: t('Discount', 'ছাড়'),
                                subtitle: t(
                                  'Enter a fixed amount in taka.',
                                  'টাকায় ছাড়ের পরিমাণ লিখুন।',
                                ),
                              ),
                              const SizedBox(height: 10),
                              TextField(
                                controller: _discountController,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                inputFormatters: [
                                  FilteringTextInputFormatter.allow(
                                    RegExp(r'^\d*\.?\d{0,2}'),
                                  ),
                                ],
                                onChanged: (_) => setState(() {}),
                                decoration: InputDecoration(
                                  prefixText: '৳  ',
                                  hintText: '0',
                                  errorText: invalidDiscount
                                      ? t(
                                          'Discount can’t exceed subtotal',
                                          'ছাড় উপমোটের বেশি হতে পারে না',
                                        )
                                      : null,
                                  filled: true,
                                  fillColor: const Color(0xFFFAF9F7),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(13),
                                    borderSide: const BorderSide(
                                      color: Color(0xFFECEAE7),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),
                        _totalsCard(),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.fromLTRB(20, 12, 20, 14),
                    decoration: const BoxDecoration(
                      color: Colors.white,
                      border: Border(top: BorderSide(color: Color(0xFFECEAE7))),
                    ),
                    child: SafeArea(
                      top: false,
                      child: SizedBox(
                        width: double.infinity,
                        height: 52,
                        child: FilledButton(
                          onPressed:
                              _selectedProducts.isEmpty ||
                                  invalidDiscount ||
                                  _saving
                              ? null
                              : _saveSale,
                          style: FilledButton.styleFrom(
                            backgroundColor: _saleRed,
                            disabledBackgroundColor: const Color(0xFFDDDDDD),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: _saving
                              ? const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: Colors.white,
                                  ),
                                )
                              : Text(
                                  '${t('Save sale', 'বিক্রি সংরক্ষণ করুন')}  ·  ৳${_formatMoney(_total)}',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 15,
                                  ),
                                ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFECEAE7)),
    ),
    child: child,
  );

  Widget _thumb(ShopProduct product, {double size = 42}) {
    Widget child;
    if (product.imageData != null && product.imageData!.isNotEmpty) {
      child = Image.memory(base64Decode(product.imageData!), fit: BoxFit.cover);
    } else if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      child = Image.file(File(product.imagePath!), fit: BoxFit.cover);
    } else {
      child = const Center(
        child: Icon(Icons.inventory_2_outlined, color: _saleRed, size: 20),
      );
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: Container(
        width: size,
        height: size,
        color: const Color(0xFFFFEEEE),
        child: child,
      ),
    );
  }

  Widget _productTile(ShopProduct product) {
    final qty = _quantity(product);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 10),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F1EF))),
      ),
      child: Row(
        children: [
          _thumb(product),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _saleInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '৳${_formatMoney(product.price)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _saleRed,
                  ),
                ),
              ],
            ),
          ),
          InkWell(
            onTap: () => _changeQuantity(product, 1),
            borderRadius: BorderRadius.circular(9),
            child: Container(
              width: 30,
              height: 30,
              decoration: BoxDecoration(
                color: qty > 0 ? const Color(0xFFFFEEEE) : _saleRed,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                qty > 0 ? Icons.check_rounded : Icons.add_rounded,
                size: 18,
                color: qty > 0 ? _saleRed : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _saleItemTile(ShopProduct product) {
    final qty = _quantity(product);
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFF3F1EF))),
      ),
      child: Row(
        children: [
          _thumb(product, size: 38),
          const SizedBox(width: 11),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  product.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: _saleInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '৳${_formatMoney(product.price)} ${t('each', 'প্রতি')}',
                  style: const TextStyle(fontSize: 12, color: _saleMuted),
                ),
              ],
            ),
          ),
          _miniStep(
            '−',
            onTap: () => _changeQuantity(product, -1),
            radius: const BorderRadius.horizontal(left: Radius.circular(9)),
          ),
          Container(
            width: 34,
            height: 30,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border.symmetric(
                vertical: BorderSide(color: Color(0xFFECEAE7)),
              ),
            ),
            child: Text(
              '$qty',
              style: const TextStyle(
                fontWeight: FontWeight.w800,
                fontSize: 13,
                color: _saleInk,
              ),
            ),
          ),
          _miniStep(
            '+',
            onTap: () => _changeQuantity(product, 1),
            radius: const BorderRadius.horizontal(right: Radius.circular(9)),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 58,
            child: Text(
              '৳${_formatMoney(product.price * qty)}',
              textAlign: TextAlign.right,
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: _saleRed,
              ),
            ),
          ),
          const SizedBox(width: 6),
          InkWell(
            onTap: () => _changeQuantity(product, -qty),
            borderRadius: BorderRadius.circular(8),
            child: Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.close_rounded,
                size: 16,
                color: _saleRed,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniStep(
    String label, {
    required VoidCallback onTap,
    BorderRadius? radius,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: Colors.white,
          border: Border.all(color: const Color(0xFFECEAE7)),
          borderRadius: radius,
        ),
        child: Text(
          label,
          style: const TextStyle(
            color: _saleRed,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _paymentChip(String value, String label, IconData icon) {
    final selected = _paymentMethod == value;
    return ChoiceChip(
      avatar: Icon(icon, size: 17, color: selected ? _saleRed : _saleMuted),
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _paymentMethod = value),
      selectedColor: const Color(0xFFFFEEEE),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _saleRed : const Color(0xFFECEAE7)),
      labelStyle: TextStyle(
        color: selected ? _saleRed : _saleInk,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      showCheckmark: false,
    );
  }

  Widget _totalsCard() => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(color: const Color(0xFFECEAE7)),
    ),
    child: Column(
      children: [
        _TotalLine(label: t('Subtotal', 'উপমোট'), amount: _subtotal),
        const SizedBox(height: 9),
        _TotalLine(
          label: t('Discount', 'ছাড়'),
          amount: -_discount,
          isDiscount: true,
        ),
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Divider(height: 1),
        ),
        _TotalLine(
          label: t('Total', 'মোট'),
          amount: _total,
          isGrandTotal: true,
        ),
        if (_paymentMethod == 'remaining') ...[
          const SizedBox(height: 10),
          Row(
            children: [
              const Icon(Icons.info_outline_rounded, size: 16, color: _saleRed),
              const SizedBox(width: 7),
              Expanded(
                child: Text(
                  t(
                    'This full amount will be recorded as remaining.',
                    'সম্পূর্ণ পরিমাণ বাকি হিসেবে সংরক্ষণ হবে।',
                  ),
                  style: const TextStyle(fontSize: 12, color: _saleMuted),
                ),
              ),
            ],
          ),
        ],
      ],
    ),
  );
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, this.subtitle});
  final String title;
  final String? subtitle;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        title,
        style: const TextStyle(
          fontSize: 17,
          fontWeight: FontWeight.w800,
          color: _saleInk,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          style: const TextStyle(fontSize: 12, color: _saleMuted),
        ),
      ],
    ],
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
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: isGrandTotal ? 16 : 13,
            fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w500,
            color: isGrandTotal ? _saleInk : _saleMuted,
          ),
        ),
      ),
      Text(
        '${amount < 0 ? '−' : ''}৳${_formatMoney(amount.abs())}',
        style: TextStyle(
          fontSize: isGrandTotal ? 18 : 14,
          fontWeight: FontWeight.w800,
          color: isDiscount
              ? const Color(0xFF22865A)
              : (isGrandTotal ? _saleRed : _saleInk),
        ),
      ),
    ],
  );
}

class SalesReportsScreen extends StatelessWidget {
  const SalesReportsScreen({
    super.key,
    required this.sales,
    required this.profile,
    required this.bangla,
    required this.t,
    required this.onNavigate,
    required this.onNewSale,
  });
  final List<SaleRecord> sales;
  final ShopProfile profile;
  final bool bangla;
  final String Function(String, String) t;
  final ValueChanged<int> onNavigate;
  final VoidCallback onNewSale;

  @override
  Widget build(BuildContext context) {
    final total = sales.fold<double>(0, (sum, sale) => sum + sale.total);
    final remaining = sales
        .where((sale) => sale.paymentMethod == 'remaining')
        .fold<double>(0, (sum, sale) => sum + sale.total);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Sales reports', 'বিক্রির রিপোর্ট'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
        ),
      ),
      bottomNavigationBar: BikritoBottomBar(
        selectedIndex: 2,
        t: t,
        onNavigate: onNavigate,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: BikritoSaleButton(t: t, onPressed: onNewSale),
      body: sales.isEmpty
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.receipt_long_rounded,
                    size: 48,
                    color: _saleRed,
                  ),
                  const SizedBox(height: 14),
                  Text(
                    t('No sales yet', 'এখনও কোনো বিক্রি নেই'),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: _saleInk,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Text(
                    t(
                      'Saved sales will appear here.',
                      'সংরক্ষিত বিক্রি এখানে দেখা যাবে।',
                    ),
                    style: const TextStyle(color: _saleMuted),
                  ),
                ],
              ),
            )
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Row(
                  children: [
                    Expanded(
                      child: _SummaryCard(
                        label: t('Sales total', 'মোট বিক্রি'),
                        value: total,
                        icon: Icons.trending_up_rounded,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _SummaryCard(
                        label: t('Remaining', 'বাকি'),
                        value: remaining,
                        icon: Icons.hourglass_bottom_rounded,
                        highlight: true,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  t(
                    'All sales  ·  ${sales.length}',
                    'সব বিক্রি  ·  ${sales.length}',
                  ),
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: _saleInk,
                  ),
                ),
                const SizedBox(height: 12),
                ...sales.map((sale) => _saleCard(context, sale)),
              ],
            ),
    );
  }

  Widget _saleCard(BuildContext context, SaleRecord sale) {
    final method = paymentLabel(sale.paymentMethod, t);
    return InkWell(
      onTap: () => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        isScrollControlled: true,
        builder: (_) => _SaleDetails(sale: sale, t: t, profile: profile),
      ),
      borderRadius: BorderRadius.circular(17),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(17),
          border: Border.all(color: const Color(0xFFECEAE7)),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: const Color(0xFFFFEEEE),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: _saleRed,
                size: 21,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${t('Sale', 'বিক্রি')} #${sale.id ?? ''}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      color: _saleInk,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_saleDate(sale.createdAt)}  ·  ${sale.items.length} ${t('items', 'টি পণ্য')}',
                    style: const TextStyle(fontSize: 11, color: _saleMuted),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    method,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: sale.paymentMethod == 'remaining'
                          ? _saleRed
                          : _saleMuted,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              '৳${_formatMoney(sale.total)}',
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: _saleRed,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SaleDetails extends StatelessWidget {
  const _SaleDetails({required this.sale, required this.t, required this.profile});
  final SaleRecord sale;
  final String Function(String, String) t;
  final ShopProfile profile;

  @override
  Widget build(BuildContext context) => SafeArea(
    child: Padding(
      padding: const EdgeInsets.fromLTRB(22, 8, 22, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${t('Sale', 'বিক্রি')} #${sale.id ?? ''}',
            style: const TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w800,
              color: _saleInk,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            _saleDate(sale.createdAt),
            style: const TextStyle(color: _saleMuted, fontSize: 12),
          ),
          const SizedBox(height: 16),
          ...sale.items.map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      '${item.name}  ×  ${item.quantity}',
                      style: const TextStyle(color: _saleInk),
                    ),
                  ),
                  Text(
                    '৳${_formatMoney(item.lineTotal)}',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 24),
          _TotalLine(label: t('Subtotal', 'উপমোট'), amount: sale.subtotal),
          const SizedBox(height: 8),
          _TotalLine(
            label: t('Discount', 'ছাড়'),
            amount: -sale.discount,
            isDiscount: true,
          ),
          const SizedBox(height: 8),
          _TotalLine(
            label: t('Total', 'মোট'),
            amount: sale.total,
            isGrandTotal: true,
          ),
          const SizedBox(height: 10),
          Text(
            '${t('Payment', 'পেমেন্ট')}: ${paymentLabel(sale.paymentMethod, t)}',
            style: const TextStyle(color: _saleMuted, fontSize: 13),
          ),
          if (sale.buyerName.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              '${t('Buyer', 'ক্রেতা')}: ${sale.buyerName}',
              style: const TextStyle(color: _saleMuted, fontSize: 13),
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
                sale: sale,
                t: t,
              ),
              icon: const Icon(Icons.receipt_long_rounded),
              label: Text(t('Invoice', 'ইনভয়েস')),
              style: FilledButton.styleFrom(backgroundColor: _saleRed),
            ),
          ),
        ],
      ),
    ),
  );
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
    required this.icon,
    this.highlight = false,
  });
  final String label;
  final double value;
  final IconData icon;
  final bool highlight;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(15),
    decoration: BoxDecoration(
      color: highlight ? const Color(0xFFFFEEEE) : Colors.white,
      borderRadius: BorderRadius.circular(17),
      border: Border.all(
        color: highlight ? const Color(0xFFF3D5D5) : const Color(0xFFECEAE7),
      ),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 19, color: _saleRed),
        const SizedBox(height: 12),
        Text(label, style: const TextStyle(fontSize: 11, color: _saleMuted)),
        const SizedBox(height: 4),
        Text(
          '৳${_formatMoney(value)}',
          overflow: TextOverflow.ellipsis,
          style: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w800,
            color: _saleInk,
          ),
        ),
      ],
    ),
  );
}

String _saleDate(DateTime date) =>
    '${date.day.toString().padLeft(2, '0')}/${date.month.toString().padLeft(2, '0')}/${date.year}  ${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

String _formatMoney(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
