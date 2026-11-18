import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/shop_product.dart';
import '../widgets/bikrito_bottom_navigation.dart';

const _productsRed = Color(0xFFD83B3B);
const _productsInk = Color(0xFF252525);
const _productsMuted = Color(0xFF858585);

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({
    super.key,
    required this.products,
    required this.t,
    required this.onNavigate,
    required this.onNewSale,
    required this.onAdd,
    required this.onDelete,
    required this.onRefresh,
  });

  final List<ShopProduct> products;
  final String Function(String, String) t;
  final ValueChanged<int> onNavigate;
  final VoidCallback onNewSale;
  final Future<void> Function() onAdd;
  final Future<void> Function(int productId) onDelete;
  final Future<List<ShopProduct>> Function() onRefresh;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  late List<ShopProduct> _products = List.of(widget.products);

  @override
  void didUpdateWidget(covariant ProductsScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.products != widget.products) {
      _products = List.of(widget.products);
    }
  }

  Future<void> _addProduct() async {
    await widget.onAdd();
    final products = await widget.onRefresh();
    if (mounted) setState(() => _products = products);
  }

  Future<void> _deleteProduct(ShopProduct product) async {
    if (product.id == null) return;
    await widget.onDelete(product.id!);
    final products = await widget.onRefresh();
    if (mounted) setState(() => _products = products);
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.t;
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Products', 'পণ্য'),
          style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800),
        ),
        actions: [
          IconButton.filled(
            onPressed: _addProduct,
            tooltip: t('Add product', 'পণ্য যোগ করুন'),
            style: IconButton.styleFrom(
              backgroundColor: _productsRed,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.add_rounded),
          ),
          const SizedBox(width: 12),
        ],
      ),
      body: _products.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.inventory_2_outlined,
                      color: _productsRed,
                      size: 48,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      t('No products yet', 'এখনও কোনো পণ্য নেই'),
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w800,
                        color: _productsInk,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      t(
                        'Add products to start making sales.',
                        'বিক্রি শুরু করতে পণ্য যোগ করুন।',
                      ),
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: _productsMuted),
                    ),
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      onPressed: _addProduct,
                      icon: const Icon(Icons.add_rounded),
                      label: Text(t('Add product', 'পণ্য যোগ করুন')),
                      style: FilledButton.styleFrom(
                        backgroundColor: _productsRed,
                      ),
                    ),
                  ],
                ),
              ),
            )
          : ListView.separated(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 28),
              itemCount: _products.length,
              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, index) {
                final product = _products[index];
                return Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(17),
                    border: Border.all(color: const Color(0xFFECEAE7)),
                  ),
                  child: Row(
                    children: [
                      _ProductThumbnail(
                        path: product.imagePath,
                        imageData: product.imageData,
                      ),
                      const SizedBox(width: 13),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              product.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w700,
                                color: _productsInk,
                              ),
                            ),
                            const SizedBox(height: 5),
                            Text(
                              '৳${_productMoney(product.price)}',
                              style: const TextStyle(
                                color: _productsRed,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ],
                        ),
                      ),
                      PopupMenuButton<String>(
                        onSelected: (value) {
                          if (value == 'delete') _deleteProduct(product);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                            value: 'delete',
                            child: Text(t('Remove product', 'পণ্য সরান')),
                          ),
                        ],
                      ),
                    ],
                  ),
                );
              },
            ),
      bottomNavigationBar: BikritoBottomBar(
        selectedIndex: 1,
        t: t,
        onNavigate: widget.onNavigate,
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerDocked,
      floatingActionButton: BikritoSaleButton(
        t: t,
        onPressed: widget.onNewSale,
      ),
    );
  }
}

class _ProductThumbnail extends StatelessWidget {
  const _ProductThumbnail({this.path, this.imageData});
  final String? path;
  final String? imageData;

  @override
  Widget build(BuildContext context) {
    Widget image;
    if (kIsWeb && imageData != null) {
      image = Image.memory(base64Decode(imageData!), fit: BoxFit.cover);
    } else if (!kIsWeb && path != null) {
      image = Image.file(File(path!), fit: BoxFit.cover);
    } else {
      image = const Icon(Icons.inventory_2_outlined, color: _productsRed);
    }
    return ClipRRect(
      borderRadius: BorderRadius.circular(12),
      child: SizedBox(
        width: 58,
        height: 58,
        child: Container(color: const Color(0xFFFFEEEE), child: image),
      ),
    );
  }
}

String _productMoney(double price) => price == price.roundToDouble()
    ? price.toStringAsFixed(0)
    : price.toStringAsFixed(2);
