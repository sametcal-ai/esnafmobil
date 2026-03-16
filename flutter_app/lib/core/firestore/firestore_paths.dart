class FirestorePaths {
  static String company(String companyId) => 'companies/$companyId';

  static String member(String companyId, String uid) =>
      'companies/$companyId/members/$uid';

  static String store(String companyId, String storeId) =>
      'companies/$companyId/stores/$storeId';

  static String products(String companyId) => 'companies/$companyId/products';
  static String product(String companyId, String productId) =>
      'companies/$companyId/products/$productId';

  static String customers(String companyId) => 'companies/$companyId/customers';
  static String customer(String companyId, String customerId) =>
      'companies/$companyId/customers/$customerId';

  static String suppliers(String companyId) => 'companies/$companyId/suppliers';
  static String supplier(String companyId, String supplierId) =>
      'companies/$companyId/suppliers/$supplierId';

  static String sales(String companyId) => 'companies/$companyId/sales';
  static String sale(String companyId, String saleId) =>
      'companies/$companyId/sales/$saleId';

  static String stockEntries(String companyId) =>
      'companies/$companyId/stockEntries';
  static String stockEntry(String companyId, String entryId) =>
      'companies/$companyId/stockEntries/$entryId';

  /// Ledger alt koleksiyonları için önerilen yapı:
  /// companies/{companyId}/customers/{customerId}/ledger/{entryId}
  /// companies/{companyId}/suppliers/{supplierId}/ledger/{entryId}
  static String customerLedger(String companyId, String customerId) =>
      'companies/$companyId/customers/$customerId/ledger';
  static String customerLedgerEntry(
    String companyId,
    String customerId,
    String entryId,
  ) =>
      'companies/$companyId/customers/$customerId/ledger/$entryId';

  static String supplierLedger(String companyId, String supplierId) =>
      'companies/$companyId/suppliers/$supplierId/ledger';
  static String supplierLedgerEntry(
    String companyId,
    String supplierId,
    String entryId,
  ) =>
      'companies/$companyId/suppliers/$supplierId/ledger/$entryId';

  static String alerts(String companyId) => 'companies/$companyId/alerts';
  static String alert(String companyId, String alertId) =>
      'companies/$companyId/alerts/$alertId';
}
