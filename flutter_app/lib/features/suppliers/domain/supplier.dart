import '../../../core/models/auditable.dart';

class Supplier {
  final String id;
  final String name;
  final String? phone;
  final String? address;
  final String? note;
  final AuditMeta meta;

  const Supplier({
    required this.id,
    required this.name,
    this.phone,
    this.address,
    this.note,
    required this.meta,
  });

  Supplier copyWith({
    String? id,
    String? name,
    String? phone,
    String? address,
    String? note,
    AuditMeta? meta,
  }) {
    return Supplier(
      id: id ?? this.id,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      address: address ?? this.address,
      note: note ?? this.note,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'phone': phone,
      'address': address,
      'note': note,
      ...meta.toMap(),
    };
  }

  factory Supplier.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);
    final meta = AuditMeta.fromMap(map);
    return Supplier(
      id: map['id'] as String,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      address: map['address'] as String?,
      note: map['note'] as String?,
      meta: meta,
    );
  }
}