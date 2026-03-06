class ExternalProduct {
  final String barcode;
  final String? brand;
  final String? category;
  final String? imageUrl;
  final dynamic markets;
  final String? name;
  final double? price;
  final String? salesUnit;
  final double? tax;
  final double? taxRate;
  final double? total;

  const ExternalProduct({
    required this.barcode,
    this.brand,
    this.category,
    this.imageUrl,
    this.markets,
    this.name,
    this.price,
    this.salesUnit,
    this.tax,
    this.taxRate,
    this.total,
  });

  factory ExternalProduct.fromJson(Map<String, dynamic> json) {
    return ExternalProduct(
      barcode: (json['barcode'] as String?)?.trim() ?? '',
      brand: (json['brand'] as String?)?.trim(),
      category: (json['category'] as String?)?.trim(),
      imageUrl: (json['imageUrl'] as String?)?.trim(),
      markets: json['markets'],
      name: (json['name'] as String?)?.trim(),
      price: (json['price'] as num?)?.toDouble(),
      salesUnit: (json['salesUnit'] as String?)?.trim(),
      tax: (json['tax'] as num?)?.toDouble(),
      taxRate: (json['taxRate'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
    );
  }
}