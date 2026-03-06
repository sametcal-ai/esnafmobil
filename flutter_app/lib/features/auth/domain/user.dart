import '../../../core/models/auditable.dart';

enum UserRole {
  admin,
  cashier,
}

class User {
  final String id;
  final String username;
  final String passwordHash;
  final UserRole role;
  final AuditMeta meta;

  const User({
    required this.id,
    required this.username,
    required this.passwordHash,
    required this.role,
    required this.meta,
  });

  User copyWith({
    String? id,
    String? username,
    String? passwordHash,
    UserRole? role,
    AuditMeta? meta,
  }) {
    return User(
      id: id ?? this.id,
      username: username ?? this.username,
      passwordHash: passwordHash ?? this.passwordHash,
      role: role ?? this.role,
      meta: meta ?? this.meta,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'username': username,
      'passwordHash': passwordHash,
      'role': role.name,
      ...meta.toMap(),
    };
  }

  factory User.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap);
    final roleName = (map['role'] as String?) ?? 'cashier';
    final meta = AuditMeta.fromMap(map);
    return User(
      id: map['id'] as String,
      username: map['username'] as String,
      passwordHash: map['passwordHash'] as String,
      role: roleName == 'admin' ? UserRole.admin : UserRole.cashier,
      meta: meta,
    );
  }
}