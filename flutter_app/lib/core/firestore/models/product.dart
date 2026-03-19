import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/auditable.dart';

class ProductParameters {
  final int criticalStockLevel;
  final int safeStockLevel;
  final bool autoPrice;

  const ProductParameters({
    this.criticalStockLevel = 0,
    this.safeStockLevel = 0,
    this.autoPrice = false,
  });

  ProductParameters copyWith({
    int? criticalStockLevel,
    int? safeStockLevel,
    bool? autoPrice,
  }) {
    return ProductParameters(
      criticalStockLevel: criticalStockLevel ?? this.criticalStockLevel,
      safeStockLevel: safeStockLevel ?? this.safeStockLevel,
      autoPrice: autoPrice ?? this.autoPrice,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'criticalStockLevel': criticalStockLevel,
      'safeStockLevel': safeStockLevel,
      'autoPrice': autoPrice,
    };
  }

  factory ProductParameters.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const ProductParameters();

    final critical = map['criticalStockLevel'];
    final safe = map['safeStockLevel'];
    final auto = map['autoPrice'];

    return ProductParameters(
      criticalStockLevel:
          critical is num ? critical.toInt() : int.tryParse('$critical') ?? 0,
      safeStockLevel: safe is num ? safe.toInt() : int.tryParse('$safe') ?? 0,
      autoPrice: auto is bool ? auto : auto?.toString().toLowerCase() == 'true',
    );
  }
}

class Product {
  final String id;
  final String name;
  final String brand;
  final String barcode;
  /// Dış servisten gelen ürün görseli URL'si (opsiyonel).
  final String? imageUrl;
  final List<String> tags;
  final int stockQuantity;
  /// Son alış fiyatı.
  final double lastPurchasePrice;
  /// Ürün için tanımlı satış fiyatı (KDV hariç).
  final double salePrice;
  /// Ürün bazlı kâr marjı (%) – alış fiyatına göre.
  final double marginPercent;
  /// Satış fiyatı manuel olarak mı girildi?
  /// true ise, stok girişiyle alış fiyatı değiştiğinde otomatik güncellenmez.
  final bool isManualPrice;

  /// Ürün özel parametreleri.
  final ProductParameters parameters;

  /// Dış ürün arama servisinden gelen fiyat bilgileri.
  /// Bu alanlar yalnızca referans amaçlıdır; ürünün kendi satış fiyatı için
  /// [salePrice] kullanılmaya devam edilir.
  final double? externalPrice;
  final double? externalTax;
  final double? externalTaxRate;
  final double? externalTotal;

  /// Barkod ile dış API sorgusu yapılan tarih/zaman bilgisi.
  final DateTime? externalDate;

  /// Ortak denetim ve soft-state alanları.
  final AuditMeta meta;

  const Product({
    required this.id,
    required this.name,
    required this.brand,
    required this.barcode,
    this.imageUrl,
    required this.tags,
    required this.stockQuantity,
    required this.lastPurchasePrice,
    this.salePrice = 0,
    this.marginPercent = 0,
    this.isManualPrice = false,
    this.parameters = const ProductParameters(),
    this.externalPrice,
    this.externalTax,
    this.externalTaxRate,
    this.externalTotal,
    this.externalDate,
    required this.meta,
  });

  Product copyWith({
    String? id,
    String? name,
    String? brand,
    String? barcode,
    String? imageUrl,
    List<String>? tags,
    int? stockQuantity,
    double? lastPurchasePrice,
    double? salePrice,
    double? marginPercent,
    bool? isManualPrice,
    ProductParameters? parameters,
    double? externalPrice,
    double? externalTax,
    double? externalTaxRate,
    double? externalTotal,
    DateTime? externalDate,
    AuditMeta? meta,
  }) {
    return Product(
      id: id ?? this.id,
      name: name ?? this.name,
      brand: brand ?? this.brand,
      barcode: barcode ?? this.barcode,
      imageUrl: imageUrl ?? this.imageUrl,
      tags: tags ?? this.tags,
      stockQuantity: stockQuantity ?? this.stockQuantity,
      lastPurchasePrice: lastPurchasePrice ?? this.lastPurchasePrice,
      salePrice: salePrice ?? this.salePrice,
      marginPercent: marginPercent ?? this.marginPercent,
      isManualPrice: isManualPrice ?? this.isManualPrice,
      parameters: parameters ?? this.parameters,
      externalPrice: externalPrice ?? this.externalPrice,
      externalTax: externalTax ?? this.externalTax,
      externalTaxRate: externalTaxRate ?? this.externalTaxRate,
      externalTotal: externalTotal ?? this.externalTotal,
      externalDate: externalDate ?? this.externalDate,
      meta: meta ?? this.meta,
    );
  }

  /// Hive/legacy Map serileştirmesi (epoch millis).
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'tags': tags,
      'stockQuantity': stockQuantity,
      'lastPurchasePrice': lastPurchasePrice,
      'salePrice': salePrice,
      'marginPercent': marginPercent,
      'isManualPrice': isManualPrice,
      'parameters': parameters.toMap(),
      'externalPrice': externalPrice,
      'externalTax': externalTax,
      'externalTaxRate': externalTaxRate,
      'externalTotal': externalTotal,
      'externalDate': externalDate?.toIso8601String(),
      ...meta.toMap(),
    };
  }

  /// Firestore serileştirmesi (Timestamp).
  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'name': name,
      'brand': brand,
      'barcode': barcode,
      'imageUrl': imageUrl,
      'tags': tags,
      'stockQuantity': stockQuantity,
      'lastPurchasePrice': lastPurchasePrice,
      'salePrice': salePrice,
      'marginPercent': marginPercent,
      'isManualPrice': isManualPrice,
      'parameters': parameters.toMap(),
      'externalPrice': externalPrice,
      'externalTax': externalTax,
      'externalTaxRate': externalTaxRate,
      'externalTotal': externalTotal,
      'externalDate': externalDate == null
          ? null
          : Timestamp.fromDate(externalDate!),
      ...meta.toFirestoreMap(),
    };
  }

  factory Product.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);
    final rawTags = map['tags'];
    final tags = rawTags is List
        ? rawTags.map((e) => e.toString()).toList(growable: false)
        : const <String>[];

    DateTime? externalDate;
    final rawExternalDate = map['externalDate'];
    if (rawExternalDate is String && rawExternalDate.isNotEmpty) {
      externalDate = DateTime.tryParse(rawExternalDate);
    } else if (rawExternalDate is DateTime) {
      externalDate = rawExternalDate;
    } else if (rawExternalDate is Timestamp) {
      externalDate = rawExternalDate.toDate();
    } else if (rawExternalDate is int) {
      externalDate = DateTime.fromMillisecondsSinceEpoch(rawExternalDate);
    }

    final meta = AuditMeta.fromMap(map);

    final rawParameters = map['parameters'];
    final parameters = rawParameters is Map
        ? ProductParameters.fromMap(Map<String, dynamic>.from(rawParameters))
        : const ProductParameters();

    return Product(
      id: map['id'] as String,
      name: map['name'] as String,
      brand: (map['brand'] as String?) ?? '',
      barcode: (map['barcode'] as String?) ?? '',
      imageUrl: (map['imageUrl'] as String?),
      tags: tags,
      stockQuantity: (map['stockQuantity'] as int?) ?? 0,
      lastPurchasePrice: (map['lastPurchasePrice'] as num?)?.toDouble() ?? 0,
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0,
      marginPercent: (map['marginPercent'] as num?)?.toDouble() ?? 0,
      isManualPrice: (map['isManualPrice'] as bool?) ?? false,
      parameters: parameters,
      externalPrice: (map['externalPrice'] as num?)?.toDouble(),
      externalTax: (map['externalTax'] as num?)?.toDouble(),
      externalTaxRate: (map['externalTaxRate'] as num?)?.toDouble(),
      externalTotal: (map['externalTotal'] as num?)?.toDouble(),
      externalDate: externalDate,
      meta: meta,
    );
  }

  factory Product.fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) {
      final fallback = AuditMeta.create(createdBy: 'system', now: DateTime.now());
      return Product(
        id: snap.id,
        name: '',
        brand: '',
        barcode: '',
        tags: const <String>[],
        stockQuantity: 0,
        lastPurchasePrice: 0,
        meta: fallback,
      );
    }

    final map = <String, dynamic>{...data};
    map['id'] ??= snap.id;
    return Product.fromMap(map);
  }
}
