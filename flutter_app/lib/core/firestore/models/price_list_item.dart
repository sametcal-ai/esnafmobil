import 'package:cloud_firestore/cloud_firestore.dart';

import '../../models/auditable.dart';

class PriceListItem {
  final String id;
  final String productId;

  final double purchasePrice;
  final double salePrice;

  /// Fiyatın başka bir listeden taşındığını belirtir.
  final bool isInherited;
  final String? inheritedFromPriceListId;

  final AuditMeta meta;

  const PriceListItem({
    required this.id,
    required this.productId,
    required this.purchasePrice,
    required this.salePrice,
    required this.isInherited,
    this.inheritedFromPriceListId,
    required this.meta,
  });

  PriceListItem copyWith({
    String? id,
    String? productId,
    double? purchasePrice,
    double? salePrice,
    bool? isInherited,
    String? inheritedFromPriceListId,
    AuditMeta? meta,
  }) {
    return PriceListItem(
      id: id ?? this.id,
      productId: productId ?? this.productId,
      purchasePrice: purchasePrice ?? this.purchasePrice,
      salePrice: salePrice ?? this.salePrice,
      isInherited: isInherited ?? this.isInherited,
      inheritedFromPriceListId:
          inheritedFromPriceListId ?? this.inheritedFromPriceListId,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toFirestoreMap() {
    return {
      'id': id,
      'productId': productId,
      'purchasePrice': purchasePrice,
      'salePrice': salePrice,
      'isInherited': isInherited,
      'inheritedFromPriceListId': inheritedFromPriceListId,
      ...meta.toFirestoreMap(),
    };
  }

  factory PriceListItem.fromMap(Map<String, dynamic> map) {
    final meta = AuditMeta.fromMap(map);
    return PriceListItem(
      id: (map['id'] as String?) ?? '',
      productId: (map['productId'] as String?) ?? '',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? 0,
      salePrice: (map['salePrice'] as num?)?.toDouble() ?? 0,
      isInherited: (map['isInherited'] as bool?) ?? false,
      inheritedFromPriceListId: map['inheritedFromPriceListId'] as String?,
      meta: meta,
    );
  }

  factory PriceListItem.fromDoc(DocumentSnapshot<Map<String, dynamic>> snap) {
    final data = snap.data();
    if (data == null) {
      final now = DateTime.now();
      final fallback = AuditMeta.create(createdBy: 'system', now: now);
      return PriceListItem(
        id: snap.id,
        productId: '',
        purchasePrice: 0,
        salePrice: 0,
        isInherited: false,
        meta: fallback,
      );
    }

    final map = <String, dynamic>{...data};
    map['id'] ??= snap.id;
    return PriceListItem.fromMap(map);
  }
}
