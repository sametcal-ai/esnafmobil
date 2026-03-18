import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../core/config/api_keys.dart';
import '../core/config/product_search_type.dart';
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

  Future<ExternalProduct> searchProductByBarcode(
    String barcode, {
    ProductSearchType searchType = ProductSearchType.api,
  }) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) {
      throw ExternalSearchException('Geçerli bir barkod değeri gerekli.');
    }

    switch (searchType) {
      case ProductSearchType.scrap:
        return _searchProductByBarcodeScrap(trimmed);
      case ProductSearchType.api:
      default:
        return _searchProductByBarcodeApi(trimmed);
    }
  }

  Future<ExternalProduct> _searchProductByBarcodeApi(String barcode) async {
    if (kDebugMode) {
      debugPrint(
        'JojapiExternalSearchService.searchProductByBarcode apiKey dolu mu: '
        '${_apiKey.trim().isNotEmpty} (length: ${_apiKey.length})',
      );
    }

    final apiKey = _apiKey;
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
        'query': barcode,
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

  Future<ExternalProduct> _searchProductByBarcodeScrap(String barcode) async {
    final uri = Uri.https(
      'camgoz.net',
      '/search-product',
      {
        'value': barcode,
      },
    );

    http.Response response;
    try {
      response = await _client
          .get(
            uri,
            headers: <String, String>{
              'Referer': 'https://camgoz.net/search',
              'X-Requested-With': 'XMLHttpRequest',
              'User-Agent':
                  'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/146.0.0.0 Safari/537.36',
              'Accept': '*/*',
            },
          )
          .timeout(const Duration(seconds: 20));
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService scrap timeout: $e');
      }
      throw ExternalSearchException(
        'Dış servis yanıt vermedi (zaman aşımı). '
        'Lütfen tekrar deneyin.',
      );
    } on SocketException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService scrap socket error: $e');
      }
      throw ExternalSearchException(
        'Dış servise bağlanılamadı. '
        'Ağ bağlantınızı ve DNS ayarlarınızı kontrol edip tekrar deneyin.',
      );
    } on HandshakeException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService scrap TLS handshake error: $e');
      }
      throw ExternalSearchException(
        'Dış servis ile güvenli bağlantı kurulamadı. '
        'Cihaz tarih/saat ayarlarını kontrol edip tekrar deneyin.',
      );
    } on http.ClientException catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService scrap client error: $e');
      }
      throw ExternalSearchException(
        'Dış servis ile bağlantı kurulamadı. '
        'Lütfen daha sonra tekrar deneyin.',
      );
    } on Exception catch (e) {
      if (kDebugMode) {
        debugPrint('JojapiExternalSearchService scrap unexpected error: $e');
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

    final html = response.body;

    final tableRowMatch = RegExp(
      r'<tr[^>]*class="table-light"[^>]*>([\s\S]*?)<\/tr>',
      caseSensitive: false,
    ).firstMatch(html);

    if (tableRowMatch == null) {
      throw ExternalSearchException('Bu barkod için ürün bulunamadı.');
    }

    final rowHtml = tableRowMatch.group(1) ?? '';

    String? readCell(String label) {
      final match = RegExp(
        '<td[^>]*data-label="$label"[^>]*>([\\s\\S]*?)<\\/td>',
        caseSensitive: false,
      ).firstMatch(rowHtml);
      if (match == null) return null;

      final raw = match.group(1) ?? '';
      final withoutTags = raw.replaceAll(RegExp(r'<[^>]*>'), ' ');
      final cleaned = withoutTags
          .replaceAll('&nbsp;', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim();
      return cleaned.isEmpty ? null : cleaned;
    }

    final name = readCell('Ürün');
    final brand = readCell('Marka');
    final category = readCell('Kategori');

    final imageUrl = RegExp(
      r'<img[^>]*src="([^"]+)"',
      caseSensitive: false,
    ).firstMatch(rowHtml)?.group(1);

    double? parsePrice(String? priceText) {
      if (priceText == null) return null;
      final cleaned = priceText
          .replaceAll('TL', '')
          .replaceAll('₺', '')
          .replaceAll(RegExp(r'\s+'), '')
          .trim();
      if (cleaned.isEmpty) return null;

      final normalized = cleaned.replaceAll('.', '').replaceAll(',', '.');
      return double.tryParse(normalized);
    }

    final priceText = readCell('Fiyat');
    final price = parsePrice(priceText);

    final product = ExternalProduct(
      barcode: barcode,
      name: name,
      brand: brand,
      category: category,
      imageUrl: imageUrl,
      price: price,
      total: price,
      tax: null,
      taxRate: null,
      markets: null,
      salesUnit: 'TL',
    );

    if (product.name == null && product.brand == null) {
      throw ExternalSearchException('Bu barkod için ürün bulunamadı.');
    }

    return product;
  }
}