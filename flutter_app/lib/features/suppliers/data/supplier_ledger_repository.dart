import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';

class SupplierLedgerRepository {
  static const _uuid = Uuid();

  SupplierLedgerRepository([FirestoreRefs? refs]) : _refs = refs ?? FirestoreRefs.instance();

  final FirestoreRefs _refs;

  Future<SupplierLedgerEntry> addPurchaseEntry({
    required String companyId,
    required Supplier supplier,
    required double amount,
    String? note,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = SupplierLedgerEntry(
      id: id,
      supplierId: supplier.id,
      type: SupplierLedgerEntryType.purchase,
      amount: amount,
      note: note,
      createdAt: now,
      meta: meta,
    );

    await _refs.supplierLedger(companyId, supplier.id).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    return entry;
  }

  Future<SupplierLedgerEntry> addPaymentEntry({
    required String companyId,
    required Supplier supplier,
    required double amount,
    String? note,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = SupplierLedgerEntry(
      id: id,
      supplierId: supplier.id,
      type: SupplierLedgerEntryType.payment,
      amount: amount,
      note: note,
      createdAt: now,
      meta: meta,
    );

    await _refs.supplierLedger(companyId, supplier.id).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    return entry;
  }

  Future<List<SupplierLedgerEntry>> getEntriesForSupplier(
    String companyId,
    String supplierId,
  ) async {
    final snap = await _refs
        .supplierLedger(companyId, supplierId)
        .orderBy('createdAt', descending: true)
        .get();

    return snap.docs
        .map((d) => d.data())
        .whereType<Map<String, dynamic>>()
        .map((m) {
          final createdAt = m['createdAt'];
          if (createdAt is Timestamp) {
            m['createdAt'] = createdAt.toDate().millisecondsSinceEpoch;
          }
          return SupplierLedgerEntry.fromMap(m);
        })
        .where((e) => !e.meta.isDeleted)
        .toList(growable: false);
  }

  Future<double> getBalanceForSupplier(
    String companyId,
    String supplierId,
  ) async {
    final entries = await getEntriesForSupplier(companyId, supplierId);
    double balance = 0;
    for (final entry in entries) {
      if (entry.type == SupplierLedgerEntryType.purchase) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }
}

final supplierLedgerRepositoryProvider = Provider<SupplierLedgerRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  return SupplierLedgerRepository(refs);
});
