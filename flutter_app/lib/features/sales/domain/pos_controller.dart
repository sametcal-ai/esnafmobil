import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/config/app_settings.dart';
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

class PosController extends StateNotifier<PosState> {
  final ProductRepository _productRepository;
  final SalesRepository _salesRepository;
  final AppSettings _settings;

  PosController({
    required AppSettings settings,
    ProductRepository? productRepository,
    SalesRepository? salesRepository,
  })  : _productRepository = productRepository ?? ProductRepository(),
        _salesRepository = salesRepository ?? SalesRepository(),
        _settings = settings,
        super(PosState.initial());

  /// Şimdilik satışları "system" kullanıcısı ile ilişkilendiriyoruz.
  /// İleride auth state'i enjekte edilerek gerçek kullanıcı ID'si eklenebilir.
  String? get _currentUserId => null;

  double _calculateUnitPrice(catalog.Product product) {
    return PriceResolver.resolveSellPrice(
      product: product,
      settings: _settings,
    );
  }

  /// Barkodu işler ve sepete ürün ekler ya da miktarını artırır.
  ScanResult handleBarcode(String rawBarcode) {
    final barcode = rawBarcode.trim();
    if (barcode.isEmpty) {
      return ScanResult.notFound;
    }

    final catalogProduct = _productRepository.getProductByBarcode(barcode);
    if (catalogProduct == null) {
      return ScanResult.notFound;
    }

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

    final updatedItem =
        item.copyWith(quantity: item.quantity + 1);
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

    final updatedItem =
        item.copyWith(quantity: item.quantity - 1);
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

  /// Satışı tamamlar. Stok kontrolü başarısız olursa `null` döner.
  Future<String?> completeSale({
    String? customerId,
    required String paymentMethod,
  }) async {
    if (state.items.isEmpty) return null;

    // Stok kontrolü – herhangi bir üründe yetersiz stok varsa iptal.
    for (final item in state.items) {
      final catalogProduct =
          await _productRepository.getProductById(item.product.id);
      if (catalogProduct == null) {
        return null;
      }
      if (catalogProduct.stockQuantity < item.quantity) {
        return null;
      }
    }

    // Stokları düş.
    for (final item in state.items) {
      await _productRepository.decreaseStock(
        productId: item.product.id,
        quantity: item.quantity,
      );
    }

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
      customerId: customerId,
      subtotal: subtotal,
      discount: discount,
      vat: vat,
      total: total,
      paymentMethod: paymentMethod,
      items: items,
      currentUserId: _currentUserId,
    );

    // Satış tamamlandıktan sonra sepeti temizle.
    clearCart();

    return saleId;
  }
}

final posControllerProvider =
    StateNotifierProvider<PosController, PosState>((ref) {
  final settings = ref.watch(appSettingsProvider);
  return PosController(settings: settings);
});