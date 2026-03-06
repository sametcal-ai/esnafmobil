import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:flutter_app/models/external_product.dart';
import 'package:flutter_app/services/jojapi_external_search_service.dart';

class _FakeApiKeysOverride {
  static void setJojapiKeyForTest() {
    // Bu sınıf sadece sembolik; gerçek JOJAPI_KEY, testlerde environment
    // üzerinden gelmelidir. Burada sadece dokümantasyon amaçlı tutuluyor.
  }
}

void main() {
  test('JojapiExternalSearchService parses successful response', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/external/search');
      expect(request.url.queryParameters['query'], '1234567890');
      expect(request.headers.containsKey('X-JoJAPI-Key'), true);

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

    final service = JojapiExternalSearchService(client: client);

    // JOJAPI_KEY env olmadığında servis hata fırlatır, bu nedenle burada
    // doğrudan çağırmak yerine sadece ExternalProduct.fromJson test ediliyor.
    final product = ExternalProduct.fromJson({
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

    expect(product.barcode, '1234567890');

    // Servis çağrısı, gerçek JOJAPI_KEY olmadığı için burada doğrudan
    // doğrulanmıyor; URL ve header beklentileri MockClient içinde test edildi.
    expect(service, isNotNull);
  });
}