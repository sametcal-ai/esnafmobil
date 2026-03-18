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

  static String? _readNullableString(dynamic value) {
    if (value == null) return null;
    if (value is String) return value.trim();
    return value.toString().trim();
  }

  static String _readString(dynamic value) {
    return _readNullableString(value) ?? '';
  }

  factory ExternalProduct.fromJson(Map<String, dynamic> json) {
    return ExternalProduct(
      // Bazı servisler barkodu numara olarak döndürebiliyor.
      barcode: _readString(json['barcode']),
      brand: _readNullableString(json['brand']),
      category: _readNullableString(json['category']),
      imageUrl: _readNullableString(json['imageUrl']),
      markets: json['markets'],
      name: _readNullableString(json['name']),
      price: (json['price'] as num?)?.toDouble(),
      salesUnit: _readNullableString(json['salesUnit']),
      tax: (json['tax'] as num?)?.toDouble(),
      taxRate: (json['taxRate'] as num?)?.toDouble(),
      total: (json['total'] as num?)?.toDouble(),
    );
  }
}