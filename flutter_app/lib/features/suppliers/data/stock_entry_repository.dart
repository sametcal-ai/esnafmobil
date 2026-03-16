import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../../products/data/product_repository.dart';
import '../domain/stock_entry.dart';
import 'supplier_repository.dart';
import 'supplier_ledger_repository.dart';

class StockEntryRepository {
  static const _uuid = Uuid();

  StockEntryRepository(
    this._productRepository, {
    FirestoreRefs? refs,
  }) : _refs = refs ?? FirestoreRefs.instance();

  final FirestoreRefs _refs;
  final ProductRepository _productRepository;

  Stream<List<StockEntry>> watchEntries(String companyId) {
    return _refs
        .stockEntries(companyId)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => d.data())
          .whereType<Map<String, dynamic>>()
          .map(_fromFirestoreMap)
          .where((e) => !e.meta.isDeleted)
          .toList(growable: false);
    });
  }

  Future<List<StockEntry>> getAllEntries(String companyId) async {
    final snap = await _refs.stockEntries(companyId).orderBy('createdAt', descending: true).get();
    return snap.docs
        .map((d) => d.data())
        .whereType<Map<String, dynamic>>()
        .map(_fromFirestoreMap)
        .where((e) => !e.meta.isDeleted)
        .toList(growable: false);
  }

  StockEntry _fromFirestoreMap(Map<String, dynamic> m) {
    final createdAt = m['createdAt'];
    if (createdAt is Timestamp) {
      m['createdAt'] = createdAt.toDate().millisecondsSinceEpoch;
    }
    return StockEntry.fromMap(m);
  }

  Future<StockEntry> createStockEntry({
    required String companyId,
    required String supplierId,
    required String productId,
    required int quantity,
    required double unitCost,
    double? marginPercent,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = StockEntry(
      id: id,
      supplierId: supplierId,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      createdAt: now,
      type: StockMovementType.incoming,
      meta: meta,
    );

    await _refs.stockEntries(companyId).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    await _productRepository.increaseStock(
      companyId: companyId,
      productId: productId,
      quantity: quantity,
      purchasePrice: unitCost,
      marginPercent: marginPercent,
      currentUserId: currentUserId,
    );

    if (supplierId.isNotEmpty) {
      final supplierRepo = SupplierRepository(_refs);
      final supplier = await supplierRepo.getSupplierById(companyId, supplierId);
      if (supplier != null) {
        final ledgerRepo = SupplierLedgerRepository(_refs);
        final totalAmount = quantity * unitCost;
        await ledgerRepo.addPurchaseEntry(
          companyId: companyId,
          supplier: supplier,
          amount: totalAmount,
          note: 'Stok girişi',
          currentUserId: currentUserId,
        );
      }
    }

    return entry;
  }

  Future<StockEntry> createSaleEntry({
    required String companyId,
    required String productId,
    required int quantity,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = StockEntry(
      id: id,
      supplierId: null,
      productId: productId,
      quantity: quantity,
      unitCost: 0,
      createdAt: now,
      type: StockMovementType.outgoing,
      meta: meta,
    );

    await _refs.stockEntries(companyId).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    return entry;
  }
}

final stockEntryRepositoryProvider = Provider<StockEntryRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  final productRepo = ref.watch(productsRepositoryProvider);
  return StockEntryRepository(productRepo, refs: refs);
});
