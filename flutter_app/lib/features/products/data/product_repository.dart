import 'package:hive_flutter/hive_flutter.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/models/auditable.dart';
import '../domain/product.dart';

class ProductRepository {
  static const String productsBoxName = 'products';
  static const _uuid = Uuid();

  Box get _productsBox => Hive.box(productsBoxName);

  Future<List<Product>> getAllProducts() async {
    return _productsBox.values
        .whereType<Map>()
        .where(isActiveRecordMap)
        .map((map) => Product.fromMap(map))
        .toList(growable: false);
  }

  Future<Product> createProduct({
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

    await _productsBox.put(id, product.toMap());
    return product;
  }

  Future<Product?> getProductById(String id) async {
    final raw = _productsBox.get(id);
    if (raw is! Map) return null;
    if (!isActiveRecordMap(raw)) return null;
    return Product.fromMap(raw);
  }

  /// Barkoda göre ürün bulur.
  /// Hive koleksiyonu bellek içinde olduğundan, bu arama senkron çalışabilir.
  Product? getProductByBarcode(String barcode) {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    for (final dynamic raw in _productsBox.values) {
      if (raw is! Map) continue;
      if (!isActiveRecordMap(raw)) continue;
      final product = Product.fromMap(raw);
      if (product.barcode.trim() == trimmed) {
        return product;
      }
    }
    return null;
  }

  Future<Product?> updateProduct(
    Product product, {
    String? currentUserId,
  }) async {
    final raw = _productsBox.get(product.id);
    if (raw is! Map) return null;
    final existing = Product.fromMap(raw);

    if (existing.meta.isLocked) {
      return null;
    }

    final actor = currentUserId ?? 'system';
    final updatedMeta = existing.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
    );

    final updated = product.copyWith(meta: updatedMeta);
    await _productsBox.put(product.id, updated.toMap());
    return updated;
  }

  /// Ürünü soft delete ile siler.
  Future<void> deleteProduct(
    String id, {
    String? currentUserId,
  }) async {
    final raw = _productsBox.get(id);
    if (raw is! Map) return;
    final existing = Product.fromMap(raw);
    final actor = currentUserId ?? 'system';
    final deletedMeta = existing.meta.softDelete(modifiedBy: actor);
    final deleted = existing.copyWith(meta: deletedMeta);
    await _productsBox.put(id, deleted.toMap());
  }

  Future<void> increaseStock({
    required String productId,
    required int quantity,
    double? purchasePrice,
    double? marginPercent,
    String? currentUserId,
  }) async {
    if (quantity <= 0) return;

    final product = await getProductById(productId);
    if (product == null) return;

    // Yeni stok miktarı.
    final newQuantity = product.stockQuantity + quantity;

    double newLastPurchasePrice =
        purchasePrice ?? product.lastPurchasePrice;
    double newSalePrice = product.salePrice;
    double newMarginPercent = product.marginPercent;

    // Otomatik fiyatlandırma: manuel fiyat kullanılmıyorsa
    // ve marj bilgisi geldiyse satış fiyatını güncelle.
    if (!product.isManualPrice && purchasePrice != null) {
      newLastPurchasePrice = purchasePrice;
      if (marginPercent != null && marginPercent > 0) {
        newMarginPercent = marginPercent;
        newSalePrice =
            newLastPurchasePrice * (1 + newMarginPercent / 100);
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

    await updateProduct(updated, currentUserId: currentUserId);
  }

  Future<void> decreaseStock({
    required String productId,
    required int quantity,
    String? currentUserId,
  }) async {
    if (quantity <= 0) return;

    final product = await getProductById(productId);
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

    await updateProduct(updated, currentUserId: currentUserId);
  }
}

final productsRepositoryProvider =
    Provider<ProductRepository>((ref) => ProductRepository());