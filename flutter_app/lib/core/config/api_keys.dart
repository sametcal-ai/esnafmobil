class ApiKeys {
  /// Dış ürün arama servisi için kullanılan JOJAPI anahtarı.
  /// Build sırasında aşağıdaki gibi iletilmelidir:
  ///
  /// flutter run --dart-define=JOJAPI_KEY=xxx
  /// flutter build apk --dart-define=JOJAPI_KEY=xxx
  static const String jojapiKey = String.fromEnvironment(
    'JOJAPI_KEY',
    defaultValue: 'jk_adKq6b60JS39Cac8e9c5v0cYLefafSbgxau6D0o73edL9449Fvbayl6tW17qukdb',
  );

  /// OpenFoodFacts için API anahtarı gerekmiyor, endpoint açıktır.
  /// Diğer servisler (UPCitemdb, Barcode Lookup vb.) için anahtarlar
  /// gerektiğinde buraya eklenip, .env / build config üzerinden yönetilebilir.
  ///
  /// Örnek:
  /// static const String upcItemDbApiKey = String.fromEnvironment(
  ///   'UPCITEMDB_API_KEY',
  ///   defaultValue: '',
  /// );
}
