import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_app/models/external_product.dart';

void main() {
  test('ExternalProduct.fromJson parses basic fields', () {
    final json = {
      'barcode': '8692641003001',
      'brand': 'POLO',
      'category': 'Hırdavat',
      'imageUrl': 'https://file.camgoz.net/example.jpeg',
      'markets': null,
      'name': 'Polo Çakmak Gazı 270Ml',
      'price': 29.17,
      'salesUnit': 'TL',
      'tax': 5.83,
      'taxRate': 20,
      'total': 35,
    };

    final product = ExternalProduct.fromJson(json);

    expect(product.barcode, '8692641003001');
    expect(product.brand, 'POLO');
    expect(product.category, 'Hırdavat');
    expect(product.imageUrl, 'https://file.camgoz.net/example.jpeg');
    expect(product.name, 'Polo Çakmak Gazı 270Ml');
    expect(product.price, 29.17);
    expect(product.salesUnit, 'TL');
    expect(product.tax, 5.83);
    expect(product.taxRate, 20);
    expect(product.total, 35);
  });
}