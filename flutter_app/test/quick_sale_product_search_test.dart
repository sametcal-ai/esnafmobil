import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/core/models/auditable.dart';
import 'package:flutter_app/features/products/domain/product.dart';
import 'package:flutter_app/features/sales/quick_sale/product_search.dart';

void main() {
  test('filterProductsForQuickSale matches by name, brand, barcode and tags', () {
    final meta = AuditMeta.create(createdBy: 'test', now: DateTime(2024));

    final products = [
      Product(
        id: '1',
        name: 'Coca Cola 1L',
        brand: 'Coca Cola',
        barcode: '8690000000001',
        tags: const ['içecek', 'soğuk'],
        stockQuantity: 10,
        lastPurchasePrice: 0,
        meta: meta,
      ),
      Product(
        id: '2',
        name: 'Nescafe Gold',
        brand: 'Nestle',
        barcode: '123',
        tags: const ['kahve', 'sıcak'],
        stockQuantity: 10,
        lastPurchasePrice: 0,
        meta: meta,
      ),
    ];

    expect(filterProductsForQuickSale(products, 'coca').single.id, '1');
    expect(filterProductsForQuickSale(products, 'nestle').single.id, '2');
    expect(filterProductsForQuickSale(products, '8690000').single.id, '1');
    expect(filterProductsForQuickSale(products, 'kahve').single.id, '2');

    // Comma-separated query acts as AND across tokens.
    expect(filterProductsForQuickSale(products, 'içecek, soğuk').single.id, '1');
    expect(filterProductsForQuickSale(products, 'içecek, sıcak'), isEmpty);
  });
}
