import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_keys.dart';
import '../models/external_product.dart';

class ExternalSearchException implements Exception {
  final String message;

  ExternalSearchException(this.message);

  @override
  String toString() => 'ExternalSearchException: $message';
}

class JojapiExternalSearchService {
  final http.Client _client;

  JojapiExternalSearchService({http.Client? client})
      : _client = client ?? http.Client();

  Future<ExternalProduct> searchProductByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      throw ExternalSearchException('Geçerli bir barkod değeri gerekli.');
    }

    final apiKey = ApiKeys.jojapiKey;
    if (apiKey.isEmpty) {
      if (kDebugMode) {
        debugPrint(
          'JOJAPI_KEY tanımlı değil. '
          'Uygulamayı --dart-define=JOJAPI_KEY=... ile başlatın.',
        );
      }
      throw ExternalSearchException(
        'Dış ürün arama servisi yapılandırılmamış. '
        'Lütfen sistem yöneticinizle iletişime geçin.',
      );
    }

    final uri = Uri.https(
      'camgoz.jojapi.net',
      '/api/external/search',
      {
        'query': trimmed,
        'marketPrices': 'true',
        'preferredMarkets': 'A101,Şok Market',
        'historyPrices': 'true',
      },
    );

    http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: <String, String>{
              'X-JoJAPI-Key': apiKey,
            },
          )
          .timeout(const Duration(seconds: 12));
    } on Exception {
      throw ExternalSearchException(
        'Dış servis ile bağlantı kurulamadı. '
        'Lütfen internet bağlantınızı kontrol edip tekrar deneyin.',
      );
    }

    if (response.statusCode != 200) {
      throw ExternalSearchException(
        'Dış servis hata döndürdü (kod: ${response.statusCode}). '
        'Lütfen daha sonra tekrar deneyin.',
      );
    }

    final dynamic decoded = json.decode(response.body);

    // API hem tek bir nesne, hem de tek elemanlı bir liste dönebilecek şekilde
    // çalışabildiği için iki formatı da destekleyelim.
    Map<String, dynamic>? productJson;

    if (decoded is Map<String, dynamic>) {
      productJson = decoded;
    } else if (decoded is List) {
      if (decoded.isEmpty || decoded.first is! Map) {
        throw ExternalSearchException(
          'Dış servisten beklenmeyen veri formatı alındı.',
        );
      }
      productJson = Map<String, dynamic>.from(decoded.first as Map);
    } else {
      throw ExternalSearchException(
        'Dış servisten beklenmeyen veri formatı alındı.',
      );
    }

    final product = ExternalProduct.fromJson(productJson);
    if (product.barcode.isEmpty || (product.name == null && product.brand == null)) {
      throw ExternalSearchException('Bu barkod için ürün bulunamadı.');
    }

    return product;
  }
}