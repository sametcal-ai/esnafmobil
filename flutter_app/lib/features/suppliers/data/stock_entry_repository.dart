import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../auth/domain/current_user_provider.dart';
import '../../products/data/product_repository.dart';
import '../domain/stock_entry.dart';
import 'supplier_repository.dart';
import 'supplier_ledger_repository.dart';

class StockEntryRepository {
  static const _uuid = Uuid();

  StockEntryRepository(
    this._productRepository, {
    required FirestoreRefs refs,
    String? currentUserId,
  })  : _refs = refs,
        _currentUserId = currentUserId;

  final FirestoreRefs _refs;
  final ProductRepository _productRepository;
  final String? _currentUserId;

  String _requireActor([String? overrideUserId]) {
    final actor = (overrideUserId ?? _currentUserId) ?? '';
    if (actor.isEmpty) {
      throw StateError('currentUserId is required for this operation');
    }
    return actor;
  }

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
    final actor = _requireActor(currentUserId);
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = StockEntry(
      id: id,
      supplierId: supplierId,
      supplierName: null,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      createdAt: now,
      type: StockMovementType.incoming,
      saleId: null,
      meta: meta,
    );

    await _refs.stockEntries(companyId).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    

    if (supplierId.isNotEmpty) {
      final supplierRepo = SupplierRepository(_refs, currentUserId: actor);
      final supplier = await supplierRepo.getSupplierById(companyId, supplierId);
      if (supplier != null) {
        final ledgerRepo = SupplierLedgerRepository(_refs, currentUserId: actor);
        final totalAmount = quantity * unitCost;
        await ledgerRepo.addPurchaseEntry(
          companyId: companyId,
          supplier: supplier,
          amount: totalAmount,
          note: 'Stok girişi',
          currentUserId: actor,
        );
      }
    }

    return entry;
  }

  Future<StockEntry> createSaleEntry({
    required String companyId,
    required String productId,
    required int quantity,
    String? saleId,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = _requireActor(currentUserId);
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = StockEntry(
      id: id,
      supplierId: null,
      supplierName: null,
      productId: productId,
      quantity: quantity,
      unitCost: 0,
      createdAt: now,
      type: StockMovementType.outgoing,
      saleId: saleId,
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

  Future<StockEntry> createSystemIncomingEntry({
    required String companyId,
    required String productId,
    required int quantity,
    double unitCost = 0,
    String supplierName = 'system',
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = _requireActor(currentUserId);
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = StockEntry(
      id: id,
      supplierId: null,
      supplierName: supplierName,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      createdAt: now,
      type: StockMovementType.incoming,
      saleId: null,
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

  Future<StockEntry> createSystemOutgoingEntry({
    required String companyId,
    required String productId,
    required int quantity,
    double unitCost = 0,
    String supplierName = 'system',
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final id = _uuid.v4();
    final actor = _requireActor(currentUserId);
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final entry = StockEntry(
      id: id,
      supplierId: null,
      supplierName: supplierName,
      productId: productId,
      quantity: quantity,
      unitCost: unitCost,
      createdAt: now,
      type: StockMovementType.outgoing,
      saleId: null,
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

  Future<int> softDeleteEntriesBySaleId({
    required String companyId,
    required String saleId,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final query = await _refs
        .stockEntries(companyId)
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

final stockEntryRepositoryProvider = Provider<StockEntryRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  final productRepo = ref.watch(productsRepositoryProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return StockEntryRepository(
    productRepo,
    refs: refs,
    currentUserId: currentUserId,
  );
});
