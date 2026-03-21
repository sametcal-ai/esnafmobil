import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../../core/config/app_settings.dart';
import '../../../core/firestore/firestore_refs.dart';
import '../../../core/models/auditable.dart';
import '../../auth/domain/current_user_provider.dart';
import '../../company/domain/active_company_provider.dart';
import '../../company/domain/company_memberships_provider.dart';
import '../../pricing/domain/price_resolver.dart';
import '../../pricing/domain/price_list_providers.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart' as catalog;
import '../../suppliers/domain/stock_entry.dart';
import '../data/sales_repository.dart';
import 'pos_models.dart';

/// Barkod okuma sonucunu temsil eder.
enum ScanResult {
  added,
  incremented,
  notFound,
}

class PosController extends Notifier<PosState> {
  static const _uuid = Uuid();

  late String companyId;
  late String? currentUserId;
  late ProductRepository _productRepository;
  late FirestoreRefs _refs;
  late AppSettings _settings;
  late Map<String, double> _activePriceMap;

  @override
  PosState build() {
    _settings = ref.watch(appSettingsProvider);
    companyId = ref.watch(activeCompanyIdProvider) ?? '';
    currentUserId = ref.watch(currentUserIdProvider);
    _productRepository = ref.watch(productsRepositoryProvider);
    _refs = ref.watch(firestoreRefsProvider);
    _activePriceMap = ref.watch(activePriceListPriceMapProvider);

    return PosState.initial();
  }

  bool hasActivePriceList() {
    return _activePriceMap.isNotEmpty;
  }

  bool isMissingPriceListPrice(catalog.Product product) {
    if (_activePriceMap.isEmpty) return false;

    final priceFromList = _activePriceMap[product.id];
    return priceFromList == null || priceFromList <= 0;
  }

  double resolveUnitPriceFromActiveList(catalog.Product product) {
    final priceFromList = _activePriceMap[product.id];
    if (priceFromList != null && priceFromList > 0) {
      return priceFromList;
    }

    // Aktif fiyat listesi var ama bu üründe fiyat yoksa satışı 0 ile engelle.
    if (_activePriceMap.isNotEmpty) {
      return 0;
    }

    // Henüz aktif liste yoksa (ilk kurulum vb.) eski davranışa düş.
    return PriceResolver.resolveSellPrice(
      product: product,
      settings: _settings,
    );
  }

  double resolveFallbackUnitPrice(catalog.Product product) {
    final p = product.salePrice;
    if (p > 0) return p;
    return 0;
  }

  ScanResult _addCatalogProduct(catalog.Product catalogProduct) {
    // Sepette aynı ürün varsa miktarını artırırken güncel fiyatı da uygula.
    final existingIndex =
        state.items.indexWhere((item) => item.product.id == catalogProduct.id);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedCartProduct = Product(
        id: catalogProduct.id,
        name: catalogProduct.name,
        barcode: catalogProduct.barcode,
        unitPrice: resolveUnitPriceFromActiveList(catalogProduct),
        missingPriceListPrice: isMissingPriceListPrice(catalogProduct),
      );
      final updatedItem = existing.copyWith(
        product: updatedCartProduct,
        quantity: existing.quantity + 1,
      );
      final updatedItems = [...state.items];
      updatedItems[existingIndex] = updatedItem;

      state = state.copyWith(items: updatedItems);
      return ScanResult.incremented;
    }

    // Yeni ürün ekle. POS tarafındaki Product modeline dönüştür.
    final cartProduct = Product(
      id: catalogProduct.id,
      name: catalogProduct.name,
      barcode: catalogProduct.barcode,
      unitPrice: resolveUnitPriceFromActiveList(catalogProduct),
      missingPriceListPrice: isMissingPriceListPrice(catalogProduct),
    );

    final newItem = CartItem(product: cartProduct, quantity: 1);
    state = state.copyWith(items: [...state.items, newItem]);

    return ScanResult.added;
  }

  /// Barkodu işler ve sepete ürün ekler ya da miktarını artırır.
  Future<ScanResult> handleBarcode(String rawBarcode) async {
    if (companyId.isEmpty) {
      return ScanResult.notFound;
    }

    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) {
      return ScanResult.notFound;
    }

    final catalogProduct =
        await _productRepository.findProductByBarcode(companyId, barcode);
    if (catalogProduct == null) {
      return ScanResult.notFound;
    }

    return _addCatalogProduct(catalogProduct);
  }

  /// Ürün seçimi ile sepete ekler ya da miktarını artırır.
  ScanResult addProduct(catalog.Product product) {
    return _addCatalogProduct(product);
  }

  /// UI tarafında kullanıcı onayı ile (ör. fiyat listesinde yoksa)
  /// ürün kartındaki salePrice gibi bir fallback fiyatı ile sepete eklemek için.
  ScanResult addProductWithUnitPrice(
    catalog.Product product, {
    required double unitPrice,
    required bool missingPriceListPrice,
  }) {
    final existingIndex =
        state.items.indexWhere((item) => item.product.id == product.id);

    if (existingIndex >= 0) {
      final existing = state.items[existingIndex];
      final updatedCartProduct = Product(
        id: product.id,
        name: product.name,
        barcode: product.barcode,
        unitPrice: unitPrice,
        missingPriceListPrice: missingPriceListPrice,
      );
      final updatedItem = existing.copyWith(
        product: updatedCartProduct,
        quantity: existing.quantity + 1,
      );
      final updatedItems = [...state.items];
      updatedItems[existingIndex] = updatedItem;

      state = state.copyWith(items: updatedItems);
      return ScanResult.incremented;
    }

    final cartProduct = Product(
      id: product.id,
      name: product.name,
      barcode: product.barcode,
      unitPrice: unitPrice,
      missingPriceListPrice: missingPriceListPrice,
    );

    final newItem = CartItem(product: cartProduct, quantity: 1);
    state = state.copyWith(items: [...state.items, newItem]);

    return ScanResult.added;
  }


  void setPercentageDiscount(double percent) {
    if (percent <= 0) {
      state = state.copyWith(
        discountType: DiscountType.none,
        discountValue: 0,
      );
      return;
    }

    state = state.copyWith(
      discountType: DiscountType.percentage,
      discountValue: percent,
    );
  }

  void clearCart() {
    state = state.copyWith(items: <CartItem>[]);
  }

  void loadCartItems(List<CartItem> items) {
    state = state.copyWith(
      items: items,
      discountType: DiscountType.none,
      discountValue: 0,
    );
  }

  void removeItem(CartItem item) {
    final updated = state.items.where((i) => i != item).toList();
    state = state.copyWith(items: updated);
  }

  void incrementItem(CartItem item) {
    final index = state.items.indexOf(item);
    if (index < 0) return;

    final updatedItem = item.copyWith(quantity: item.quantity + 1);
    final updatedItems = [...state.items];
    updatedItems[index] = updatedItem;
    state = state.copyWith(items: updatedItems);
  }

  void decrementItem(CartItem item) {
    final index = state.items.indexOf(item);
    if (index < 0) return;

    if (item.quantity <= 1) {
      removeItem(item);
      return;
    }

    final updatedItem = item.copyWith(quantity: item.quantity - 1);
    final updatedItems = [...state.items];
    updatedItems[index] = updatedItem;
    state = state.copyWith(items: updatedItems);
  }

  /// Mevcut sepeti beklemeye alır.
  void holdCurrentSale() {
    if (state.items.isEmpty) return;
    state = state.copyWith(
      heldItems: state.items,
      items: <CartItem>[],
    );
  }

  /// Bekleyen satışı geri yükler.
  void resumeHeldSale() {
    if (!state.hasHeldItems) return;
    state = state.copyWith(
      items: state.heldItems ?? <CartItem>[],
      heldItems: null,
    );
  }

  Future<String?> completeSale({
    String? customerId,
    required String paymentMethod,
  }) async {
    if (companyId.isEmpty) return null;
    if (state.items.isEmpty) return null;

    final now = DateTime.now();
    final saleId = now.microsecondsSinceEpoch.toString();

    final actor = currentUserId;
    if (actor == null || actor.isEmpty) return null;
    final saleMeta = AuditMeta.create(createdBy: actor, now: now);

    final subtotal = state.subtotal;
    final discount = state.discountAmount;
    final vat = state.taxAmount;
    final total = state.total;

    final items = state.items
        .map(
          (i) => SaleItem(
            productId: i.product.id,
            productName: i.product.name,
            barcode: i.product.barcode,
            quantity: i.quantity,
            unitPrice: i.product.unitPrice,
            lineTotal: i.lineTotal,
          ),
        )
        .toList(growable: false);

    final sale = Sale(
      id: saleId,
      customerId: customerId,
      createdAt: now,
      subtotal: subtotal,
      discount: discount,
      vat: vat,
      total: total,
      paymentMethod: paymentMethod,
      items: items,
      meta: saleMeta,
    );

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        for (final item in state.items) {
          final productRef = _refs.productsRef(companyId).doc(item.product.id);
          final productSnap = await tx.get(productRef);

          final product = productSnap.data();
          if (product == null || product.meta.isDeleted) {
            throw StateError('Product not found');
          }

          if (product.stockQuantity < item.quantity) {
            throw StateError('Insufficient stock');
          }

          final stockEntryId = _uuid.v4();
          final stockMeta = AuditMeta.create(createdBy: actor, now: now);
          final stockEntry = StockEntry(
            id: stockEntryId,
            supplierId: null,
            supplierName: null,
            productId: item.product.id,
            quantity: item.quantity,
            unitCost: 0,
            createdAt: now,
            type: StockMovementType.outgoing,
            saleId: saleId,
            meta: stockMeta,
          );

          tx.set(
            _refs.stockEntries(companyId).doc(stockEntryId),
            {
              ...stockEntry.toMap(),
              'createdAt': Timestamp.fromDate(now),
            },
            SetOptions(merge: true),
          );
        }

        tx.set(
          _refs.sales(companyId).doc(saleId),
          {
            ...sale.toMap(),
            'stockProcessedAt': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      });
    } catch (_) {
      return null;
    }

    clearCart();
    return saleId;
  }

  Future<bool> updateSale({
    required Sale originalSale,
  }) async {
    if (companyId.isEmpty) return false;

    final actor = currentUserId;
    if (actor == null || actor.isEmpty) return false;

    final now = DateTime.now();

    final subtotal = state.subtotal;
    final discount = state.discountAmount;
    final vat = state.taxAmount;
    final total = state.total;

    final items = state.items
        .map(
          (i) => SaleItem(
            productId: i.product.id,
            productName: i.product.name,
            barcode: i.product.barcode,
            quantity: i.quantity,
            unitPrice: i.product.unitPrice,
            lineTotal: i.lineTotal,
          ),
        )
        .toList(growable: false);

    final touchedMeta = originalSale.meta.touch(
      modifiedBy: actor,
      bumpVersion: true,
      now: now,
    );

    final updatedSale = Sale(
      id: originalSale.id,
      customerId: originalSale.customerId,
      createdAt: originalSale.createdAt,
      subtotal: subtotal,
      discount: discount,
      vat: vat,
      total: total,
      paymentMethod: originalSale.paymentMethod,
      items: items,
      meta: touchedMeta,
    );

    final newQty = <String, int>{
      for (final i in state.items) i.product.id: i.quantity,
    };

    final stockEntriesSnap = await _refs
        .stockEntries(companyId)
        .where('saleId', isEqualTo: originalSale.id)
        .get();

    final entriesByProduct = <String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>{};
    for (final d in stockEntriesSnap.docs) {
      final data = d.data();
      if (data == null) continue;
      final meta = AuditMeta.fromMap(data);
      if (meta.isDeleted) continue;

      final productId = data['productId'] as String?;
      if (productId == null || productId.isEmpty) continue;

      entriesByProduct.putIfAbsent(productId, () => []).add(d);
    }

    final productIds = <String>{
      ...entriesByProduct.keys,
      ...newQty.keys,
    }.toList(growable: false);

    try {
      await FirebaseFirestore.instance.runTransaction((tx) async {
        for (final productId in productIds) {
          final desiredQty = newQty[productId] ?? 0;

          // Mevcut (silinmemiş) stok hareketlerinden bu satışın net etkisini hesapla.
          // outgoing => satış (stok düşer), incoming => iade/düzeltme (stok artar)
          final existingDocs = entriesByProduct[productId] ?? const <QueryDocumentSnapshot<Map<String, dynamic>>>[];

          int currentNetOutgoing = 0;
          for (final d in existingDocs) {
            final data = d.data();
            final typeName = (data['type'] as String?) ?? 'incoming';
            final qty = (data['quantity'] as num?)?.toInt() ?? 0;
            if (qty <= 0) continue;

            if (typeName == StockMovementType.outgoing.name) {
              currentNetOutgoing += qty;
            } else {
              currentNetOutgoing -= qty;
            }
          }
          if (currentNetOutgoing < 0) currentNetOutgoing = 0;

          final additionalNeeded = desiredQty - currentNetOutgoing;
          if (additionalNeeded > 0) {
            final productRef = _refs.productsRef(companyId).doc(productId);
            final productSnap = await tx.get(productRef);
            final product = productSnap.data();
            if (product == null || product.meta.isDeleted) {
              throw StateError('Product not found');
            }
            if (product.stockQuantity < additionalNeeded) {
              throw StateError('Insufficient stock');
            }
          }

          // Tek bir aktif sale-stockEntry bırak: varsa birini update et, diğerlerini soft delete.
          QueryDocumentSnapshot<Map<String, dynamic>>? primary;
          for (final d in existingDocs) {
            final data = d.data();
            final typeName = (data['type'] as String?) ?? '';
            if (primary == null && typeName == StockMovementType.outgoing.name) {
              primary = d;
            }
          }
          primary ??= existingDocs.isNotEmpty ? existingDocs.first : null;

          if (desiredQty <= 0) {
            for (final d in existingDocs) {
              final data = d.data();
              final meta = AuditMeta.fromMap(data).softDelete(
                modifiedBy: actor,
                now: now,
              );
              tx.set(
                d.reference,
                {
                  ...data,
                  ...meta.toMap(),
                },
                SetOptions(merge: true),
              );
            }
            continue;
          }

          if (primary == null) {
            final stockEntryId = _uuid.v4();
            final stockMeta = AuditMeta.create(createdBy: actor, now: now);
            final stockEntry = StockEntry(
              id: stockEntryId,
              supplierId: null,
              supplierName: null,
              productId: productId,
              quantity: desiredQty,
              unitCost: 0,
              createdAt: now,
              type: StockMovementType.outgoing,
              saleId: originalSale.id,
              meta: stockMeta,
            );

            tx.set(
              _refs.stockEntries(companyId).doc(stockEntryId),
              {
                ...stockEntry.toMap(),
                'createdAt': Timestamp.fromDate(now),
              },
              SetOptions(merge: true),
            );
            continue;
          }

          final primaryData = primary.data();
          final touchedStockMeta = AuditMeta.fromMap(primaryData).touch(
            modifiedBy: actor,
            bumpVersion: true,
            now: now,
          );

          tx.set(
            primary.reference,
            {
              ...primaryData,
              'productId': productId,
              'quantity': desiredQty,
              'unitCost': 0,
              'type': StockMovementType.outgoing.name,
              'saleId': originalSale.id,
              ...touchedStockMeta.toMap(),
            },
            SetOptions(merge: true),
          );

          for (final d in existingDocs) {
            if (d.id == primary.id) continue;
            final data = d.data();
            final meta = AuditMeta.fromMap(data).softDelete(
              modifiedBy: actor,
              now: now,
            );
            tx.set(
              d.reference,
              {
                ...data,
                ...meta.toMap(),
              },
              SetOptions(merge: true),
            );
          }
        }

        tx.set(
          _refs.sales(companyId).doc(originalSale.id),
          {
            ...updatedSale.toMap(),
            'createdAt': Timestamp.fromDate(originalSale.createdAt),
            'stockProcessedAt': Timestamp.fromDate(now),
          },
          SetOptions(merge: true),
        );
      });
    } catch (_) {
      return false;
    }

    clearCart();
    return true;
  }
}

final posControllerProvider = NotifierProvider<PosController, PosState>(
  PosController.new,
);