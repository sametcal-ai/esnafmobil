# Hive → Firestore (1 kereye mahsus) migrasyon

Bu proje Hive’da tutulan iş verilerini Firestore’a **tek seferlik** taşımak için bir geçiş (migration) katmanı içerir.

## Ne zaman çalışır?

Migrasyon yalnızca şu koşullarda otomatik tetiklenir:

- kullanıcı giriş yapmışsa
- `activeCompanyId` seçilmişse
- `SharedPreferences` içinde `migrationDone_<companyId>` flag’i **false** ise

Migrasyon tamamlanınca ilgili flag **true** yapılır ve aynı firmada tekrar çalışmaz.

## Hive box → Firestore path eşlemesi

Firestore root: `companies/{companyId}/...`

- `products` → `products/{productId}`
- `customers` → `customers/{customerId}`
- `suppliers` → `suppliers/{supplierId}`
- `sales` → `sales/{saleId}`
- `stock_entries` → `stockEntries/{entryId}`
- `customer_ledger` → `customers/{customerId}/ledger/{entryId}`
- `supplier_ledger` → `suppliers/{supplierId}/ledger/{entryId}`

## ID korunumu

- Hive kaydı `Map` ise ve `map['id']` varsa: **Firestore docId = map['id']**
- `map['id']` yoksa ve Hive key string ise: **Firestore docId = Hive key**
- ID çıkarılamıyorsa kayıt atlanır ve `debugPrint` ile raporlanır (UUID üretilmez)

## Performans

- Firestore batch write kullanılır.
- Batch commit boyutu: `450` (Firestore limit 500)
- Koleksiyon koleksiyon taşınır.

## Dosyalar

- `lib/core/migration/hive_to_firestore_migrator.dart`
- `lib/core/migration/migration_state_provider.dart`
- UI entegrasyon: `lib/features/company/presentation/company_gate_page.dart`
