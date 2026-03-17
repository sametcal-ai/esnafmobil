import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../auth/domain/current_user_provider.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart';
import '../domain/price_list.dart';
import '../domain/price_list_item.dart';

class PriceListRepository {
  static const _uuid = Uuid();

  PriceListRepository(
    this._refs,
    this._productRepo, {
    String? currentUserId,
  }) : _currentUserId = currentUserId;

  final FirestoreRefs _refs;
  final ProductRepository _productRepo;
  final String? _currentUserId;

  String _requireActor([String? overrideUserId]) {
    final actor = (overrideUserId ?? _currentUserId) ?? '';
    if (actor.isEmpty) {
      throw StateError('currentUserId is required for this operation');
    }
    return actor;
  }

  Stream<List<PriceList>> watchPriceLists(String companyId) {
    return _refs
        .priceListsRef(companyId)
        .orderBy('startDate', descending: true)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => d.data())
          .where((pl) => !pl.meta.isDeleted)
          .toList(growable: false);
    });
  }

  Stream<PriceList?> watchActivePriceList(String companyId) {
    return _refs
        .priceListsRef(companyId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .snapshots()
        .map((snap) {
      if (snap.docs.isEmpty) return null;
      final pl = snap.docs.first.data();
      return pl.meta.isDeleted ? null : pl;
    });
  }

  Future<PriceList?> getActivePriceList(String companyId) async {
    final snap = await _refs
        .priceListsRef(companyId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final pl = snap.docs.first.data();
    return pl.meta.isDeleted ? null : pl;
  }

  Stream<List<PriceListItem>> watchItems(
    String companyId,
    String priceListId,
  ) {
    return _refs
        .priceListItemsRef(companyId, priceListId)
        .snapshots()
        .map((snap) {
      return snap.docs
          .map((d) => d.data())
          .where((i) => !i.meta.isDeleted)
          .toList(growable: false);
    });
  }

  Future<PriceList> createPriceList({
    required String companyId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required PriceListType type,
    bool makeActive = false,
    String? currentUserId,
  }) async {
    final now = DateTime.now();
    final actor = _requireActor(currentUserId);
    final id = _uuid.v4();
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final pl = PriceList(
      id: id,
      name: name,
      startDate: startDate,
      endDate: endDate,
      type: type,
      isActive: false,
      inactiveReason: null,
      meta: meta,
    );

    await _refs
        .priceListsRef(companyId)
        .doc(id)
        .set(pl, SetOptions(merge: true));

    if (makeActive) {
      await setActivePriceList(
        companyId: companyId,
        priceListId: id,
        previousExpired: false,
        currentUserId: actor,
      );
    }

    return pl.copyWith(isActive: makeActive);
  }

  Future<void> setActivePriceList({
    required String companyId,
    required String priceListId,
    required bool previousExpired,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final prevActiveSnap = await _refs
        .priceListsRef(companyId)
        .where('isActive', isEqualTo: true)
        .limit(1)
        .get();

    final String? prevId =
        prevActiveSnap.docs.isEmpty ? null : prevActiveSnap.docs.first.id;

    // Transaction.set, typed DocumentReference (withConverter) ile çalışırken
    // T tipini PriceList bekler. Burada Map yazdığımız için raw ref kullanıyoruz.
    final rawCol = FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('priceLists');

    final prevRef = prevId == null ? null : rawCol.doc(prevId);
    final nextRef = rawCol.doc(priceListId);

    final db = FirebaseFirestore.instance;
    await db.runTransaction((tx) async {
      final nextSnap = await tx.get(nextRef);
      if (!nextSnap.exists) {
        throw StateError('PriceList not found');
      }

      if (prevRef != null && prevRef.id != priceListId) {
        tx.set(
          prevRef,
          {
            'isActive': false,
            'inactiveReason': previousExpired ? 'Süresi doldu' : 'Pasif',
            'modifiedBy': actor,
            'modifiedDate': Timestamp.fromDate(now),
            'versionNo': FieldValue.increment(1),
            'versionDate': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      }

      tx.set(
        nextRef,
        {
          'isActive': true,
          'inactiveReason': null,
          'modifiedBy': actor,
          'modifiedDate': Timestamp.fromDate(now),
          'versionNo': FieldValue.increment(1),
          'versionDate': Timestamp.fromDate(now),
        },
        SetOptions(merge: true),
      );
    });

    // Aktivasyon sonrası: yeni listede eksik ürün varsa eski listeden kopyala.
    final active = await getActivePriceList(companyId);
    if (active == null || active.id != priceListId) return;

    final prev =
        await _findMostRecentOtherList(companyId, excludeId: priceListId);
    if (prev == null) return;

    await _fillMissingItemsFromPrevious(
      companyId: companyId,
      targetPriceListId: priceListId,
      sourcePriceListId: prev.id,
      currentUserId: actor,
    );
  }

  Future<void> updatePriceList({
    required String companyId,
    required String priceListId,
    required String name,
    required DateTime startDate,
    required DateTime endDate,
    required PriceListType type,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    // _refs.priceListsRef uses withConverter<PriceList>, so .set expects a PriceList.
    // For partial updates we use the raw reference.
    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('priceLists')
        .doc(priceListId)
        .set(
      <String, dynamic>{
        'name': name,
        'startDate': Timestamp.fromDate(startDate),
        'endDate': Timestamp.fromDate(endDate),
        'type': type.name,
        'modifiedBy': actor,
        'modifiedDate': Timestamp.fromDate(now),
        'versionNo': FieldValue.increment(1),
        'versionDate': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> syncMissingItemsFromProductsWithMargin({
    required String companyId,
    required String priceListId,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);

    final products = await _productRepo.getAllProducts(companyId);
    final existingSnap = await _refs.priceListItemsRef(companyId, priceListId).get();

    // Soft delete edilen (isDeleted=true) ürünler "listede var" sayılmamalı.
    // Aksi halde aynı productId'ye sahip doküman var diye yeniden oluşturma atlanıyor.
    final existingIds = existingSnap.docs
        .map((d) => d.data())
        .where((i) => !i.meta.isDeleted)
        .map((i) => i.productId)
        .toSet();

    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    for (final p in products) {
      if (existingIds.contains(p.id)) continue;

      final computedSale = p.lastPurchasePrice * (1 + (p.marginPercent / 100));

      final item = PriceListItem(
        id: p.id,
        productId: p.id,
        purchasePrice: p.lastPurchasePrice,
        salePrice: computedSale,
        isInherited: false,
        inheritedFromPriceListId: null,
        meta: AuditMeta.create(createdBy: actor, now: now),
      );

      batch.set(
        _refs.priceListItemsRef(companyId, priceListId).doc(p.id),
        item,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<PriceList?> ensureActiveForNow(String companyId) async {
    final now = DateTime.now();
    final active = await getActivePriceList(companyId);

    if (active != null && active.isValidAt(now)) {
      return active;
    }

    // Aktif yoksa veya süresi dolduysa uygun listeyi bul.
    final listsSnap = await _refs.priceListsRef(companyId).get();
    final lists = listsSnap.docs
        .map((d) => d.data())
        .where((pl) => !pl.meta.isDeleted)
        .toList(growable: false);

    final candidate = lists
        .where((pl) => pl.isValidAt(now))
        .toList(growable: false)
      ..sort((a, b) => b.startDate.compareTo(a.startDate));

    if (candidate.isEmpty) {
      return active;
    }

    final next = candidate.first;

    await setActivePriceList(
      companyId: companyId,
      priceListId: next.id,
      previousExpired: active != null,
      currentUserId: _requireActor(),
    );

    return next;
  }

  Future<void> upsertItemForProduct({
    required String companyId,
    required String priceListId,
    required Product product,
    required double purchasePrice,
    required double salePrice,
    bool isInherited = false,
    String? inheritedFromPriceListId,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    final itemId = product.id;
    final meta = AuditMeta.create(createdBy: actor, now: now);

    final item = PriceListItem(
      id: itemId,
      productId: product.id,
      purchasePrice: purchasePrice,
      salePrice: salePrice,
      isInherited: isInherited,
      inheritedFromPriceListId: inheritedFromPriceListId,
      meta: meta,
    );

    await _refs
        .priceListItemsRef(companyId, priceListId)
        .doc(itemId)
        .set(item, SetOptions(merge: true));
  }

  Future<void> deleteItemForProduct({
    required String companyId,
    required String priceListId,
    required String productId,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);
    final now = DateTime.now();

    await FirebaseFirestore.instance
        .collection('companies')
        .doc(companyId)
        .collection('priceLists')
        .doc(priceListId)
        .collection('items')
        .doc(productId)
        .set(
      {
        'isDeleted': true,
        'isVisible': false,
        'isActived': false,
        'modifiedBy': actor,
        'modifiedDate': Timestamp.fromDate(now),
        'versionNo': FieldValue.increment(1),
        'versionDate': Timestamp.fromDate(now),
      },
      SetOptions(merge: true),
    );
  }

  Future<void> ensureProductInActiveList({
    required String companyId,
    required Product product,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);

    final active = await ensureActiveForNow(companyId);
    if (active == null) return;

    final purchase = product.lastPurchasePrice;
    final sale = product.salePrice;

    await upsertItemForProduct(
      companyId: companyId,
      priceListId: active.id,
      product: product,
      purchasePrice: purchase,
      salePrice: sale,
      currentUserId: actor,
    );
  }

  Future<void> syncMissingItemsFromProducts({
    required String companyId,
    required String priceListId,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);

    final products = await _productRepo.getAllProducts(companyId);
    final existingSnap = await _refs.priceListItemsRef(companyId, priceListId).get();

    // Soft delete edilen ürünleri "var" kabul etmiyoruz.
    final existingIds = existingSnap.docs
        .map((d) => d.data())
        .where((i) => !i.meta.isDeleted
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    for (final p in products) {
      if (existingIds.contains(p.id)) continue;

      final item = PriceListItem(
        id: p.id,
        productId: p.id,
        purchasePrice: p.lastPurchasePrice,
        salePrice: p.salePrice,
        isInherited: false,
        inheritedFromPriceListId: null,
        meta: AuditMeta.create(createdBy: actor, now: now),
      );

      batch.set(
        _refs.priceListItemsRef(companyId, priceListId).doc(p.id),
        item,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<void> cloneFromOtherListWithIncrease({
    required String companyId,
    required String sourcePriceListId,
    required String targetPriceListId,
    required double increaseValue,
    required bool isPercent,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);

    final sourceSnap = await _refs.priceListItemsRef(companyId, sourcePriceListId).get();
    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    for (final doc in sourceSnap.docs) {
      final item = doc.data();
      if (item.meta.isDeleted) continue;

      final base = item.salePrice;
      final updatedSale = isPercent ? base * (1 + increaseValue / 100) : base + increaseValue;

      final next = item.copyWith(
        id: item.productId,
        salePrice: updatedSale,
        isInherited: true,
        inheritedFromPriceListId: sourcePriceListId,
        meta: AuditMeta.create(createdBy: actor, now: now),
      );

      batch.set(
        _refs.priceListItemsRef(companyId, targetPriceListId).doc(next.id),
        next,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }

  Future<PriceList?> _findMostRecentOtherList(
    String companyId, {
    required String excludeId,
  }) async {
    final snap = await _refs.priceListsRef(companyId).orderBy('startDate', descending: true).get();
    for (final doc in snap.docs) {
      final pl = doc.data();
      if (pl.meta.isDeleted) continue;
      if (pl.id == excludeId) continue;
      return pl;
    }
    return null;
  }

  Future<void> _fillMissingItemsFromPrevious({
    required String companyId,
    required String targetPriceListId,
    required String sourcePriceListId,
    String? currentUserId,
  }) async {
    final actor = _requireActor(currentUserId);

    final targetSnap = await _refs.priceListItemsRef(companyId, targetPriceListId).get();
    final existingIds = targetSnap.docs
        .map((d) => d.data())
        .where((i) => !i.meta.isDeleted)
        .map((i) => i.productId)
        .toSet();

    final sourceSnap = await _refs.priceListItemsRef(companyId, sourcePriceListId).get();

    final batch = FirebaseFirestore.instance.batch();
    final now = DateTime.now();

    for (final doc in sourceSnap.docs) {
      final item = doc.data();
      if (item.meta.isDeleted) continue;
      if (existingIds.contains(item.productId)) continue;

      final inherited = item.copyWith(
        id: item.productId,
        isInherited: true,
        inheritedFromPriceListId: sourcePriceListId,
        meta: AuditMeta.create(createdBy: actor, now: now),
      );

      batch.set(
        _refs.priceListItemsRef(companyId, targetPriceListId).doc(inherited.id),
        inherited,
        SetOptions(merge: true),
      );
    }

    await batch.commit();
  }
}

final priceListRepositoryProvider = Provider<PriceListRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  final currentUserId = ref.watch(currentUserIdProvider);
  final productRepo = ref.watch(productsRepositoryProvider);
  return PriceListRepository(
    refs,
    productRepo,
    currentUserId: currentUserId,
  );
});
