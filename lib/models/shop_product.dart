class ShopProduct {
  const ShopProduct({
    this.id,
    required this.name,
    required this.price,
    this.imagePath,
    this.imageData,
  });

  final int? id;
  final String name;
  final double price;
  final String? imagePath;
  final String? imageData;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'price': price,
    'imagePath': imagePath,
    'imageData': imageData,
  };

  factory ShopProduct.fromJson(Map<String, dynamic> json) => ShopProduct(
    id: json['id'] as int?,
    name: json['name'] as String? ?? '',
    price: (json['price'] as num? ?? 0).toDouble(),
    imagePath: (json['imagePath'] ?? json['image_path']) as String?,
    imageData: (json['imageData'] ?? json['image_data']) as String?,
  );
}

ShopProduct productWithId(ShopProduct product, int id) => ShopProduct(
  id: id,
  name: product.name,
  price: product.price,
  imagePath: product.imagePath,
  imageData: product.imageData,
);
