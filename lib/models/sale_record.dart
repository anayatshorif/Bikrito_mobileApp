class SaleItem {
  const SaleItem({
    this.productId,
    required this.name,
    required this.unitPrice,
    required this.quantity,
  });

  final int? productId;
  final String name;
  final double unitPrice;
  final int quantity;

  double get lineTotal => unitPrice * quantity;
}

class SaleRecord {
  const SaleRecord({
    this.id,
    required this.items,
    required this.subtotal,
    required this.discount,
    required this.total,
    required this.paymentMethod,
    required this.createdAt,
    this.buyerName = '',
    this.buyerPhone = '',
  });

  final int? id;
  final List<SaleItem> items;
  final double subtotal;
  final double discount;
  final double total;
  final String paymentMethod;
  final DateTime createdAt;
  final String buyerName;
  final String buyerPhone;

  SaleRecord withId(int saleId) => SaleRecord(
    id: saleId,
    items: items,
    subtotal: subtotal,
    discount: discount,
    total: total,
    paymentMethod: paymentMethod,
    createdAt: createdAt,
    buyerName: buyerName,
    buyerPhone: buyerPhone,
  );
}
