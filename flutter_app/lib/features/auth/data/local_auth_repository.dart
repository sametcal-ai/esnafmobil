import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../../../core/models/auditable.dart';
import '../domain/user.dart';

class LocalAuthRepository {
  static const String usersBoxName = 'users';
  static const String sessionBoxName = 'session';
  static const String _sessionUserIdKey = 'currentUserId';

  Box get _usersBox => Hive.box(usersBoxName);
  Box get _sessionBox => Hive.box(sessionBoxName);

  /// Uygulama ilk açıldığında varsayılan admin oluştur.
  ///
  /// username: admin
  /// password: admin123
  Future<void> ensureDefaultAdminUser() async {
    if (_usersBox.isEmpty) {
      final meta = AuditMeta.create(createdBy: 'system');
      final admin = User(
        id: '1',
        username: 'admin',
        passwordHash: _hashPassword('admin123', 'admin'),
        role: UserRole.admin,
        meta: meta,
      );
      await _usersBox.put(admin.id, admin.toMap());
    }
  }

  String _hashPassword(String password, String salt) {
    final bytes = utf8.encode('$salt::$password');
    final digest = sha256.convert(bytes);
    return digest.toString();
  }

  Future<User?> authenticate(String username, String password) async {
    final allUsers = _usersBox.values;
    for (final dynamic raw in allUsers) {
      if (raw is Map) {
        final user = User.fromMap(raw);
        if (user.username == username) {
          final hash = _hashPassword(password, username);
          if (hash == user.passwordHash) {
            await _persistSession(user.id);
            return user;
          }
          return null;
        }
      }
    }
    return null;
  }

  Future<void> _persistSession(String userId) async {
    await _sessionBox.put(_sessionUserIdKey, userId);
  }

  Future<void> clearSession() async {
    await _sessionBox.delete(_sessionUserIdKey);
  }

  Future<User?> getCurrentUser() async {
    final userId = _sessionBox.get(_sessionUserIdKey);
    if (userId is! String) return null;
    final raw = _usersBox.get(userId);
    if (raw is! Map) return null;
    return User.fromMap(raw);
  }

  Future<List<User>> getAllUsers() async {
    return _usersBox.values
        .whereType<Map>()
        .where(isActiveRecordMap)
        .map((map) => User.fromMap(map))
        .toList(growable: false);
  }

  /// Kullanıcıyı soft delete ile siler.
  /// Kaydı Hive'dan fiziksel olarak kaldırmaz, sadece isDeleted/isVisible/isActived bayraklarını günceller.
  Future<void> softDeleteUser(String userId) async {
    final raw = _usersBox.get(userId);
    if (raw is! Map) return;
    final user = User.fromMap(raw);
    final deletedMeta = user.meta.softDelete(modifiedBy: 'system');
    final updated = user.copyWith(meta: deletedMeta);
    await _usersBox.put(user.id, updated.toMap());
  }

  Future<User?> createUser({
    required String username,
    required String password,
    required UserRole role,
    String? currentUserId,
  }) async {
    // Aynı kullanıcı adıyla kayıt var mı kontrol et.
    final existingUsers = await getAllUsers();
    final exists = existingUsers.any(
      (u) => u.username.toLowerCase() == username.toLowerCase(),
    );
    if (exists) {
      return null;
    }

    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final meta = AuditMeta.create(createdBy: 'system');
    final user = User(
      id: id,
      username: username,
      passwordHash: _hashPassword(password, username),
      role: role,
      meta: meta,
    );
    await _usersBox.put(id, user.toMap());
    return user;
  }

  Future<User?> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final raw = _usersBox.get(userId);
    if (raw is! Map) return null;
    final user = User.fromMap(raw);

    final currentHash = _hashPassword(currentPassword, user.username);
    if (currentHash != user.passwordHash) {
      return null;
    }

    final updatedMeta = user.meta.touch(
      modifiedBy: 'system',
      bumpVersion: true,
    );

    final updated = user.copyWith(
      passwordHash: _hashPassword(newPassword, user.username),
      meta: updatedMeta,
    );
    await _usersBox.put(user.id, updated.toMap());
    return updated;
  }
}