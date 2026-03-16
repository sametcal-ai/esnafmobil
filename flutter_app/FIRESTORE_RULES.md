# Firestore Security Rules (production)

Bu proje multi-tenant olduğu için tüm iş verisi `companies/{companyId}` altında tutulur.

## Üyelik dokümanı

Path:

- `companies/{companyId}/members/{uid}`

Kritik alanlar:

- `status`: `pending | active | disabled`
- `role`: `admin | cashier` (ihtiyaç olursa ileride genişletilir)

> `role/status/permissions/storeIds` alanları **client tarafından update edilemez**.

### Üyelik başvurusu

Client sadece kendi dokümanını oluşturabilir:

- `status` zorunlu: `pending`
- `role` zorunlu: `cashier`
- `permissions: []` ve `storeIds: []` olmak zorunda

### Approval (admin onayı)

Üyeliği aktif etmek / role atamak için Cloud Function kullanılır.

- Callable: `approveMember`
- Input: `{ companyId, uid, role }`
- Yetki: çağıran kullanıcı `companies/{companyId}/members/{callerUid}` altında `role=admin` ve `status=active` olmalı.

Function target member dokümanını şunlarla update eder:

- `status: 'active'`
- `role: 'admin' | 'cashier'`
- `approvedAt`: serverTimestamp
- `approvedBy`: admin uid

## Yetkiler (özet)

### Admin

- Company altındaki çoğu koleksiyonda read/write
- Üyelik approval/rol değişimi: **Cloud Function**

### Cashier

- Read: `products`, `customers`, `suppliers`, `sales`, `stockEntries` (company scope)
- Write (offline satış/iş akışı):
  - `sales` (create)
  - `stockEntries` (create)
  - `ledger` (create)
- `products` write: default kapalı (admin yönetir)

## Koleksiyon bazlı kurallar

- `companies/{companyId}`
  - read: active member
  - write: admin

- `companies/{companyId}/products/*`
  - read: member
  - write: admin

- `companies/{companyId}/customers/*`
  - read: member
  - write: admin
  - `customers/{customerId}/ledger/*`
    - read: member
    - create: admin veya cashier
    - update/delete: admin

- `companies/{companyId}/suppliers/*`
  - read: member
  - write: admin
  - `suppliers/{supplierId}/ledger/*` (customers ledger ile aynı)

- `companies/{companyId}/sales/*`
  - read: member
  - create: admin veya cashier
  - update/delete: admin

- `companies/{companyId}/stockEntries/*`
  - read: member
  - create: admin veya cashier
  - update/delete: admin

- `companies/{companyId}/alerts/*`
  - read: admin
  - write: kapalı (admin SDK / function üzerinden)

## Notlar

- Rules dosyası: repo kökünde `firestore.rules`
- Rules deployment için `firebase.json` içinde referanslanır.
