import '../../../core/config/app_settings.dart';
import '../../products/domain/product.dart';

/// Ürünlerin satış fiyatını hesaplamak için tek merkez.
/// - Manuel fiyat varsa onu kullanır.
/// - Aksi halde sistem varsayılan kâr marjını kullanarak
///   son alış fiyatından satış fiyatını üretir.
class PriceResolver {
  const PriceResolver._();

  /// [product] için satış fiyatını hesaplar.
  ///
  /// İş kuralları:
  /// - product.isManualPrice == true ve product.salePrice > 0 ise
  ///   manuel fiyat döner.
  /// - Aksi halde:
  ///   salePrice = lastPurchasePrice * (1 + defaultMarginPercent / 100)
  /// - lastPurchasePrice <= 0 ise 0 döner.
  static double resolveSellPrice({
    required Product product,
    required AppSettings settings,
  }) {
    // Manuel fiyat her zaman öncelikli.
    if (product.isManualPrice && product.salePrice > 0) {
      return product.salePrice;
    }

    final lastPurchase = product.lastPurchasePrice;
    if (lastPurchase <= 0) {
      return 0;
    }

    final margin = settings.defaultMarginPercent;
    if (margin <= 0) {
      // Marj yoksa alış fiyatını aynen döndür.
      return lastPurchase;
    }

    return lastPurchase * (1 + margin / 100);
  }
}