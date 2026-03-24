import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../auth/domain/current_user_provider.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';

class CustomerLedgerRepository {
  static const _uuid = Uuid();

  CustomerLedgerRepository(
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

  Future<CustomerLedgerEntry> addSaleEntry({
    required String companyId,
    required Customer customer,
    required double amount,
    String? note,
    String? saleId,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = _requireActor(currentUserId);
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = CustomerLedgerEntry(
      id: id,
      customerId: customer.id,
      type: LedgerEntryType.sale,
      amount: amount,
      note: note,
      createdAt: now,
      saleId: saleId,
      meta: meta,
    );

    await _refs.customerLedger(companyId, customer.id).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    return entry;
  }

  Future<CustomerLedgerEntry> addPaymentEntry({
    required String companyId,
    required Customer customer,
    required double amount,
    String? note,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = _requireActor(currentUserId);
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = CustomerLedgerEntry(
      id: id,
      customerId: customer.id,
      type: LedgerEntryType.payment,
      amount: amount,
      note: note,
      createdAt: now,
      saleId: null,
      meta: meta,
    );

    await _refs.customerLedger(companyId, customer.id).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    return entry;
  }

  Future<List<CustomerLedgerEntry>> getEntriesForCustomer(
    String companyId,
    String customerId,
  ) async {
    final snap = await _refs
        .customerLedger(companyId, customerId)
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
          return CustomerLedgerEntry.fromMap(m);
        })
        .where((e) => !e.meta.isDeleted)
        .toList(growable: false);
  }

  Future<List<CustomerLedgerEntry>> getEntriesForCustomerPaged(
    String companyId,
    String customerId, {
    required int offset,
    required int limit,
  }) async {
    final all = await getEntriesForCustomer(companyId, customerId);
    if (offset >= all.length) {
      return <CustomerLedgerEntry>[];
    }
    final end = (offset + limit).clamp(0, all.length);
    return all.sublist(offset, end);
  }

  Future<double> getBalanceForCustomer(
    String companyId,
    String customerId,
  ) async {
    final entries = await getEntriesForCustomer(companyId, customerId);
    double balance = 0;
    for (final entry in entries) {
      if (entry.type == LedgerEntryType.sale) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }

  Future<double> getBalanceForCustomerBefore(
    String companyId,
    String customerId,
    DateTime before,
  ) async {
    final entries = await getEntriesForCustomer(companyId, customerId);
    double balance = 0;
    for (final entry in entries) {
      if (!entry.createdAt.isBefore(before)) continue;
      if (entry.type == LedgerEntryType.sale) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }

  Future<List<CustomerLedgerEntry>> getEntriesForCustomerInDateRange(
    String companyId,
    String customerId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final entries = await getEntriesForCustomer(companyId, customerId);
    return entries
        .where((e) => !e.createdAt.isBefore(start) && !e.createdAt.isAfter(end))
        .toList(growable: false);
  }

  Future<void> updatePaymentEntry({
    required String companyId,
    required String customerId,
    required CustomerLedgerEntry entry,
    required double amount,
    String? note,
    String? currentUserId,
  }) async {
    if (entry.type != LedgerEntryType.payment) {
      throw StateError('Only payment entries can be updated');
    }

    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final nextMeta = entry.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
      now: now,
    );

    await _refs.customerLedger(companyId, customerId).doc(entry.id).set(
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
    required String customerId,
    required CustomerLedgerEntry entry,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final deleted = entry.meta.softDelete(
      modifiedBy: actor,
      now: now,
    );

    await _refs.customerLedger(companyId, customerId).doc(entry.id).set(
      {
        ...deleted.toMap(),
      },
      SetOptions(merge: true),
    );
  }

  Future<int> softDeleteEntriesBySaleId({
    required String companyId,
    required String customerId,
    required String saleId,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final query = await _refs
        .customerLedger(companyId, customerId)
        .where('saleId', isEqualTo: saleId)
        .get();

    int touched = 0;
    for (final doc in query.docs) {
      final data = doc.data();
      if (data == null) continue;
      final meta = AuditMeta.fromMap(data);
      if (meta.isDeleted) continue;

      final deleted = meta.softDelete(modifiedBy: actor, now: now);
      await doc.reference.set(
        {
          ...data,
          ...deleted.toMap(),
        },
        SetOptions(merge: true),
      );
      touched++;
    }

    return touched;
  }
}

final customerLedgerRepositoryProvider = Provider<CustomerLedgerRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return CustomerLedgerRepository(refs, currentUserId: currentUserId);
});
