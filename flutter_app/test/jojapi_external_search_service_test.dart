import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_app/core/config/product_search_type.dart';
import 'package:flutter_app/models/external_product.dart';
import 'package:flutter_app/services/jojapi_external_search_service.dart';

void main() {
  test('JojapiExternalSearchService parses successful response', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/external/search');
      expect(request.url.queryParameters['query'], '1234567890');
      expect(request.headers['X-JoJAPI-Key'], 'test_key');

      final body = jsonEncode({
        'barcode': '1234567890',
        'brand': 'Test Brand',
        'category': 'Test Category',
        'imageUrl': 'https://file.camgoz.net/example.jpeg',
        'markets': null,
        'name': 'Test Product',
        'price': 10.0,
        'salesUnit': 'TL',
        'tax': 2.0,
        'taxRate': 20,
        'total': 12.0,
      });

      return http.Response(body, 200);
    });

    final service = JojapiExternalSearchService(
      client: client,
      apiKey: 'test_key',
    );

    final product = await service.searchProductByBarcode('1234567890');

    expect(product, isA<ExternalProduct>());
    expect(product.barcode, '1234567890');
    expect(product.name, 'Test Product');
  });

  test('JojapiExternalSearchService maps timeout to user friendly message',
      () async {
    final client = MockClient((_) async {
      throw TimeoutException('timeout');
    });

    final service = JojapiExternalSearchService(
      client: client,
      apiKey: 'test_key',
    );

    await expectLater(
      () => service.searchProductByBarcode('1234567890'),
      throwsA(
        predicate(
          (e) =>
              e is ExternalSearchException && e.message.contains('zaman aşımı'),
        ),
      ),
    );
  });

  test('JojapiExternalSearchService scrap parses camgoz html response',
      () async {
    final client = MockClient((request) async {
      expect(request.url.host, 'camgoz.net');
      expect(request.url.path, '/search-product');
      expect(request.url.queryParameters['value'], '8690526643298');

      return http.Response(
        '''
        <table class="table table-hover text-center align-middle">
          <tbody>
            <tr class="table-light">
              <td data-label="Ürün" class="fw-bold">Eti Benimo Çikolatalı 80 gr</td>
              <td data-label="Barkod">
                <a class="text-primary" href="/p/x">8690526643298</a>
              </td>
              <td data-label="Marka">Eti</td>
              <td data-label="Kategori">Bisküvi</td>
              <td data-label="Fiyat" class="fw-bold text-success">30,00 TL</td>
              <td data-label="Görsel">
                <img src="https://file.camgoz.net/example.jpeg" />
              </td>
            </tr>
          </tbody>
        </table>
        ''',
        200,
      );
    });

    final service = JojapiExternalSearchService(
      client: client,
      apiKey: 'test_key',
    );

    final product = await service.searchProductByBarcode(
      '8690526643298',
      searchType: ProductSearchType.scrap,
    );

    expect(product.barcode, '8690526643298');
    expect(product.name, 'Eti Benimo Çikolatalı 80 gr');
    expect(product.brand, 'Eti');
    expect(product.category, 'Bisküvi');
    expect(product.imageUrl, 'https://file.camgoz.net/example.jpeg');
    expect(product.price, 30.0);
    expect(product.total, 30.0);
  });
}