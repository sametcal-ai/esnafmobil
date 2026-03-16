import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/customer.dart';

class CustomerRepository {
  static const _uuid = Uuid();

  CustomerRepository([FirestoreRefs? refs]) : _refs = refs ?? FirestoreRefs.instance();

  final FirestoreRefs _refs;

  Stream<List<Customer>> watchCustomers(String companyId) {
    return _refs.customers(companyId).snapshots().map((snap) {
      return snap.docs
          .map((d) => d.data())
          .whereType<Map<String, dynamic>>()
          .map(Customer.fromMap)
          .where((c) => !c.meta.isDeleted)
          .toList(growable: false);
    });
  }

  Stream<Customer?> watchCustomerById(
    String companyId,
    String customerId,
  ) {
    return _refs.customers(companyId).doc(customerId).snapshots().map((snap) {
      final data = snap.data();
      if (!snap.exists || data == null) return null;
      final customer = Customer.fromMap(data);
      return customer.meta.isDeleted ? null : customer;
    });
  }

  Future<List<Customer>> getAllCustomers(String companyId) async {
    final snap = await _refs.customers(companyId).get();
    return snap.docs
        .map((d) => d.data())
        .whereType<Map<String, dynamic>>()
        .map(Customer.fromMap)
        .where((c) => !c.meta.isDeleted)
        .toList(growable: false);
  }

  Future<Customer?> getCustomerById(
    String companyId,
    String id,
  ) async {
    final snap = await _refs.customers(companyId).doc(id).get();
    final data = snap.data();
    if (data == null) return null;
    final customer = Customer.fromMap(data);
    return customer.meta.isDeleted ? null : customer;
  }

  Future<Customer> createCustomer({
    required String companyId,
    String? code,
    required String name,
    String? phone,
    String? email,
    String? workplace,
    String? note,
    String? currentUserId,
  }) async {
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(createdBy: actor);

    final customer = Customer(
      id: id,
      code: code,
      name: name,
      phone: phone,
      email: email,
      workplace: workplace,
      note: note,
      meta: meta,
    );

    await _refs.customers(companyId).doc(id).set(customer.toMap(), SetOptions(merge: true));
    return customer;
  }

  Future<Customer?> updateCustomer(
    String companyId,
    Customer customer, {
    String? currentUserId,
  }) async {
    final existing = await getCustomerById(companyId, customer.id);
    if (existing == null) return null;

    if (existing.meta.isLocked) {
      return null;
    }

    final actor = currentUserId ?? 'system';
    final updatedMeta = existing.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
    );

    final updated = customer.copyWith(meta: updatedMeta);
    await _refs.customers(companyId).doc(updated.id).set(updated.toMap(), SetOptions(merge: true));
    return updated;
  }

  Future<void> deleteCustomer(
    String companyId,
    String id, {
    String? currentUserId,
  }) async {
    final existing = await getCustomerById(companyId, id);
    if (existing == null) return;

    final actor = currentUserId ?? 'system';
    final deletedMeta = existing.meta.softDelete(modifiedBy: actor);
    final deleted = existing.copyWith(meta: deletedMeta);

    await _refs.customers(companyId).doc(id).set(deleted.toMap(), SetOptions(merge: true));
  }
}

final customerRepositoryProvider = Provider<CustomerRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  return CustomerRepository(refs);
});
