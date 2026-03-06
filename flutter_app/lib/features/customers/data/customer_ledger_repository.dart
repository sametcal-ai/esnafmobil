import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/auditable.dart';
import '../domain/customer.dart';
import '../domain/customer_ledger.dart';
import 'customer_repository.dart';

class CustomerLedgerRepository {
  static const String ledgerBoxName = 'customer_ledger';
  static const _uuid = Uuid();

  Box get _ledgerBox => Hive.box(ledgerBoxName);

  final CustomerRepository _customerRepository;

  CustomerLedgerRepository(this._customerRepository);

  Future<CustomerLedgerEntry> addSaleEntry({
    required Customer customer,
    required double amount,
    String? note,
    String? saleId,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(
      createdBy: actor,
      now: now,
    );
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
    await _ledgerBox.put(id, entry.toMap());
    return entry;
  }

  Future<CustomerLedgerEntry> addPaymentEntry({
    required Customer customer,
    required double amount,
    String? note,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final meta = AuditMeta.create(
      createdBy: customer.id,
      now: now,
    );
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
    await _ledgerBox.put(id, entry.toMap());
    return entry;
  }

  Future<List<CustomerLedgerEntry>> getEntriesForCustomer(
    String customerId,
  ) async {
    final entries = _ledgerBox.values
        .whereType<Map>()
        .where(isActiveRecordMap)
        .map((map) => CustomerLedgerEntry.fromMap(map))
        .where((entry) => entry.customerId == customerId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return entries;
  }

  Future<List<CustomerLedgerEntry>> getEntriesForCustomerPaged(
    String customerId, {
    required int offset,
    required int limit,
  }) async {
    final all = await getEntriesForCustomer(customerId);
    if (offset >= all.length) {
      return <CustomerLedgerEntry>[];
    }
    final end = (offset + limit).clamp(0, all.length);
    return all.sublist(offset, end);
  }

  Future<List<CustomerLedgerEntry>> getEntriesForCustomerInDateRange(
    String customerId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final all = await getEntriesForCustomer(customerId);
    return all
        .where((e) =>
            !e.createdAt.isBefore(start) && !e.createdAt.isAfter(end))
        .toList();
  }

  Future<double> getBalanceForCustomerBefore(
    String customerId,
    DateTime before,
  ) async {
    final all = await getEntriesForCustomer(customerId);
    double balance = 0;
    for (final entry in all.where((e) => e.createdAt.isBefore(before))) {
      if (entry.type == LedgerEntryType.sale) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }

  Future<double> getBalanceForCustomer(String customerId) async {
    final entries = await getEntriesForCustomer(customerId);
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