import '../../../core/models/auditable.dart';

class SupplierLedgerEntry {
  final String id;
  final String supplierId;
  final SupplierLedgerEntryType type;
  final double amount;
  final String? note;
  final DateTime createdAt;
  final AuditMeta meta;

  const SupplierLedgerEntry({
    required this.id,
    required this.supplierId,
    required this.type,
    required this.amount,
    required this.note,
    required this.createdAt,
    required this.meta,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'supplierId': supplierId,
      'type': type.name,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
      ...meta.toMap(),
    };
  }

  factory SupplierLedgerEntry.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);
    final typeName = (map['type'] as String?) ?? 'purchase';
    final type = typeName == 'payment'
        ? SupplierLedgerEntryType.payment
        : SupplierLedgerEntryType.purchase;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] as int?) ?? 0,
    );
    final meta = AuditMeta.fromMap(
      map,
      fallbackCreatedAt: createdAt,
    );

    return SupplierLedgerEntry(
      id: map['id'] as String,
      supplierId: map['supplierId'] as String,
      type: type,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: createdAt,
      meta: meta,
    );
  }
}

enum SupplierLedgerEntryType {
  purchase,
  payment,
}
