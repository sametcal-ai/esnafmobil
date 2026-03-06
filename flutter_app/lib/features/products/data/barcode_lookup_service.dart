import 'dart:convert';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;

/// Basit barkod sorgulama servisi.
/// Şu an için OpenFoodFacts API kullanıyor:
/// https://world.openfoodfacts.org/api/v0/product/{barcode}.json
class BarcodeLookupService {
  static const String barcodeCacheBoxName = 'barcode_cache';

  final http.Client _client;

  BarcodeLookupService({http.Client? client})
      : _client = client ?? http.Client();

  Box get _cacheBox => Hive.box(barcodeCacheBoxName);

  Future<BarcodeLookupResult?> lookup(String barcode) async {
    final trimmed = barcode.trim();
    if (trimmed.isEmpty) return null;

    // Önce lokal cache'e bak.
    final cached = _cacheBox.get(trimmed);
    if (cached is Map) {
      return BarcodeLookupResult.fromMap(cached);
    }

    final uri = Uri.parse(
      'https://world.openfoodfacts.org/api/v0/product/$trimmed.json',
    );

    try {
      final response = await _client.get(uri);
      if (response.statusCode != 200) {
        return null;
      }

      final dynamic decoded = json.decode(response.body);
      if (decoded is! Map) return null;
      final map = Map<String, dynamic>.from(decoded);

      // OpenFoodFacts formatında status 1 ise ürün bulundu.
      final status = map['status'];
      if (status != 1) {
        return null;
      }

      final product = map['product'];
      if (product is! Map) return null;
      final p = Map<String, dynamic>.from(product);

      final name = (p['product_name'] as String?)?.trim();
      final brand = (p['brands'] as String?)?.split(',').first.trim();
      final categories = (p['categories'] as String?) ?? '';
      final firstCategory = categories
          .split(',')
          .map((e) => e.trim())
          .firstWhere(
            (e) => e.isNotEmpty,
            orElse: () => '',
          );
      final imageUrl = (p['image_url'] as String?)?.trim();

      final result = BarcodeLookupResult(
        barcode: trimmed,
        name: name,
        brand: brand,
        category: firstCategory.isEmpty ? null : firstCategory,
        imageUrl: imageUrl,
      );

      // Başarılı sonucu cache'e yaz.
      _cacheBox.put(trimmed, result.toMap());

      return result;
    } catch (_) {
      return null;
    }
  }
}

class BarcodeLookupResult {
  final String barcode;
  final String? name;
  final String? brand;
  final String? category;
  final String? imageUrl;

  const BarcodeLookupResult({
    required this.barcode,
    this.name,
    this.brand,
    this.category,
    this.imageUrl,
  });

  Map<String, dynamic> toMap() {
    return {
      'barcode': barcode,
      'name': name,
      'brand': brand,
      'category': category,
      'imageUrl': imageUrl,
    };
  }

  factory BarcodeLookupResult.fromMap(Map dynamicMap) {
    final map = Map<String, dynamic>.from(dynamicMap as Map);
    return BarcodeLookupResult(
      barcode: map['barcode'] as String,
      name: map['name'] as String?,
      brand: map['brand'] as String?,
      category: map['category'] as String?,
      imageUrl: map['imageUrl'] as String?,
    );
  }
}