import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/supplier.dart';

class SupplierRepository {
  static const _uuid = Uuid();

  SupplierRepository([FirestoreRefs? refs]) : _refs = refs ?? FirestoreRefs.instance();

  final FirestoreRefs _refs;

  Stream<List<Supplier>> watchSuppliers(String companyId) {
    return _refs.suppliers(companyId).snapshots().map((snap) {
      return snap.docs
          .map((d) => d.data())
          .whereType<Map<String, dynamic>>()
          .map(Supplier.fromMap)
          .where((s) => !s.meta.isDeleted)
          .toList(growable: false);
    });
  }

  Future<Supplier?> getSupplierById(
    String companyId,
    String id,
  ) async {
    final snap = await _refs.suppliers(companyId).doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    final supplier = Supplier.fromMap(data);
    return supplier.meta.isDeleted ? null : supplier;
  }

  Future<List<Supplier>> getAllSuppliers(String companyId) async {
    final snap = await _refs.suppliers(companyId).get();
    return snap.docs
        .map((d) => d.data())
        .whereType<Map<String, dynamic>>()
        .map(Supplier.fromMap)
        .where((s) => !s.meta.isDeleted)
        .toList(growable: false);
  }

  Future<Supplier> createSupplier({
    required String companyId,
    required String name,
    String? phone,
    String? address,
    String? note,
    String? currentUserId,
  }) async {
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(createdBy: actor);

    final supplier = Supplier(
      id: id,
      name: name,
      phone: phone,
      address: address,
      note: note,
      meta: meta,
    );

    await _refs.suppliers(companyId).doc(id).set(supplier.toMap(), SetOptions(merge: true));
    return supplier;
  }

  Future<Supplier?> updateSupplier(
    String companyId,
    Supplier supplier, {
    String? currentUserId,
  }) async {
    final existing = await getSupplierById(companyId, supplier.id);
    if (existing == null) return null;

    if (existing.meta.isLocked) {
      return null;
    }

    final actor = currentUserId ?? 'system';
    final updatedMeta = existing.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
    );

    final updated = supplier.copyWith(meta: updatedMeta);
    await _refs.suppliers(companyId).doc(updated.id).set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  Future<void> deleteSupplier(
    String companyId,
    String id, {
    String? currentUserId,
  }) async {
    final existing = await getSupplierById(companyId, id);
    if (existing == null) return;

    final actor = currentUserId ?? 'system';
    final deletedMeta = existing.meta.softDelete(modifiedBy: actor);
    final deleted = existing.copyWith(meta: deletedMeta);

    await _refs.suppliers(companyId).doc(id).set(deleted.toMap(), SetOptions(merge: true));
  }
}

final supplierRepositoryProvider = Provider<SupplierRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  return SupplierRepository(refs);
});
