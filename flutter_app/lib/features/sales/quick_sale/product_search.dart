import '../../products/domain/product.dart';

List<Product> filterProductsForQuickSale(
  List<Product> products,
  String rawQuery, {
  int limit = 8,
}) {
  final query = rawQuery.trim().toLowerCase();
  if (query.isEmpty) return const <Product>[];

  final tokens = query.contains(',')
      ? query
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList(growable: false)
      : <String>[query];

  String normalizeForSearch(String value) {
    return value
        .toLowerCase()
        // "İ" -> "i\u0307" (i + combining dot). Remove the combining dot.
        .replaceAll('\u0307', '')
        // Treat Turkish dotless i as i to make search more forgiving.
        .replaceAll('ı', 'i');
  }

  bool matchesToken(Product p, String token) {
    final normalizedToken = normalizeForSearch(token);

    final name = normalizeForSearch(p.name);
    final brand = normalizeForSearch(p.brand);
    final barcode = normalizeForSearch(p.barcode);

    if (name.contains(normalizedToken) ||
        brand.contains(normalizedToken) ||
        barcode.contains(normalizedToken)) {
      return true;
    }

    for (final tag in p.tags) {
      if (normalizeForSearch(tag).contains(normalizedToken)) {
        return true;
      }
    }

    return false;
  }

  final results = products.where((p) {
    for (final token in tokens) {
      if (!matchesToken(p, token)) return false;
    }
    return true;
  }).toList(growable: false);

  results.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

  if (results.length <= limit) return results;
  return results.take(limit).toList(growable: false);
}
