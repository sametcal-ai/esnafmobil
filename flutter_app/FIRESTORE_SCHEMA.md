# Firestore Veri Modeli (company-scope)

Bu proje için önerilen yaklaşım: **tüm iş verileri `companies/{companyId}` altında** tutulur.

Bu sayede:
- Security Rules daha basit olur (tek bir `companyId` scope)
- Multi-tenant yapı netleşir
- Index/backup/tenant silme işlemleri kolaylaşır

## 1) Koleksiyon yapısı

### Firma

- `companies/{companyId}`
  - `companyCode: string`
  - `name: string`
  - `createdAt: timestamp`
  - `ownerUid: string`

### Üyelik

- `companies/{companyId}/members/{uid}`
  - `uid: string` (koleksiyon grubu sorguları için, docId ile aynı)
  - `role: string` (örn: owner/admin/cashier)
  - `status: string` (örn: active/invited/disabled)
  - `permissions: string[]`
  - `storeIds: string[]`

### Mağaza

- `companies/{companyId}/stores/{storeId}`
  - `name: string`
  - `createdAt: timestamp`
  - `isActive: bool`

## 2) İş verileri (tamamı company altında)

- `companies/{companyId}/products/{productId}`
- `companies/{companyId}/customers/{customerId}`
- `companies/{companyId}/suppliers/{supplierId}`
- `companies/{companyId}/sales/{saleId}`
- `companies/{companyId}/stockEntries/{entryId}`

## 3) Ledger (müşteri / tedarikçi)

Ledger için en pratik ve sorgulanabilir yapı alt koleksiyondur:

- `companies/{companyId}/customers/{customerId}/ledger/{entryId}`
- `companies/{companyId}/suppliers/{supplierId}/ledger/{entryId}`

> Alternatif olarak `companies/{companyId}/ledger` altında `entityType + entityId` ile de tutulabilir; ancak alt koleksiyon yaklaşımı müşteri/tedarikçi bazlı listelemeyi kolaylaştırır.

## 4) Admin uyarıları

- `companies/{companyId}/alerts/{alertId}`

## 5) Kod tarafı

Flutter tarafında path/ref yardımcıları:

- `lib/core/firestore/firestore_paths.dart` (string path üretimi)
- `lib/core/firestore/firestore_refs.dart` (typed ref’ler)
