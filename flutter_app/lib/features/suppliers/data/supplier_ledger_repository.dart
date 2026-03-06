import 'package:hive_flutter/hive_flutter.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/auditable.dart';
import '../domain/supplier.dart';
import '../domain/supplier_ledger.dart';
import 'supplier_repository.dart';

class SupplierLedgerRepository {
  static const String ledgerBoxName = 'supplier_ledger';
  static const _uuid = Uuid();

  Box get _ledgerBox => Hive.box(ledgerBoxName);

  final SupplierRepository _supplierRepository;

  SupplierLedgerRepository(this._supplierRepository);

  Future<SupplierLedgerEntry> addPurchaseEntry({
    required Supplier supplier,
    required double amount,
    String? note,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final meta = AuditMeta.create(
      createdBy: supplier.id,
      now: now,
    );
    final entry = SupplierLedgerEntry(
      id: id,
      supplierId: supplier.id,
      type: SupplierLedgerEntryType.purchase,
      amount: amount,
      note: note,
      createdAt: now,
      meta: meta,
    );
    await _ledgerBox.put(id, entry.toMap());
    return entry;
  }

  Future<SupplierLedgerEntry> addPaymentEntry({
    required Supplier supplier,
    required double amount,
    String? note,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final meta = AuditMeta.create(
      createdBy: supplier.id,
      now: now,
    );
    final entry = SupplierLedgerEntry(
      id: id,
      supplierId: supplier.id,
      type: SupplierLedgerEntryType.payment,
      amount: amount,
      note: note,
      createdAt: now,
      meta: meta,
    );
    await _ledgerBox.put(id, entry.toMap());
    return entry;
  }

  Future<List<SupplierLedgerEntry>> getEntriesForSupplier(
    String supplierId,
  ) async {
    final entries = _ledgerBox.values
        .whereType<Map>()
        .where(isActiveRecordMap)
        .map((map) => SupplierLedgerEntry.fromMap(map))
        .where((entry) => entry.supplierId == supplierId)
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));

    return entries;
  }

  Future<List<SupplierLedgerEntry>> getEntriesForSupplierInDateRange(
    String supplierId, {
    required DateTime start,
    required DateTime end,
  }) async {
    final all = await getEntriesForSupplier(supplierId);
    return all
        .where(
          (e) => !e.createdAt.isBefore(start) && !e.createdAt.isAfter(end),
        )
        .toList();
  }

  Future<double> getBalanceForSupplierBefore(
    String supplierId,
    DateTime before,
  ) async {
    final all = await getEntriesForSupplier(supplierId);
    double balance = 0;
    for (final entry in all.where((e) => e.createdAt.isBefore(before))) {
      if (entry.type == SupplierLedgerEntryType.purchase) {
        balance += entry.amount;
      } else {
        balance -= entry.amount;
      }
    }
    return balance;
  }

  Future<double> getBalanceForSupplier(String supplierId) async {
    final entries = await getEntriesForSupplier(supplierId);
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
