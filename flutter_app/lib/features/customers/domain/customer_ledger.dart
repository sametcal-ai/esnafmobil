import 'customer.dart';
import '../../../core/models/auditable.dart';

enum LedgerEntryType {
  sale,
  payment,
}

class CustomerLedgerEntry {
  final String id;
  final String customerId;
  final LedgerEntryType type;
  final double amount;
  final String? note;
  final DateTime createdAt;
  /// İlgili satış kaydının ID'si (opsiyonel, eski kayıtlar için null olabilir).
  final String? saleId;
  final AuditMeta meta;

  const CustomerLedgerEntry({
    required this.id,
    required this.customerId,
    required this.type,
    required this.amount,
    required this.note,
    required this.createdAt,
    this.saleId,
    required this.meta,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'customerId': customerId,
      'type': type.name,
      'amount': amount,
      'note': note,
      'createdAt': createdAt.millisecondsSinceEpoch,
      'saleId': saleId,
      ...meta.toMap(),
    };
  }

  factory CustomerLedgerEntry.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);
    final typeName = (map['type'] as String?) ?? 'sale';
    final type = typeName == 'payment'
        ? LedgerEntryType.payment
        : LedgerEntryType.sale;

    final createdAt = DateTime.fromMillisecondsSinceEpoch(
      (map['createdAt'] as int?) ?? 0,
    );
    final meta = AuditMeta.fromMap(
      map,
      fallbackCreatedAt: createdAt,
    );

    return CustomerLedgerEntry(
      id: map['id'] as String,
      customerId: map['customerId'] as String,
      type: type,
      amount: (map['amount'] as num).toDouble(),
      note: map['note'] as String?,
      createdAt: createdAt,
      saleId: map['saleId'] as String?,
      meta: meta,
    );
  }
}

class CustomerBalance {
  final Customer customer;
  final double balance;

  const CustomerBalance({
    required this.customer,
    required this.balance,
  });
}