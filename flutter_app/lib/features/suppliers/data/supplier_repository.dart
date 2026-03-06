import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/auditable.dart';
import '../domain/supplier.dart';

class SupplierRepository {
  static const String suppliersBoxName = 'suppliers';
  static const _uuid = Uuid();

  Box get _suppliersBox => Hive.box(suppliersBoxName);

  Future<Supplier?> getSupplierById(String id) async {
    final raw = _suppliersBox.get(id);
    if (raw is! Map) return null;
    if (!isActiveRecordMap(raw)) return null;
    return Supplier.fromMap(raw);
  }

  Future<List<Supplier>> getAllSuppliers() async {
    return _suppliersBox.values
        .whereType<Map>()
        .where(isActiveRecordMap)
        .map((map) => Supplier.fromMap(map))
        .toList(growable: false);
  }

  Future<Supplier> createSupplier({
    required String name,
    String? phone,
    String? address,
    String? note,
  }) async {
    final id = _uuid.v4();
    final meta = AuditMeta.create(createdBy: 'system');
    final supplier = Supplier(
      id: id,
      name: name,
      phone: phone,
      address: address,
      note: note,
      meta: meta,
    );
    await _suppliersBox.put(id, supplier.toMap());
    return supplier;
  }

  Future<Supplier?> updateSupplier(Supplier supplier) async {
    final raw = _suppliersBox.get(supplier.id);
    if (raw is! Map) return null;
    final existing = Supplier.fromMap(raw);

    if (existing.meta.isLocked) {
      return null;
    }

    final updatedMeta = existing.meta.touch(
      modifiedBy: 'system',
      bumpVersion: true,
    );
    final updated = supplier.copyWith(meta: updatedMeta);
    await _suppliersBox.put(supplier.id, updated.toMap());
    return updated;
  }

  Future<void> deleteSupplier(String id) async {
    final raw = _suppliersBox.get(id);
    if (raw is! Map) return;
    final existing = Supplier.fromMap(raw);
    final deletedMeta = existing.meta.softDelete(modifiedBy: 'system');
    final deleted = existing.copyWith(meta: deletedMeta);
    await _suppliersBox.put(id, deleted.toMap());
  }
}