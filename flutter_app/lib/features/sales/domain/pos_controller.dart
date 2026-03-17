import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
import '../../auth/domain/current_user_provider.dart';
import '../../company/domain/active_company_provider.dart';
import '../../pricing/domain/price_resolver.dart';
import '../../products/data/product_repository.dart';
import '../../products/domain/product.dart' as catalog;
import '../data/sales_repository.dart';
import 'pos_models.dart';

/// Barkod okuma sonucunu temsil eder.
enum ScanResult {
  added,
  incremented,
  notFound,
}

class PosController extends Notifier<PosState> {
  late String companyId;
  late String? currentUserId;
  late ProductRepository _productRepository;
  late SalesRepository _salesRepository;
  late AppSettings _settings;

  @override
  PosState build() {
    _settings = ref.watch(appSettingsProvider);
    companyId = ref.watch(activeCompanyIdProvider) ?? '';
    currentUserId = ref.watch(currentUserIdProvider);
    _productRepository = ref.watch(productsRepositoryProvider);
    _salesRepository = ref.watch(salesRepositoryProvider);

    return PosState.initial();
  }

  double _calculateUnitPrice(catalog.Product product) {
    return PriceResolver.resolveSellPrice(
      product: product,
      settings: _settings,
    );
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
        unitPrice: _calculateUnitPrice(catalogProduct),
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
      unitPrice: _calculateUnitPrice(catalogProduct),
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

    final saleId = await _salesRepository.createSale(
      companyId: companyId,
      customerId: customerId,
      subtotal: subtotal,
      discount: discount,
      vat: vat,
      total: total,
      paymentMethod: paymentMethod,
      items: items,
      currentUserId: currentUserId,
    );

    clearCart();

    return saleId;
  }
}

final posControllerProvider = NotifierProvider<PosController, PosState>(
  PosController.new,
);
