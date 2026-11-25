import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../bills/invoice_actions.dart';
import '../bills/whatsapp_bill.dart';
import '../models/sale_record.dart';
import '../models/customer_history.dart';
import '../models/shop_product.dart';
import '../models/shop_profile.dart';
import '../orders/courier_details.dart';
import '../widgets/bikrito_bottom_navigation.dart';

const _orderRed = Color(0xFFD83B3B);
const _orderInk = Color(0xFF252525);
const _orderMuted = Color(0xFF858585);

class OrderScreen extends StatefulWidget {
  const OrderScreen({
    super.key,
    required this.products,
    required this.profile,
    required this.bangla,
    required this.t,
    required this.onSave,
    required this.onFindCustomer,
    required this.onNavigate,
    this.saleCounts = const {},
  });

  final List<ShopProduct> products;
  final ShopProfile profile;
  final bool bangla;
  final String Function(String, String) t;
  final Future<SaleRecord> Function(SaleRecord) onSave;
  final Future<CustomerHistory?> Function(String normalizedPhone)
  onFindCustomer;
  final ValueChanged<int> onNavigate;
  final Map<int, int> saleCounts;

  @override
  State<OrderScreen> createState() => _OrderScreenState();
}

class _OrderScreenState extends State<OrderScreen> {
  final _buyerNameController = TextEditingController();
  final _buyerPhoneController = TextEditingController();
  final _buyerAddressController = TextEditingController();
  final _searchController = TextEditingController();
  final _deliveryController = TextEditingController();
  final _advanceController = TextEditingController();
  final _discountController = TextEditingController();
  Timer? _customerLookupTimer;
  int _customerLookupRequest = 0;
  CustomerHistory? _customerHistory;
  String? _customerLookupError;
  bool _isLookingUpCustomer = false;
  bool _customerLookupComplete = false;
  String _searchQuery = '';
  final Map<int, int> _quantities = {};
  bool _saving = false;
  bool _showAllProducts = false;

  String t(String en, String bn) => widget.t(en, bn);

  List<ShopProduct> get _selectedProducts => widget.products
      .where(
        (product) => product.id != null && (_quantities[product.id] ?? 0) > 0,
      )
      .toList();

  int _quantity(ShopProduct product) =>
      product.id == null ? 0 : (_quantities[product.id] ?? 0);

  List<ShopProduct> get _sortedProducts {
    final counts = widget.saleCounts;
    return List<ShopProduct>.from(widget.products)
      ..sort((a, b) {
        final aCount = a.id == null ? 0 : (counts[a.id] ?? 0);
        final bCount = b.id == null ? 0 : (counts[b.id] ?? 0);
        if (aCount != bCount) return bCount.compareTo(aCount);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });
  }

  List<ShopProduct> get _filteredProducts {
    final query = _searchQuery.trim().toLowerCase();
    final sorted = _sortedProducts;
    if (query.isEmpty) return sorted;
    return sorted.where((p) => p.name.toLowerCase().contains(query)).toList();
  }

  List<ShopProduct> get _visibleProducts => _showAllProducts
      ? _filteredProducts
      : _filteredProducts.take(4).toList();

  double get _subtotal => _selectedProducts.fold<double>(
    0,
    (sum, product) => sum + product.price * _quantity(product),
  );

  double get _deliveryCharge =>
      double.tryParse(_deliveryController.text.trim()) ?? 0;

  double get _discount =>
      double.tryParse(_discountController.text.trim()) ?? 0;

  double get _advancePaid =>
      double.tryParse(_advanceController.text.trim()) ?? 0;

  double get _total =>
      (_subtotal + _deliveryCharge - _discount).clamp(0, double.infinity).toDouble();

  double get _codDue =>
      (_total - _advancePaid).clamp(0, double.infinity).toDouble();

  bool get _canSave =>
      _selectedProducts.isNotEmpty &&
      _buyerNameController.text.trim().isNotEmpty &&
      _buyerPhoneController.text.trim().isNotEmpty &&
      _buyerAddressController.text.trim().isNotEmpty &&
      !_saving;

  bool get _canCopyCourier =>
      _selectedProducts.isNotEmpty &&
      _buyerNameController.text.trim().isNotEmpty &&
      _buyerPhoneController.text.trim().isNotEmpty &&
      _buyerAddressController.text.trim().isNotEmpty &&
      !_saving;

  @override
  void dispose() {
    _customerLookupTimer?.cancel();
    _buyerNameController.dispose();
    _buyerPhoneController.dispose();
    _buyerAddressController.dispose();
    _searchController.dispose();
    _deliveryController.dispose();
    _advanceController.dispose();
    _discountController.dispose();
    super.dispose();
  }

  void _handleBuyerPhoneChanged(String value) {
    _customerLookupTimer?.cancel();
    final request = ++_customerLookupRequest;
    final phone = normaliseBdPhone(value);
    final hasValidPhone = RegExp(r'^8801\d{9}$').hasMatch(phone);
    final previousHistory = _customerHistory;
    if (previousHistory != null) {
      if (_buyerNameController.text == previousHistory.name) {
        _buyerNameController.clear();
      }
      if (_buyerAddressController.text == previousHistory.address) {
        _buyerAddressController.clear();
      }
    }

    setState(() {
      _customerHistory = null;
      _customerLookupError = null;
      _customerLookupComplete = false;
      _isLookingUpCustomer = hasValidPhone;
    });
    if (!hasValidPhone) return;

    _customerLookupTimer = Timer(const Duration(milliseconds: 350), () async {
      try {
        final history = await widget.onFindCustomer(phone);
        if (!mounted || request != _customerLookupRequest) return;
        setState(() {
          _customerHistory = history;
          _isLookingUpCustomer = false;
          _customerLookupComplete = true;
          if (history != null) {
            _buyerNameController.text = history.name;
            _buyerAddressController.text = history.address;
          }
        });
      } catch (error, stackTrace) {
        debugPrint('Looking up Bikrito customer failed: $error\n$stackTrace');
        if (!mounted || request != _customerLookupRequest) return;
        setState(() {
          _isLookingUpCustomer = false;
          _customerLookupError = error.toString();
        });
      }
    });
  }

  Future<void> _copyDraftForCourier() => copyCourierDetails(
    context: context,
    name: _buyerNameController.text,
    phone: normaliseBdPhone(_buyerPhoneController.text),
    address: _buyerAddressController.text,
    codAmount: _codDue,
    t: t,
  );

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

  Future<void> _saveOrder() async {
    if (!_canSave) return;
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
      paymentMethod: 'cod',
      createdAt: DateTime.now(),
      buyerName: _buyerNameController.text.trim(),
      buyerPhone: normaliseBdPhone(_buyerPhoneController.text),
      buyerAddress: _buyerAddressController.text.trim(),
      deliveryCharge: _deliveryCharge,
      advancePaid: _advancePaid,
      codDue: _codDue,
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
      debugPrint('Saving Bikrito order failed: $error\n$stackTrace');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${t('Could not save order', 'অর্ডার সংরক্ষণ হয়নি')}: $error',
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('E-Commerce Order', 'ই-কমার্স অর্ডার'),
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
            ? _emptyProducts()
            : Column(
                children: [
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                      children: [
                        _buildSearchBar(),
                        const SizedBox(height: 16),
                        _card(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              _SectionTitle(
                                title: _searchQuery.trim().isNotEmpty
                                    ? t('Search results', 'অনুসন্ধানের ফলাফল')
                                    : t('Most sold', 'সবচেয়ে বিক্রিত'),
                                subtitle: t(
                                  'Tap + to add products.',
                                  'পণ্য যোগ করতে + চাপুন।',
                                ),
                              ),
                              const SizedBox(height: 12),
                              if (_filteredProducts.isEmpty)
                                Padding(
                                  padding:
                                      const EdgeInsets.symmetric(vertical: 16),
                                  child: Text(
                                    t(
                                      'No matching products',
                                      'কোনো পণ্য পাওয়া যায়নি',
                                    ),
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: _orderMuted,
                                      fontSize: 12,
                                    ),
                                  ),
                                )
                              else ...[
                                ..._visibleProducts.map(_productTile),
                                if (!_showAllProducts &&
                                    _filteredProducts.length > 4)
                                  _seeAllButton(),
                              ],
                            ],
                          ),
                        ),
                        if (_selectedProducts.isNotEmpty) ...[
                          const SizedBox(height: 16),
                          _card(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    Text(
                                      t('Order items', 'অর্ডারের পণ্য'),
                                      style: const TextStyle(
                                        fontSize: 15,
                                        fontWeight: FontWeight.w800,
                                        color: _orderInk,
                                      ),
                                    ),
                                    Text(
                                      '${_selectedProducts.length} ${t('items', 'টি পণ্য')}',
                                      style: const TextStyle(
                                        fontSize: 12,
                                        color: _orderMuted,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 4),
                                ..._selectedProducts.map(_selectedItemTile),
                              ],
                            ),
                          ),
                        ],
                        const SizedBox(height: 16),
                        _customerCard(),
                        const SizedBox(height: 16),
                        _deliveryCard(),
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
                      child: Row(
                        children: [
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: OutlinedButton.icon(
                                onPressed: _canCopyCourier
                                    ? _copyDraftForCourier
                                    : null,
                                icon: const Icon(Icons.copy_rounded, size: 18),
                                label: Text(
                                  t('Copy for Courier', 'কুরিয়ারের জন্য কপি'),
                                ),
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: _orderRed,
                                  side: const BorderSide(color: _orderRed),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: SizedBox(
                              height: 52,
                              child: FilledButton(
                                onPressed: _canSave ? _saveOrder : null,
                                style: FilledButton.styleFrom(
                                  backgroundColor: _orderRed,
                                  disabledBackgroundColor: const Color(
                                    0xFFDDDDDD,
                                  ),
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
                                        '${t('Save order', 'অর্ডার সংরক্ষণ করুন')} · ৳${_formatMoney(_codDue)}',
                                        textAlign: TextAlign.center,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 14,
                                        ),
                                      ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
      ),
    );
  }

  Widget _emptyProducts() => Center(
    child: Padding(
      padding: const EdgeInsets.all(28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.inventory_2_outlined,
            color: _orderRed,
            size: 48,
          ),
          const SizedBox(height: 14),
          Text(
            t('Add products first', 'আগে পণ্য যোগ করুন'),
            style: const TextStyle(
              fontSize: 19,
              fontWeight: FontWeight.w800,
              color: _orderInk,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            t('Your product list is empty.', 'আপনার পণ্যের তালিকা খালি।'),
            style: const TextStyle(color: _orderMuted),
          ),
        ],
      ),
    ),
  );

  Widget _card({required Widget child}) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: const Color(0xFFECEAE7)),
    ),
    child: child,
  );

  Widget _buildSearchBar() => Container(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: TextField(
      controller: _searchController,
      onChanged: (value) => setState(() => _searchQuery = value),
      decoration: InputDecoration(
        hintText: t('Search products…', 'পণ্য খুজুন…'),
        prefixIcon: const Icon(Icons.search_rounded),
        suffixIcon: _searchQuery.isNotEmpty
            ? IconButton(
                icon: const Icon(Icons.close_rounded, size: 20),
                onPressed: () {
                  _searchController.clear();
                  setState(() => _searchQuery = '');
                },
              )
            : null,
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFECEAE7)),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: Color(0xFFECEAE7)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: _orderRed),
        ),
      ),
    ),
  );

  Widget _customerCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: t('Customer details', 'ক্রেতার তথ্য'),
          subtitle: t(
            'Name, phone and delivery address.',
            'নাম, ফোন এবং ডেলিভারি ঠিকানা।',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('order-customer-name'),
          controller: _buyerNameController,
          textCapitalization: TextCapitalization.words,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(
            t('Customer name', 'ক্রেতার নাম'),
            Icons.person_outline_rounded,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('order-customer-phone'),
          controller: _buyerPhoneController,
          keyboardType: TextInputType.phone,
          onChanged: _handleBuyerPhoneChanged,
          decoration: _inputDecoration(
            t('Customer phone', 'ক্রেতার ফোন'),
            Icons.phone_outlined,
          ),
        ),
        if (_isLookingUpCustomer) ...[
          const SizedBox(height: 6),
          Text(
            t('Checking past orders…', 'আগের অর্ডার খোঁজা হচ্ছে…'),
            style: const TextStyle(fontSize: 12, color: _orderMuted),
          ),
        ],
        if (_customerLookupError != null) ...[
          const SizedBox(height: 6),
          Text(
            '${t('Could not load customer history', 'ক্রেতার আগের তথ্য লোড হয়নি')}: $_customerLookupError',
            style: const TextStyle(fontSize: 12, color: _orderRed),
          ),
        ],
        if (_customerLookupComplete) ...[
          const SizedBox(height: 6),
          Text(
            t(
              'Past orders: ${_customerHistory?.orderCount ?? 0}',
              'আগের অর্ডার: ${_customerHistory?.orderCount ?? 0}',
            ),
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: _orderRed,
            ),
          ),
        ],
        const SizedBox(height: 10),
        TextField(
          key: const ValueKey('order-customer-address'),
          controller: _buyerAddressController,
          textCapitalization: TextCapitalization.sentences,
          maxLines: 3,
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(
            t('Delivery address', 'ডেলিভারি ঠিকানা'),
            Icons.home_outlined,
          ),
        ),
      ],
    ),
  );

  Widget _deliveryCard() => _card(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _SectionTitle(
          title: t('Delivery & payment', 'ডেলিভারি ও পেমেন্ট'),
          subtitle: t(
            'Delivery charge and advance amount.',
            'ডেলিারি চার্জ এবং আগাম টাকা।',
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _deliveryChip(70),
            _deliveryChip(130),
            _deliveryChip(null, label: t('Custom', 'কাস্টম')),
          ],
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _deliveryController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(
            t('Delivery charge', 'ডেলিভারি চার্জ'),
            Icons.local_shipping_outlined,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _discountController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(
            t('Discount', 'ছাড়'),
            Icons.local_offer_outlined,
          ),
        ),
        const SizedBox(height: 10),
        TextField(
          controller: _advanceController,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          inputFormatters: [
            FilteringTextInputFormatter.allow(RegExp(r'^\d*\.?\d{0,2}')),
          ],
          onChanged: (_) => setState(() {}),
          decoration: _inputDecoration(
            t('Advance paid', 'আগাম পেইড'),
            Icons.account_balance_wallet_outlined,
          ),
        ),
      ],
    ),
  );

  InputDecoration _inputDecoration(String hint, IconData icon) =>
      InputDecoration(
        hintText: hint,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFFAF9F7),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(13),
          borderSide: const BorderSide(color: Color(0xFFECEAE7)),
        ),
      );

  Widget _deliveryChip(double? value, {String? label}) {
    final current = double.tryParse(_deliveryController.text.trim()) ?? 0;
    final selected = value != null && current == value;
    return ChoiceChip(
      label: Text(label ?? '৳${value!.toStringAsFixed(0)}'),
      selected: selected,
      onSelected: (_) {
        if (value != null) {
          _deliveryController.text = value.toStringAsFixed(0);
        } else {
          _deliveryController.clear();
        }
        setState(() {});
      },
      selectedColor: const Color(0xFFFFEEEE),
      backgroundColor: Colors.white,
      side: BorderSide(color: selected ? _orderRed : const Color(0xFFECEAE7)),
      labelStyle: TextStyle(
        color: selected ? _orderRed : _orderInk,
        fontWeight: FontWeight.w700,
        fontSize: 12,
      ),
      showCheckmark: false,
    );
  }

  Widget _totalsCard() => _card(
    child: Column(
      children: [
        _TotalLine(label: t('Subtotal', 'উপমোট'), amount: _subtotal),
        if (_deliveryCharge > 0)
          _TotalLine(
            label: t('Delivery charge', 'ডেলিভারি চার্জ'),
            amount: _deliveryCharge,
          ),
        if (_discount > 0)
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
        if (_advancePaid > 0) ...[
          const SizedBox(height: 9),
          _TotalLine(
            label: t('Advance paid', 'আগাম পেইড'),
            amount: -_advancePaid,
            isDiscount: true,
          ),
        ],
        const SizedBox(height: 10),
        _TotalLine(
          label: t('COD Due', 'COD বাকি'),
          amount: _codDue,
          isGrandTotal: true,
          isCod: true,
        ),
      ],
    ),
  );

  Widget _seeAllButton() => Padding(
    padding: const EdgeInsets.only(top: 8),
    child: InkWell(
      onTap: () => setState(() => _showAllProducts = true),
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12),
        decoration: BoxDecoration(
          color: const Color(0xFFFFEEEE),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              t('See all', 'সব দেখুন'),
              style: const TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: _orderRed,
              ),
            ),
            const SizedBox(width: 4),
            const Icon(
              Icons.keyboard_arrow_down_rounded,
              color: _orderRed,
              size: 18,
            ),
          ],
        ),
      ),
    ),
  );

  Widget _selectedItemTile(ShopProduct product) {
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
                    color: _orderInk,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '৳${_formatMoney(product.price)} ${t('each', 'প্রতি')}',
                  style: const TextStyle(fontSize: 12, color: _orderMuted),
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
                color: _orderInk,
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
                color: _orderRed,
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
                color: _orderRed,
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
            color: _orderRed,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
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
                    color: _orderInk,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '৳${_formatMoney(product.price)}',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _orderRed,
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
                color: qty > 0 ? const Color(0xFFFFEEEE) : _orderRed,
                borderRadius: BorderRadius.circular(9),
              ),
              child: Icon(
                qty > 0 ? Icons.check_rounded : Icons.add_rounded,
                size: 18,
                color: qty > 0 ? _orderRed : Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(ShopProduct product, {double size = 42}) {
    Widget child;
    if (product.imageData != null && product.imageData!.isNotEmpty) {
      child = Image.memory(base64Decode(product.imageData!), fit: BoxFit.cover);
    } else if (product.imagePath != null && product.imagePath!.isNotEmpty) {
      child = Image.file(File(product.imagePath!), fit: BoxFit.cover);
    } else {
      child = const Center(
        child: Icon(Icons.inventory_2_outlined, color: _orderRed, size: 20),
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
          color: _orderInk,
        ),
      ),
      if (subtitle != null) ...[
        const SizedBox(height: 3),
        Text(
          subtitle!,
          style: const TextStyle(fontSize: 12, color: _orderMuted),
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
    this.isCod = false,
  });
  final String label;
  final double amount;
  final bool isDiscount, isGrandTotal, isCod;
  @override
  Widget build(BuildContext context) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: TextStyle(
            fontSize: isGrandTotal ? 16 : 13,
            fontWeight: isGrandTotal ? FontWeight.w800 : FontWeight.w500,
            color: isGrandTotal || isCod ? _orderInk : _orderMuted,
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
              : (isGrandTotal || isCod ? _orderRed : _orderInk),
        ),
      ),
    ],
  );
}

String _formatMoney(double value) => value == value.roundToDouble()
    ? value.toStringAsFixed(0)
    : value.toStringAsFixed(2);
