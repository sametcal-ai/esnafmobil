import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../auth/domain/current_user_provider.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';

class SupplierLedgerRepository {
  static const _uuid = Uuid();

  SupplierLedgerRepository(
    this._refs, {
    String? currentUserId,
  }) : _currentUserId = currentUserId;

  final FirestoreRefs _refs;
  final String? _currentUserId;

  String _requireActor([String? overrideUserId]) {
    final actor = (overrideUserId ?? _currentUserId) ?? '';
    if (actor.isEmpty) {
      throw StateError('currentUserId is required for this operation');
    }
    return actor;
  }

  Future<SupplierLedgerEntry> addPurchaseEntry({
    required String companyId,
    required Supplier supplier,
    required double amount,
    String? note,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = _requireActor(currentUserId);
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
    final actor = _requireActor(currentUserId);
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

  Future<double> getBalanceForSupplierBefore(
    String companyId,
    String supplierId,
    DateTime before,
  ) async {
    final entries = await getEntriesForSupplier(companyId, supplierId);
    double balance = 0;
    for (final entry in entries) {
      if (!entry.createdAt.isBefore(before)) continue;
      if (entry.type == SupplierLedgerEntryType.purchase) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }

  Future<List<SupplierLedgerEntry>> getEntriesForSupplierInDateRange(
    String companyId,
    String supplierId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await getEntriesForSupplier(companyId, supplierId);
    return entries
        .where((e) => !e.createdAt.isBefore(start) && !e.createdAt.isAfter(end))
        .toList(growable: false);
  }

  Future<void> updatePaymentEntry({
    required String companyId,
    required String supplierId,
    required SupplierLedgerEntry entry,
    required double amount,
    String? note,
    String? currentUserId,
  }) async {
    if (entry.type != SupplierLedgerEntryType.payment) {
      throw StateError('Only payment entries can be updated');
    }

    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final nextMeta = entry.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
      now: now,
    );

    await _refs.supplierLedger(companyId, supplierId).doc(entry.id).set(
      {
        'amount': amount,
        'note': note,
        ...nextMeta.toMap(),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> softDeleteEntry({
    required String companyId,
    required String supplierId,
    required SupplierLedgerEntry entry,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final deleted = entry.meta.softDelete(
      modifiedBy: actor,
      now: now,
    );

    await _refs.supplierLedger(companyId, supplierId).doc(entry.id).set(
      {
        ...deleted.toMap(),
      },
      SetOptions(merge: true),
    );
  }
}

final supplierLedgerRepositoryProvider = Provider<SupplierLedgerRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return SupplierLedgerRepository(refs, currentUserId: currentUserId);
});
