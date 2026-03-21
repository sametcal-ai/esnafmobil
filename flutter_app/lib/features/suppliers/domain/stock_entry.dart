import '../../../core/models/auditable.dart';

enum StockMovementType {
  incoming,
  outgoing,
}

class StockEntry {
  final String id;
  final String? supplierId;
  final String? supplierName;
  final String productId;
  final int quantity;
  final double unitCost;
  final DateTime createdAt;
  final StockMovementType type;
  final String? saleId;
  final AuditMeta meta;

  const StockEntry({
    required this.id,
    required this.supplierId,
    required this.supplierName,
    required this.productId,
    required this.quantity,
    required this.unitCost,
    required this.createdAt,
    required this.type,
    required this.saleId,
    required this.meta,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierId': supplierId,
      'supplierName': supplierName,
      'productId': productId,
      'quantity': quantity,
      'unitCost': unitCost,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'type': type.name,
      'saleId': saleId,
      ...meta.toMap(),
    };
  }

  factory StockEntry.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);
    final typeName = (map['type'] as String?) ?? 'incoming';
    final type = typeName == 'outgoing'
        ? StockMovementType.outgoing
        : StockMovementType.incoming;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] as int?) ?? 0,
    );
    final meta = AuditMeta.fromMap(
      map,
      fallbackCreatedAt: createdAt,
    );

    return StockEntry(
      id: map['id'] as String,
      supplierId: map['supplierId'] as String?,
      supplierName: map['supplierName'] as String?,
      productId: map['productId'] as String,
      quantity: map['quantity'] as int,
      unitCost: (map['unitCost'] as num).toDouble(),
      createdAt: createdAt,
      type: type,
      saleId: map['saleId'] as String?,
      meta: meta,
    );
  }
}