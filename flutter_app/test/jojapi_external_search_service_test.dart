import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

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
}