import 'dart:async';
import 'dart:convert';
import 'dart:io';

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
  final String _apiKey;

  JojapiExternalSearchService({
    http.Client? client,
    String? apiKey,
  })  : _client = client ?? http.Client(),
        _apiKey = apiKey ?? ApiKeys.jojapiKey;

  Future<ExternalProduct> searchProductByBarcode(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      throw ExternalSearchException('Geçerli bir barkod değeri gerekli.');
    }

    final apiKey = _apiKey;
    if (apiKey.isEmpty) {
sEmpty) {
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
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService timeout: $e');
      }
      throw ExternalSearchException(
        'Dış servis yanıt vermedi (zaman aşımı). '
        'Lütfen tekrar deneyin.',
      );
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService socket error: $e');
      }
      throw ExternalSearchException(
        'Dış servise bağlanılamadı. '
        'Ağ bağlantınızı ve DNS ayarlarınızı kontrol edip tekrar deneyin.',
      );
    } on HandshakeException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService TLS handshake error: $e');
      }
      throw ExternalSearchException(
        'Dış servis ile güvenli bağlantı kurulamadı. '
        'Cihaz tarih/saat ayarlarını kontrol edip tekrar deneyin.',
      );
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService client error: $e');
      }
      throw ExternalSearchException(
        'Dış servis ile bağlantı kurulamadı. '
        'Lütfen daha sonra tekrar deneyin.',
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService unexpected error: $e');
      }
      throw ExternalSearchException(
        'Dış servis ile bağlantı kurulamadı. '
        'Lütfen daha sonra tekrar deneyin.',
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