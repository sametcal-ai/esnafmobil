import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../domain/product.dart';

class ProductRepository {
  static const _uuid = Uuid();

  ProductRepository([FirestoreRefs? refs]) : _refs = refs ?? FirestoreRefs.instance();

  final FirestoreRefs _refs;

  Stream<List<Product>> watchProducts(String companyId) {
    return _refs.productsRef(companyId).snapshots().map((snap) {
      return snap.docs
          .map((d) => d.data())
          .where((p) => !p.meta.isDeleted)
          .toList(growable: false);
    });
  }

  Stream<Product?> watchProductById(
    String companyId,
    String productId,
  ) {
    return _refs
        .productsRef(companyId)
        .doc(productId)
        .snapshots()
        .map((snap) {
      if (!snap.exists) return null;
      final product = snap.data();
      if (product == null) return null;
      return product.meta.isDeleted ? null : product;
    });
  }

  Future<void> upsertProduct(String companyId, Product product) async {
    await _refs
        .productsRef(companyId)
        .doc(product.id)
        .set(product, SetOptions(merge: true));
  }

  Future<void> deleteProduct(
    String companyId,
    String productId, {
    String? currentUserId,
  }) async {
    final actor = currentUserId ?? 'system';
    final now = DateTime.now();

    await _refs.productsRef(companyId).doc(productId).set(
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

  Future<List<Product>> getAllProducts(String companyId) async {
    final snap = await _refs.productsRef(companyId).get();
    return snap.docs
        .map((d) => d.data())
        .where((p) => !p.meta.isDeleted)
        .toList(growable: false);
  }

  Future<Product?> getProductById(
    String companyId,
    String id,
  ) async {
    final snap = await _refs.productsRef(companyId).doc(id).get();
    final product = snap.data();
    if (product == null) return null;
    if (product.meta.isDeleted) return null;
    return product;
  }

  Future<Product?> findProductByBarcode(
    String companyId,
    String barcode,
  ) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    final snap = await _refs
        .productsRef(companyId)
        .where('barcode', isEqualTo: trimmed)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;
    final product = snap.docs.first.data();
    return product.meta.isDeleted ? null : product;
  }

  Future<Product> createProduct({
    required String companyId,
    required String name,
    required String brand,
    required String barcode,
    String? imageUrl,
    required List<String> tags,
    int stockQuantity = 0,
    double lastPurchasePrice = 0,
    double salePrice = 0,
    double marginPercent = 0,
    bool isManualPrice = false,
    double? externalPrice,
    double? externalTax,
    double? externalTaxRate,
    double? externalTotal,
    DateTime? externalDate,
    String? currentUserId,
  }) async {
    final id = _uuid.v4();
    final actor = currentUserId ?? 'system';
    final meta = AuditMeta.create(createdBy: actor);

    final product = Product(
      id: id,
      name: name,
      brand: brand,
      barcode: barcode,
      imageUrl: imageUrl,
      tags: tags,
      stockQuantity: stockQuantity,
      lastPurchasePrice: lastPurchasePrice,
      salePrice: salePrice,
      marginPercent: marginPercent,
      isManualPrice: isManualPrice,
      externalPrice: externalPrice,
      externalTax: externalTax,
      externalTaxRate: externalTaxRate,
      externalTotal: externalTotal,
      externalDate: externalDate,
      meta: meta,
    );

    await upsertProduct(companyId, product);
    return product;
  }

  Future<Product?> updateProduct(
    String companyId,
    Product product, {
    String? currentUserId,
  }) async {
    final existing = await getProductById(companyId, product.id);
    if (existing == null) return null;

    if (existing.meta.isLocked) {
      return null;
    }

    final actor = currentUserId ?? 'system';
    final updatedMeta = existing.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
    );

    final updated = product.copyWith(meta: updatedMeta);
    await upsertProduct(companyId, updated);
    return updated;
  }

  Future<void> increaseStock({
    required String companyId,
    required String productId,
    required int quantity,
    double? purchasePrice,
    double? marginPercent,
    String? currentUserId,
  }) async {
    if (quantity <= 0) return;

    final product = await getProductById(companyId, productId);
    if (product == null) return;

    // Yeni stok miktarı.
    final newQuantity = product.stockQuantity + quantity;

    double newLastPurchasePrice = purchasePrice ?? product.lastPurchasePrice;
    double newSalePrice = product.salePrice;
    double newMarginPercent = product.marginPercent;

    // Otomatik fiyatlandırma: manuel fiyat kullanılmıyorsa
    // ve marj bilgisi geldiyse satış fiyatını güncelle.
    if (!product.isManualPrice && purchasePrice != null) {
      newLastPurchasePrice = purchasePrice;
      if (marginPercent != null && marginPercent > 0) {
        newMarginPercent = marginPercent;
        newSalePrice = newLastPurchasePrice * (1 + newMarginPercent / 100);
      }
    }

    final actor = currentUserId ?? 'system';
    final updatedMeta = product.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
    );

    final updated = product.copyWith(
      stockQuantity: newQuantity,
      lastPurchasePrice: newLastPurchasePrice,
      salePrice: newSalePrice,
      marginPercent: newMarginPercent,
      meta: updatedMeta,
    );

    await upsertProduct(companyId, updated);
  }

  Future<void> decreaseStock({
    required String companyId,
    required String productId,
    required int quantity,
    String? currentUserId,
  }) async {
    if (quantity <= 0) return;

    final product = await getProductById(companyId, productId);
    if (product == null) return;

    final newQuantity = product.stockQuantity - quantity;
    final actor = currentUserId ?? 'system';
    final updatedMeta = product.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
    );

    final updated = product.copyWith(
      stockQuantity: newQuantity < 0 ? 0 : newQuantity,
      meta: updatedMeta,
    );

    await upsertProduct(companyId, updated);
  }
}

final productsRepositoryProvider = Provider<ProductRepository>((ref) {
  final refs = ref.watch(firestoreRefsProvider);
  return ProductRepository(refs);
});