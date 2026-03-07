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

  bool matchesToken(Product p, String token) {
    final name = p.name.toLowerCase();
    final brand = p.brand.toLowerCase();
    final barcode = p.barcode.toLowerCase();
    if (name.contains(token) || brand.contains(token) || barcode.contains(token)) {
      return true;
    }

    for (final tag in p.tags) {
      if (tag.toLowerCase().contains(token)) {
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
