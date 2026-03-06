import '../../../core/models/auditable.dart';

class Customer {
  final String id;
  final String? code;
  final String name;
  final String? phone;
  final String? email;
  final String? workplace;
  final String? note;
  final AuditMeta meta;

  const Customer({
    required this.id,
    this.code,
    required this.name,
    this.phone,
    this.email,
    this.workplace,
    this.note,
    required this.meta,
  });

  Customer copyWith({
    String? id,
    String? code,
    String? name,
    String? phone,
    String? email,
    String? workplace,
    String? note,
    AuditMeta? meta,
  }) {
    return Customer(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      workplace: workplace ?? this.workplace,
      note: note ?? this.note,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'code': code,
      'name': name,
      'phone': phone,
      'email': email,
      'workplace': workplace,
      'note': note,
      ...meta.toMap(),
    };
  }

  factory Customer.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);
    final meta = AuditMeta.fromMap(map);
    return Customer(
      id: map['id'] as String,
      code: map['code'] as String?,
      name: map['name'] as String,
      phone: map['phone'] as String?,
      email: map['email'] as String?,
      workplace: map['workplace'] as String?,
      note: map['note'] as String?,
      meta: meta,
    );
  }
}