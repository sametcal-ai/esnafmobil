import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

@immutable
class AppSettings {
  final double barcodeScanDelaySeconds;
  final double defaultMarginPercent;
  /// Ürün bazlı varsayılan kâr marjı (%).
  final double productDefaultMarginPercent;
  /// Aramanın devreye girmesi için gereken minimum karakter sayısı.
  final int searchFilterMinChars;
  /// Müşteri/ürün hareket listelerinde sayfa başına kayıt sayısı.
  final int movementsPageSize;

  const AppSettings({
    required this.barcodeScanDelaySeconds,
    required this.defaultMarginPercent,
    required this.productDefaultMarginPercent,
    required this.searchFilterMinChars,
    required this.movementsPageSize,
  });

  factory AppSettings.initial() {
    return const AppSettings(
      barcodeScanDelaySeconds: 2.0,
      defaultMarginPercent: 30.0,
      productDefaultMarginPercent: 30.0,
      searchFilterMinChars: 2,
      // Hareket listesi varsayılanı: 25 (5,10,15,...,100 aralığında bir değer)
      movementsPageSize: 25,
    );
  }

  AppSettings copyWith({
    double? barcodeScanDelaySeconds,
    double? defaultMarginPercent,
    double? productDefaultMarginPercent,
    int? searchFilterMinChars,
    int? movementsPageSize,
  }) {
    return AppSettings(
      barcodeScanDelaySeconds:
          barcodeScanDelaySeconds ?? this.barcodeScanDelaySeconds,
      defaultMarginPercent: defaultMarginPercent ?? this.defaultMarginPercent,
      productDefaultMarginPercent:
          productDefaultMarginPercent ?? this.productDefaultMarginPercent,
      searchFilterMinChars: searchFilterMinChars ?? this.searchFilterMinChars,
      movementsPageSize: movementsPageSize ?? this.movementsPageSize,
    );
  }
}

class AppSettingsController extends Notifier<AppSettings> {
  static const _barcodeDelayKey = 'barcode_scan_delay_seconds';
  static const _defaultMarginKey = 'default_margin_percent';
  static const _productDefaultMarginKey = 'product_default_margin_percent';
  static const _searchFilterMinCharsKey = 'search_filter_min_chars';
  static const _movementsPageSizeKey = 'movements_page_size';

  @override
  AppSettings build() {
    Future.microtask(_load);
    return AppSettings.initial();
  }

  Future<void> _load() async {
    final prefs = await SharedPreferences.getInstance();
    final delay = prefs.getDouble(_barcodeDelayKey);
    final margin = prefs.getDouble(_defaultMarginKey);
    final productMargin = prefs.getDouble(_productDefaultMarginKey);
    final searchMinChars = prefs.getInt(_searchFilterMinCharsKey);
    final movementsPageSize = prefs.getInt(_movementsPageSizeKey);

    state = state.copyWith(
      barcodeScanDelaySeconds: delay ?? state.barcodeScanDelaySeconds,
      defaultMarginPercent: margin ?? state.defaultMarginPercent,
      productDefaultMarginPercent:
          productMargin ?? state.productDefaultMarginPercent,
      searchFilterMinChars: searchMinChars ?? state.searchFilterMinChars,
      movementsPageSize: movementsPageSize ?? state.movementsPageSize,
    );
  }

  Future<void> setBarcodeDelaySeconds(double seconds) async {
    final clamped = seconds.clamp(0.5, 10.0).toDouble();
    state = state.copyWith(barcodeScanDelaySeconds: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_barcodeDelayKey, clamped);
  }

  Future<void> setDefaultMarginPercent(double percent) async {
    final clamped = percent.clamp(0, 1000).toDouble();
    state = state.copyWith(defaultMarginPercent: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_defaultMarginKey, clamped);
  }

  Future<void> setProductDefaultMarginPercent(double percent) async {
    final clamped = percent.clamp(0, 1000).toDouble();
    state = state.copyWith(productDefaultMarginPercent: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_productDefaultMarginKey, clamped);
  }

  Future<void> setSearchFilterMinChars(int value) async {
    final clamped = value.clamp(0, 10);
    state = state.copyWith(searchFilterMinChars: clamped);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_searchFilterMinCharsKey, clamped);
  }

  Future<void> setMovementsPageSize(int value) async {
    // 5 ile 100 arasında, 5'er 5'er artan değerler (5,10,15,...,100)
    final clamped = value.clamp(5, 100);
    final normalized = ((clamped / 5).round() * 5).clamp(5, 100);

    state = state.copyWith(movementsPageSize: normalized);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_movementsPageSizeKey, normalized);
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
  AppSettingsController.new,
);