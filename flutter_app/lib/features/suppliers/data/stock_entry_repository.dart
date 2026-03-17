import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../auth/domain/current_user_provider.dart';
import '../../products/data/product_repository.dart';
import '../../pricing/data/price_list_repository.dart';
import '../domain/stock_entry.dart';
import 'supplier_repository.dart';
import 'supplier_ledger_repository.dart';

class StockEntryRepository {
  static const _uuid = Uuid();

  StockEntryRepository(
    this._productRepository,
    this._priceListRepository, {
    required FirestoreRefs refs,
    String? currentUserId,
  })  : _refs = refs,
        _currentUserId = currentUserId;

  final FirestoreRefs _refs;
  final ProductRepository _productRepository;
  final PriceListRepository _priceListRepository;
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
      meta: meta,
    );

    await _refs.stockEntries(companyId).doc(id).set(
      {
        ...entry.toMap(),
        'createdAt': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );

    // Satış fiyatını ürünün marginPercent alanına göre hesaplayıp
    // aktif fiyat listesinde güncelle.
    final product = await _productRepository.getProductById(companyId, productId);
    if (product != null) {
      final effectiveMargin = (marginPercent != null && marginPercent > 0)
          ? marginPercent
          : product.marginPercent;

      final salePrice = unitCost > 0
          ? unitCost * (1 + (effectiveMargin > 0 ? effectiveMargin : 0) / 100)
          : 0;

      final updatedProduct = product.copyWith(
        lastPurchasePrice: unitCost,
        salePrice: salePrice,
        marginPercent: effectiveMargin,
      );

      await _productRepository.updateProduct(
        companyId,
        updatedProduct,
        currentUserId: actor,
      );

      await _priceListRepository.ensureProductInActiveList(
        companyId: companyId,
        product: updatedProduct,
        currentUserId: actor,
      );

      final active = await _priceListRepository.getActivePriceList(companyId);
      if (active != null) {
        await _priceListRepository.upsertItemForProduct(
          companyId: companyId,
          priceListId: active.id,
          product: updatedProduct,
          purchasePrice: unitCost,
          salePrice: salePrice,
          currentUserId: actor,
        );
      }
    }

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
  final priceListRepo = ref.watch(priceListRepositoryProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  return StockEntryRepository(
    productRepo,
    priceListRepo,
    refs: refs,
    currentUserId: currentUserId,
  );
});
