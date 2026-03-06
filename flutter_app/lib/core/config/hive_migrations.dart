import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

/// Basit Hive veri migrasyonları.
/// Uygulama açılışında kutular açıldıktan sonra çağrılmalıdır.
class HiveMigrations {
  static const _uuid = Uuid();

  static Future<void> runAll() async {
    await _ensureIdsInBox('products');
    await _ensureIdsInBox('customers');
    await _ensureIdsInBox('suppliers');
    await _ensureIdsInBox('customer_ledger');
    await _ensureIdsInBox('supplier_ledger');
    await _ensureIdsInBox('stock_entries');
    await _ensureIdsInBox('sales');
    await _ensureIdsInBox('users');

    await _ensureAuditFields('users');
    await _ensureAuditFields('customers');
    await _ensureAuditFields('suppliers');
    await _ensureAuditFields('products');
    await _ensureAuditFields('stock_entries', hasCreatedAt: true);
    await _ensureAuditFields('customer_ledger', hasCreatedAt: true);
    await _ensureAuditFields('supplier_ledger', hasCreatedAt: true);
    await _ensureAuditFields('sales', hasCreatedAt: true);
  }

  /// Kayıtlarda `id` alanı yoksa veya boşsa yeni bir UUID üretir.
  /// Mevcut `id` değerlerini değiştirmez, böylece ilişkiler bozulmaz.
  static Future<void> _ensureIdsInBox(String boxName) async {
    final box = Hive.box(boxName);
    final keys = box.keys.toList(growable: false);

    for (final key in keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(raw);
      final currentId = map['id'];

      if (currentId is String && currentId.isNotEmpty) {
        continue;
      }

      final newId = _uuid.v4();
      map['id'] = newId;
      await box.put(key, map);
    }
  }

  /// Audit ve soft-state alanlarını ekler.
  ///
  /// Idempotent çalışacak şekilde tasarlanmıştır: mevcut alanlara dokunmaz.
  static Future<void> _ensureAuditFields(
    String boxName, {
    bool hasCreatedAt = false,
  }) async {
    final box = Hive.box(boxName);
    final keys = box.keys.toList(growable: false);

    for (final key in keys) {
      final raw = box.get(key);
      if (raw is! Map) continue;

      final map = Map<String, dynamic>.from(raw);

      // createdDate
      if (map['createdDate'] == null) {
        int createdMs;
        if (hasCreatedAt && map['createdAt'] is int) {
          createdMs = map['createdAt'] as int;
        } else {
          createdMs = DateTime.now().millisecondsSinceEpoch;
        }
        map['createdDate'] = createdMs;

        // modifiedDate de yoksa createdDate ile başlat.
        map['modifiedDate'] ??= createdMs;
        map['versionDate'] ??= createdMs;
      }

      // createdBy / modifiedBy
      map['createdBy'] ??= 'migration';
      map['modifiedBy'] ??= map['createdBy'];

      // modifiedDate, versionNo, versionDate
      map['modifiedDate'] ??= map['createdDate'];
      map['versionNo'] ??= 1;
      map['versionDate'] ??= map['modifiedDate'];

      // Soft-state bayrakları
      map['isLocked'] ??= false;
      map['isVisible'] ??= true;
      map['isActived'] ??= true;
      map['isDeleted'] ??= false;

      await box.put(key, map);
    }
  }
}