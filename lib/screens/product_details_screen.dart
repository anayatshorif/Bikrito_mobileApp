import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import '../models/shop_product.dart';

const _detailsRed = Color(0xFFD83B3B);
const _detailsInk = Color(0xFF252525);

class ProductDetailsScreen extends StatelessWidget {
  const ProductDetailsScreen({
    super.key,
    required this.product,
    required this.t,
    this.onNewSale,
  });

  final ShopProduct product;
  final String Function(String, String) t;
  final VoidCallback? onNewSale;

  @override
  Widget build(BuildContext context) {
    final heroTag = product.id != null ? 'product-photo-${product.id}' : null;
    final picture = _ProductPicture(
      path: product.imagePath,
      imageData: product.imageData,
    );
    return Scaffold(
      appBar: AppBar(
        title: Text(
          t('Product details', 'পণ্যের তথ্য'),
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
        ),
        centerTitle: false,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(22, 12, 22, 28),
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: AspectRatio(
                aspectRatio: 1,
                child: heroTag == null
                    ? picture
                    : Hero(tag: heroTag, child: picture),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              product.name,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                color: _detailsInk,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '৳${_detailsMoney(product.price)}',
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: _detailsRed,
              ),
            ),
            const SizedBox(height: 28),
            if (onNewSale != null)
              SizedBox(
                height: 54,
                child: FilledButton.icon(
                  onPressed: onNewSale,
                  icon: const Icon(Icons.point_of_sale_rounded),
                  label: Text(
                    t('Create a sale', 'বিক্রি তৈরি করুন'),
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: _detailsRed,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(15),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ProductPicture extends StatelessWidget {
  const _ProductPicture({this.path, this.imageData});
  final String? path;
  final String? imageData;

  @override
  Widget build(BuildContext context) {
    if (imageData != null && imageData!.isNotEmpty) {
      return Image.memory(
        base64Decode(imageData!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    if (!kIsWeb && path != null && path!.isNotEmpty) {
      return Image.file(
        File(path!),
        fit: BoxFit.cover,
        errorBuilder: (_, __, ___) => _placeholder(),
      );
    }
    return _placeholder();
  }

  Widget _placeholder() => Container(
    color: const Color(0xFFFFEEEE),
    alignment: Alignment.center,
    child: const Icon(
      Icons.inventory_2_outlined,
      color: _detailsRed,
      size: 64,
    ),
  );
}

String _detailsMoney(double price) => price == price.roundToDouble()
    ? price.toStringAsFixed(0)
    : price.toStringAsFixed(2);
