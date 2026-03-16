import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';

class CustomerLedgerRepository {
  static const _uuid = Uuid();

  CustomerLedgerRepository([FirestoreRefs? refs]) : _refs = refs ?? FirestoreRefs.instance();

  final FirestoreRefs _refs;

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
    final actor = currentUserId ?? 'system';
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
    final actor = currentUserId ?? 'system';
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
}

final customerLedgerRepositoryProvider = Provider<CustomerLedgerRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  return CustomerLedgerRepository(refs);
});
