# flutter_app Veri Modelleri & İlişkiler

Bu doküman, **yalnızca `flutter_app/` dizini** içindeki Flutter uygulamasının veri modellerini, Hive depolama yapısını ve aralarındaki ilişkileri özetler.

- Depolama katmanı: Hive (Map tabanlı kayıtlar, TypeAdapter yok)
- Domain katmanı: feature bazlı (auth, customers, products, sales, suppliers, pricing)
- İlişkiler: ID referansları üzerinden (foreign-key benzeri string alanlar)

---

## A) Hive Storage Haritası

### Genel notlar

- Tüm box’lar `main.dart` içinde `Hive.openBox(...)` ile açılıyor.
- Kayıtlar **Map<String, dynamic>** şeklinde tutuluyor; TypeAdapter tanımı yok.
- `core/config/hive_migrations.dart` sadece eksik `id` alanlarını dolduruyor.

### 1. Box: `users`

**Açılış:** `main.dart` → `await Hive.openBox('users');`

**Kayıt tipi:** Auth kullanıcısı (`features/auth/domain/user.dart`)

**Key yapısı:**
- Hive key: `user.id` (örn: `'1'` veya timestamp string)
- Değer: `User.toMap()` çıktısı bir Map

**Alanlar (Map)**

Kaynak: `User.toMap()` / `User.fromMap` ve ortak audit meta (`AuditMeta.toMap()`):

- `id`: `String`
- `username`: `String`
- `passwordHash`: `String` (SHA-256 hash; salt = username)
- `role`: `String` (`'admin'` veya `'cashier'`)
- `createdDate`: `int` (epoch millis) – kaydın oluşturulma zamanı
- `createdBy`: `String` – oluşturanın kimliği (şu an `'system'` veya `'migration'`)
- `modifiedDate`: `int` – son değişiklik zamanı
- `modifiedBy`: `String` – son değiştiren
- `versionNo`: `int` – sürüm numarası (en az 1)
- `versionDate`: `int` – `versionNo`’nun değiştiği zaman
- `isLocked`: `bool` – kilitliyse update yapılmamalı (şu an repo update’i reddediyor)
- `isVisible`: `bool` – listelemeye dahil mi
- `isActived`: `bool` – aktif kayıt mı
- `isDeleted`: `bool` – soft delete bayrağı

**Örnek kayıt (şema):**

```json
{
  "id": "1",
  "username": "admin",
  "passwordHash": "<sha256>",
  "role": "admin",
  "createdDate": 1738176000000,
  "createdBy": "system",
  "modifiedDate": 1738176000000,
  "modifiedBy": "system",
  "versionNo": 1,
  "versionDate": 1738176000000,
  "isLocked": false,
  "isVisible": true,
  "isActived": true,
  "isDeleted": false
}
```

---

### 2. Box: `session`

**Açılış:** `main.dart` → `await Hive.openBox('session');`

**Kullanım:** `LocalAuthRepository` (session yönetimi)

**Key / değer:**

- Key: sabit `'currentUserId'`
- Value: `String` (users box’ındaki `id`)

**Örnek:**

```json
{
  "currentUserId": "1"
}
```

İlişki: `session.currentUserId` → `users[id]` (N:1)

---

### 3. Box: `customers`

**Açılış:** `main.dart` → `await Hive.openBox('customers');`

**Kayıt tipi:** `Customer` (`features/customers/domain/customer.dart`)

**Key yapısı:**
- Hive key: `customer.id` (UUID)
- Değer: `Customer.toMap()` çıktısı

**Alanlar:**

- `id`: `String` – müşteri kimliği (PK)
- `code`: `String?` – müşteri kodu (opsiyonel)
- `name`: `String` – müşteri adı (zorunlu)
- `phone`: `String?` – telefon
- `email`: `String?`
- `workplace`: `String?` – işyeri adı
- `note`: `String?` – serbest not
- `createdDate`: `int` – kayıt oluşturulma zamanı (epoch millis)
- `createdBy`: `String` – oluşturan kimlik (şimdilik `'system'` veya `'migration'`)
- `modifiedDate`: `int` – son değişiklik zamanı
- `modifiedBy`: `String` – son değiştiren
- `versionNo`: `int` – sürüm numarası
- `versionDate`: `int` – sürüm değişim zamanı
- `isLocked`: `bool` – kilitliyse güncellenmemeli
- `isVisible`: `bool`
- `isActived`: `bool`
- `isDeleted`: `bool` – soft delete bayrağı (CustomerRepository.deleteCustomer bunu true yapar)

**Örnek şema:**

```json
{
  "id": "c123",
  "code": "M-001",
  "name": "Ahmet Müşteri",
  "phone": "+90...",
  "email": "ahmet@example.com",
  "workplace": "Ahmet Ticaret",
  "note": "Toptan müşteri",
  "createdDate": 1738176000000,
  "createdBy": "system",
  "modifiedDate": 1738176000000,
  "modifiedBy": "system",
  "versionNo": 1,
  "versionDate": 1738176000000,
  "isLocked": false,
  "isVisible": true,
  "isActived": true,
  "isDeleted": false
}
```

İlişkiler:
- `customers[id]` birçok ledger kaydı tarafından referanslanır (`customer_ledger.customerId`).

---

### 4. Box: `customer_ledger`

**Açılış:** `main.dart` → `await Hive.openBox('customer_ledger');`

**Kayıt tipi:** `CustomerLedgerEntry` (`features/customers/domain/customer_ledger.dart`)

**Key yapısı:**
- Hive key: `entry.id` (UUID)
- Değer: `CustomerLedgerEntry.toMap()` çıktısı

**Alanlar:**

- `id`: `String` – ledger satır ID’si (PK)
- `customerId`: `String` – ilgili müşteri ID’si (`customers.id`)
- `type`: `String` – `'sale'` veya `'payment'`
- `amount`: `double` – hareket tutarı (pozitif)
- `note`: `String?` – açıklama
- `createdAt`: `int` – iş olayı zamanı (epoch millis)
- `saleId`: `String?` – ilgili satış kaydının ID’si (`sales.id`), eski kayıtlar için null
- `createdDate`: `int` – kayıt oluşturulma zamanı (çoğu zaman `createdAt` ile aynı başlar)
- `createdBy`: `String` – oluşturan kimlik (şimdilik müşteri ID’si veya `'migration'`)
- `modifiedDate`: `int` – son değişiklik zamanı
- `modifiedBy`: `String` – son değiştiren
- `versionNo`: `int` – sürüm numarası
- `versionDate`: `int` – sürüm değişim zamanı
- `isLocked`: `bool`
- `isVisible`: `bool`
- `isActived`: `bool`
- `isDeleted`: `bool`

**Örnek şema:**

```json
{
  "id": "l001",
  "customerId": "c123",
  "type": "sale",
  "amount": 250.0,
  "note": "Nakit",
  "createdAt": 1738176000000,
  "saleId": "s987",
  "createdDate": 1738176000000,
  "createdBy": "c123",
  "modifiedDate": 1738176000000,
  "modifiedBy": "c123",
  "versionNo": 1,
  "versionDate": 1738176000000,
  "isLocked": false,
  "isVisible": true,
  "isActived": true,
  "isDeleted": false
}
```

İlişkiler:
- (N) `CustomerLedgerEntry.customerId` → (1) `Customer.id`
- (opsiyonel) (N) `CustomerLedgerEntry.saleId` → (1) `Sale.id`

---

### 5. Box: `products`

**Açılış:** `main.dart` → `await Hive.openBox('products');`

**Kayıt tipi:** `Product` (`features/products/domain/product.dart`)

**Key yapısı:**
- Hive key: `product.id` (UUID)
- Değer: `Product.toMap()` çıktısı

**Alanlar (Map):**

- `id`: `String` – ürün ID’si (PK)
- `name`: `String` – ürün adı
- `brand`: `String` – marka (boş string gelebilir)
- `barcode`: `String` – barkod (boş olabilir ama pratikte dolu)
- `imageUrl`: `String?` – dış servisten gelen görsel URL’si
- `tags`: `List<String>` – etiketler
- `stockQuantity`: `int` – stok adedi
- `lastPurchasePrice`: `double` – son alış fiyatı
- `salePrice`: `double` – tanımlı satış fiyatı (KDV hariç)
- `marginPercent`: `double` – ürün bazlı kar marjı (%)
- `isManualPrice`: `bool` – manuel fiyat mı?
- `externalPrice`: `double?` – dış servis fiyatı (referans)
- `externalTax`: `double?`
- `externalTaxRate`: `double?`
- `externalTotal`: `double?` – vergi dahil toplam
- `externalDate`: `String? | DateTime?` – dış API sorgu tarihi (ISO string veya DateTime; `fromMap` her ikisini de normalize ediyor)
- `createdDate`: `int` – kayıt oluşturulma zamanı
- `createdBy`: `String` – oluşturan kimlik (şimdilik `'system'`/`'migration'`)
- `modifiedDate`: `int`
- `modifiedBy`: `String`
- `versionNo`: `int`
- `versionDate`: `int`
- `isLocked`: `bool`
- `isVisible`: `bool`
- `isActived`: `bool`
- `isDeleted`: `bool` – soft delete bayrağı (ProductRepository.deleteProduct bunu true yapar)

**Örnek şema:**

```json
{
  "id": "p001",
  "name": "Kahve",
  "brand": "Marka X",
  "barcode": "869...",
  "imageUrl": "https://...",
  "tags": ["içecek", "sıcak"],
  "stockQuantity": 42,
  "lastPurchasePrice": 20.0,
  "salePrice": 30.0,
  "marginPercent": 50.0,
  "isManualPrice": false,
  "externalPrice": 19.5,
  "externalTax": 3.5,
  "externalTaxRate": 18.0,
  "externalTotal": 23.0,
  "externalDate": "2026-01-30T10:00:00.000Z",
  "createdDate": 1738176000000,
  "createdBy": "system",
  "modifiedDate": 1738176000000,
  "modifiedBy": "system",
  "versionNo": 1,
  "versionDate": 1738176000000,
  "isLocked": false,
  "isVisible": true,
  "isActived": true,
  "isDeleted": false
}
```

İlişkiler:
- (1) Product — (N) StockEntry (`stock_entries.productId`)
- (1) Product — (N) SaleItem (`sales.items[].productId`)

---

### 6. Box: `suppliers`

**Açılış:** `main.dart` → `await Hive.openBox('suppliers');`

**Kayıt tipi:** `Supplier` (`features/suppliers/domain/supplier.dart`)

**Key yapısı:**
- Hive key: `supplier.id` (UUID)
- Değer: `Supplier.toMap()` çıktısı

**Alanlar:**

- `id`: `String` – tedarikçi ID’si (PK)
- `name`: `String` – ad
- `phone`: `String?`
- `address`: `String?`
- `note`: `String?`
- `createdDate`: `int`
- `createdBy`: `String`
- `modifiedDate`: `int`
- `modifiedBy`: `String`
- `versionNo`: `int`
- `versionDate`: `int`
- `isLocked`: `bool`
- `isVisible`: `bool`
- `isActived`: `bool`
- `isDeleted`: `bool` – soft delete (SupplierRepository.deleteSupplier)

**Örnek şema:**

```json
{
  "id": "s001",
  "name": "Tedarikçi A",
  "phone": "+90...",
  "address": "Adres...",
  "note": "Vadeli çalışıyor",
  "createdDate": 1738176000000,
  "createdBy": "system",
  "modifiedDate": 1738176000000,
  "modifiedBy": "system",
  "versionNo": 1,
  "versionDate": 1738176000000,
  "isLocked": false,
  "isVisible": true,
  "isActived": true,
  "isDeleted": false
}
```

İlişkiler:
- (1) Supplier — (N) StockEntry (`stock_entries.supplierId`)

---

### 7. Box: `stock_entries`

**Açılış:** `main.dart` → `await Hive.openBox('stock_entries');`

**Kayıt tipi:** `StockEntry` (`features/suppliers/domain/stock_entry.dart`)

**Key yapısı:**
- Hive key: `entry.id` (UUID)
- Değer: `StockEntry.toMap()` çıktısı

**Alanlar:**

- `id`: `String` – stok hareket ID’si (PK)
- `supplierId`: `String?` – ilgili tedarikçi ID’si (`suppliers.id`), satış kaynaklı çıkışlarda null
- `productId`: `String` – ilgili ürün ID’si (`products.id`)
- `quantity`: `int` – adet (giriş/çıkış yönüne göre anlamı değişir)
- `unitCost`: `double` – birim alış maliyeti (çıkışta 0 olabilir)
- `createdAt`: `int` – iş olayı zamanı (epoch millis)
- `type`: `String` – `'incoming'` veya `'outgoing'`
- `createdDate`: `int`
- `createdBy`: `String`
- `modifiedDate`: `int`
- `modifiedBy`: `String`
- `versionNo`: `int`
- `versionDate`: `int`
- `isLocked`: `bool`
- `isVisible`: `bool`
- `isActived`: `bool`
- `isDeleted`: `bool`

**Örnek şema:**

```json
{
  "id": "st001",
  "supplierId": "s001",
  "productId": "p001",
  "quantity": 10,
  "unitCost": 18.0,
  "createdAt": 1738176000000,
  "type": "incoming",
  "createdDate": 1738176000000,
  "createdBy": "system",
  "modifiedDate": 1738176000000,
  "modifiedBy": "system",
  "versionNo": 1,
  "versionDate": 1738176000000,
  "isLocked": false,
  "isVisible": true,
  "isActived": true,
  "isDe</old_code><new_code>İlişkiler:
- (N) StockEntry.productId → (1) Product.id
- (opsiyonel) StockEntry.supplierId → Supplier.id

Not: `StockEntryRepository.createStockEntry` stok girişinde ayrıca `ProductRepository.increaseStock` çağırarak ürün stokunu güncelliyor.

### 8. Box: `supplier_ledger`

**Açılış:** `main.dart` → `await Hive.openBox('supplier_ledger');`

**Kayıt tipi:** `SupplierLedgerEntry` (`features/suppliers/domain/supplier_ledger.dart`)

**Key yapısı:**
- Hive key: `entry.id` (UUID)
- Değer: `SupplierLedgerEntry.toMap()` çıktısı

**Alanlar:**

- `id`: `String` – ledger satır ID’si (PK)
- `supplierId`: `String` – ilgili tedarikçi ID’si (`suppliers.id`)
- `type`: `String` – `'purchase'` veya `'payment'`
- `amount`: `double` – hareket tutarı (pozitif)
- `note`: `String?` – açıklama
- `createdAt`: `int` – iş olayı zamanı (epoch millis)
- `createdDate`: `int` – kayıt oluşturulma zamanı (çoğu zaman `createdAt` ile aynı başlar)
- `createdBy`: `String` – oluşturan kimlik (şimdilik tedarikçi ID’si veya `'migration'`)
- `modifiedDate`: `int` – son değişiklik zamanı
- `modifiedBy`: `String` – son değiştiren
- `versionNo`: `int` – sürüm numarası
- `versionDate`: `int` – sürüm değişim zamanı
- `isLocked`: `bool`
- `isVisible`: `bool`
- `isActived`: `bool`
- `isDeleted`: `bool`

**İlişkiler:**
- (N) `SupplierLedgerEntry.supplierId` → (1) `Supplier.id`

Bakiye hesabı:
- `purchase` → bakiyeye **+amount**
- `payment` → bakiyeye **-amount**

---

### 9. Box: `barcode_cache`tockEntry.productId → (1) Product.id
- (opsiyonel) StockEntry.supplierId → Supplier.id

Not: `StockEntryRepository.createStockEntry` stok girişinde ayrıca `ProductRepository.increaseStock` çağırarak ürün stokunu güncelliyor.

### 8. Box: `supplier_ledger`

**Açılış:** `main.dart` → `await Hive.openBox('supplier_ledger');`

**Kayıt tipi:** `SupplierLedgerEntry` (`features/suppliers/domain/supplier_ledger.dart`)

**Key yapısı:**
- Hive key: `entry.id` (UUID)
- Değer: `SupplierLedgerEntry.toMap()` çıktısı

**Alanlar:**

- `id`: `String` – ledger
**Açılış:** `main.dart` → `await Hive.openBox('barcode_cache');`

**Kod içinde doğrudan model tanımı yok.** Muhtemelen dış barkod API sonuçlarını cache’lemek için kullanılıyor.

- ASSUMPTION: Bu box içinde key = barkod (`String`), value = dış API cevabı (`Map` veya JSON string) olabilir.
- Kesin bir şema bulunmadığı için burada yalnızca ismi ve muhtemel kullanım amacı not ediliyor.

---

### 9. Box: `sales`

**Açılış:** `main.dart` → `await Hive.openBox('sales');`

**Kayıt tipi:** `Sale` (`features/sales/data/sales_repository.dart`)

**Key yapısı:**
- Hive key: `sale.id` (zaman tabanlı string; `DateTime.now().microsecondsSinceEpoch.toString()`)
- Değer: Map (inline satır listesi ile)

**Alanlar (sale Map):**

- `id`: `String` – satış ID’si (PK)
- `customerId`: `String?` – ilgili müşteri ID’si (`customers.id` veya null)
- `createdAt`: `int` – epoch millis (iş olayı zamanı)
- `subtotal`: `double` – indirim & vergi öncesi toplam
- `discount`: `double` – indirim tutarı
- `vat`: `double` – vergi (KDV) tutarı
- `total`: `double` – vergi dahil toplam
- `paymentMethod`: `String` – ödeme yöntemi (nakit, kart vb.)
- `items`: `List<Map>` – satır detayları
- `createdDate`: `int` – kayıt oluşturulma zamanı (çoğu zaman createdAt ile aynı başlar)
- `createdBy`: `String` – oluşturan kimlik (şimdilik `'system'`/`'migration'`)
- `modifiedDate`: `int`
- `modifiedBy`: `String`
- `versionNo`: `int`
- `versionDate`: `int`
- `isLocked`: `bool`
- `isVisible`: `bool`
- `isActived`: `bool`
- `isDeleted`: `bool`

**Satır (`items[]` Map) alanları:**

- `productId`: `String` – ürün ID’si (`products.id`)
- `productName`: `String` – ürün adı (snapshot olarak)
- `barcode`: `String?` – barkod
- `quantity`: `int`
- `unitPrice`: `double` – birim fiyat
- `lineTotal`: `double` – satır tutarı; okunurken eksikse quantity * unitPrice ile hesaplanır

**Örnek şema:**

```json
{
  "id": "s123",
  "customerId": "c123",
  "createdAt": 1738176000000,
  "subtotal": 100.0,
  "discount": 10.0,
  "vat": 18.0,
  "total": 108.0,
  "paymentMethod": "cash",
  "items": [
    {
      "productId": "p001",
      "productName": "Kahve",
      "barcode": "869...",
      "quantity": 2,
      "unitPrice": 40.0,
      "lineTotal": 80.0
    }
  ],
  "createdDate": 1738176000000,
  "createdBy": "system",
  "modifiedDate": 1738176000000,
  "modifiedBy": "system",
  "versionNo": 1,
  "versionDate": 1738176000000,
  "isLocked": false,
  "isVisible": true,
  "isActived": true,
  "isDeleted": false
}
```

İlişkiler:
- (1) Sale — (N) SaleItem (embedded list)
- (opsiyonel) Sale.customerId → Customer.id
- (N) SaleItem.productId → Product.id
- (opsiyonel) CustomerLedgerEntry.saleId → Sale.id (müşteri ekstresi bağlamı)

---

## B) Model Kataloğu (Entity Listesi)

Aşağıda kodda tanımlı başlıca entity/model sınıfları listelenmiştir.

### 1. `User`

- **Dosya:** `lib/features/auth/domain/user.dart`
- **Primary key:** `id: String`

**Alanlar:**

- `id`: `String` – kullanıcı ID’si (users box key’i ile aynı)
- `username`: `String` – benzersiz kullanıcı adı (uygulama düzeyinde enforce)
- `passwordHash`: `String` – SHA-256 hash (`salt = username`)
- `role`: `UserRole` – `admin` veya `cashier`

**Serileştirme:**

- `toMap()` → yukarıdaki alanları string olarak yazar (`role.name`).
- `fromMap(Map dynamicMap)`:
  - `role` alanı yoksa varsayılan `cashier`.

---

### 2. `Customer`

- **Dosya:** `lib/features/customers/domain/customer.dart`
- **Primary key:** `id: String`

**Alanlar:**

- `id`: `String` – müşteri ID’si
- `code`: `String?` – müşteri kodu
- `name`: `String` – isim
- `phone`: `String?`
- `email`: `String?`
- `workplace`: `String?`
- `note`: `String?`

**Serileştirme:**

- `toMap()`/`fromMap()` birebir aynı alan isimleriyle çalışır.
- Null alanlar Map’te `null` olabilir.

---

### 3. `CustomerLedgerEntry` ve `CustomerBalance`

- **Dosya:** `lib/features/customers/domain/customer_ledger.dart`
- **Primary key:** `CustomerLedgerEntry.id: String`

**CustomerLedgerEntry alanları:**

- `id`: `String` – ledger satır ID’si
- `customerId`: `String` – `Customer.id` referansı
- `type`: `LedgerEntryType` – `sale` veya `payment`
- `amount`: `double` – pozitif tutar
- `note`: `String?`
- `createdAt`: `DateTime`
- `saleId`: `String?` – `Sale.id` referansı (opsiyonel)

**Serileştirme:**

- `toMap()`:
  - `type`: `type.name` ("sale" / "payment")
  - `createdAt`: `createdAt.millisecondsSinceEpoch`
- `fromMap(... )`:
  - type string'i yoksa varsayılan `sale`
  - createdAt int’ten DateTime’e çevrilir.

**CustomerBalance:**

- `customer`: `Customer`
- `balance`: `double`

Bu sınıf yalnızca hesaplama sonucunu taşımak için kullanılıyor; Hive’e doğrudan yazılmıyor.

---

### 4. `Product` (Katalog ürünü)

- **Dosya:** `lib/features/products/domain/product.dart`
- **Primary key:** `id: String`

**Alanlar:** (detaylar A-5’te)

- Kimlik ve temel bilgiler: `id`, `name`, `brand`, `barcode`, `imageUrl`
- Etiket ve stok: `tags`, `stockQuantity`
- Fiyatlandırma: `lastPurchasePrice`, `salePrice`, `marginPercent`, `isManualPrice`
- Dış servis bilgisi: `externalPrice`, `externalTax`, `externalTaxRate`, `externalTotal`, `externalDate`

**Serileştirme edge-case’leri:**

- `tags`: List değilse boş listeye düşer.
- `externalDate`:
  - String ise ISO parse edilir.
  - DateTime ise direkt atanır.

---

### 5. `Supplier`

- **Dosya:** `lib/features/suppliers/domain/supplier.dart`
- **Primary key:** `id: String`

**Alanlar:**

- `id`, `name`, `phone`, `address`, `note`

Serileştirme doğrudan Map’e.

---

### 6. `StockEntry`

- **Dosya:** `lib/features/suppliers/domain/stock_entry.dart`
- **Primary key:** `id: String`

**Alanlar:**

- `id`: `String` – stok hareket ID’si
- `supplierId`: `String?` – tedarikçi ID’si
- `productId`: `String` – ürün ID’si
- `quantity`: `int`
- `unitCost`: `double`
- `createdAt`: `DateTime`
- `type`: `StockMovementType` (`incoming` / `outgoing`)

**Serileştirme:**

- `toMap()` → `createdAt` millis, `type.name` string
- `fromMap()`:
  - `type` yoksa varsayılan `incoming`

---

### 7. `SaleItem` ve `Sale`

- **Dosya:** `lib/features/sales/data/sales_repository.dart`
- **Primary key:** `Sale.id: String`

**SaleItem alanları:**

- `productId`: `String`
- `productName`: `String`
- `barcode`: `String?`
- `quantity`: `int`
- `unitPrice`: `double`
- `lineTotal`: `double`

**Sale alanları:**

- `id`: `String`
- `customerId`: `String?`
- `createdAt`: `DateTime`
- `subtotal`: `double`
- `discount`: `double`
- `vat`: `double`
- `total`: `double`
- `items`: `List<SaleItem>`

**Serileştirme (repository içinde):**

- `createSale(...)` Map yazıyor (A-9’daki alanlar).
- `getSaleById(...)`:
  - `createdAt` int yoksa `DateTime.now()` fallback
  - `lineTotal` eksikse `quantity * unitPrice` ile hesaplıyor.

---

### 8. POS modelleri: `pos_models.dart`

- **Dosya:** `lib/features/sales/domain/pos_models.dart`
- **Not:** Bunlar Hive’e yazılmıyor; runtime state (Riverpod StateNotifier) için.

**Sınıflar:**

- `Product` (POS için sade model; id, name, barcode, unitPrice)
- `CartItem` (product + quantity)
- `PosState`
  - `items: List<CartItem>`
  - `discountType: DiscountType` (`none`, `percentage`, `fixed`)
  - `discountValue: double`
  - `heldItems: List<CartItem>?`
  - `taxRate: double`
  - Türetilmiş alanlar: `subtotal`, `discountAmount`, `netTotal`, `taxAmount`, `total`

---

### 9. `ExternalProduct`

- **Dosya:** `lib/models/external_product.dart`
- **Kullanım:** `JojapiExternalSearchService` HTTP cevabını parse ediyor.
- **Not:** Hive’e yazılmıyor (sadece network modeli).

**Alanlar:**

- `barcode: String`
- `brand: String?`
- `category: String?`
- `imageUrl: String?`
- `markets: dynamic` – ham market bilgisi
- `name: String?`
- `price: double?`
- `salesUnit: String?`
- `tax: double?`
- `taxRate: double?`
- `total: double?`

---

### 10. `AppSettings`

- **Dosya:** `lib/core/config/app_settings.dart`
- **Kayıt yeri:** SharedPreferences (Hive değil)

**Alanlar:**

- `barcodeScanDelaySeconds: double`
- `defaultMarginPercent: double`
- `productDefaultMarginPercent: double`
- `searchFilterMinChars: int`

Bunlar fiyatlandırma ve UI davranışı için global ayarlar.

---

## C) İlişki Haritası

### 1. Kullanıcı & Session

- `User (users box)` (1) — (0 veya 1) `session.currentUserId` (N-1 gibi düşünülebilir, pratikte tek aktif session)
- İlişki alanı: `session['currentUserId']` → `users[id]`

### 2. Müşteri & Ledger & Satış

- `Customer` (1) — (N) `CustomerLedgerEntry`
  - Foreign key: `CustomerLedgerEntry.customerId`
- `Customer` (1) — (0..N) `Sale`
  - Foreign key: `Sale.customerId`
- `Sale` (1) — (N) `SaleItem`
  - Embedded: `Sale.items[]` içinde Map listesi; sale dışında ayrı box yok.
- `CustomerLedgerEntry` (N) — (0..1) `Sale`
  - Foreign key: `CustomerLedgerEntry.saleId`

**Ledger işleyişi:**

- `CustomerLedgerRepository.addSaleEntry(...)`:
  - type = `sale`, amount = satış tutarı, saleId = ilgili `Sale.id`
- `CustomerLedgerRepository.addPaymentEntry(...)`:
  - type = `payment`, amount = tahsilat tutarı
- Bakiye hesabı:
  - `sale` → bakiyeye **+amount**
  - `payment` → bakiyeye **-amount**

### 3. Ürün & Stok Hareketleri & Satış Satırları

- `Product` (1) — (N) `StockEntry`
  - Foreign key: `StockEntry.productId`
- `Supplier` (1) — (N) `StockEntry`
  - Foreign key: `StockEntry.supplierId` (opsiyonel; satış kaynaklı çıkışlarda null)
- `Product` (1) — (N) `SaleItem`
  - Foreign key: `SaleItem.productId` (embedded)

**Stok akışı:**

- **Giriş:** `StockEntryRepository.createStockEntry(...)`
  - `StockEntry` type = `incoming`
  - Ardından `ProductRepository.increaseStock(...)` çağrılır.
- **Satış kaynaklı çıkış:**
  - `StockEntryRepository.createSaleEntry(...)` type = `outgoing`
  - POS tamamlandığında ayrıca `ProductRepository.decreaseStock(...)` ile stok düşülüyor.

### 4. Müşteri & PDF / Satış Detayları

- `CustomerStatementPdfService`:
  - `Customer` + `CustomerLedgerEntry` + `Sale` ve `SaleItem` kombinasyonundan PDF oluşturuyor.
  - `saleId` dolu olan ledger satırları için `SalesRepository.getSalesByIds(...)` ile satış ve satırlarını çekiyor.

---

## D) Tutarlılık Kuralları (Invariants)

### 1. Satış toplamları

- POS tarafında (`PosState`):
  - `subtotal = sum(items.lineTotal)`
  - `discountAmount`:
    - `none` → 0
    - `percentage` → `subtotal * (discountValue / 100)`
    - `fixed` → `discountValue` (0..subtotal aralığına clamp)
  - `netTotal = max(0, subtotal - discountAmount)`
  - `taxAmount = netTotal * (taxRate / 100)` (taxRate > 0 ise)
  - `total = max(0, netTotal + taxAmount)`

- `SalesRepository` kaydı:
  - `createSale` parametreleri POS’tan gelen `subtotal`, `discount`, `vat`, `total`.
  - `getSaleById` okurken `lineTotal` null ise **yeniden hesaplıyor**:

### 2. Müşteri bakiyesi

- `CustomerLedgerRepository.getBalanceForCustomer`:
  - Başlangıç bakiye 0.
  - Her entry için:
    - `type == sale` → `balance += amount`
    - `type == payment` → `balance -= amount`

- `getBalanceForCustomerBefore(...)` benzer, sadece belirli tarihten önceki kayıtları dikkate alıyor.

### 3. Ürün stokları

- `Product.stockQuantity`:
  - Stok girişlerinde `increaseStock` ile artırılır.
  - Satışta `decreaseStock` ile azaltılır; negatif olmaması için `newQuantity < 0 ? 0 : newQuantity`.

- `PosController.completeSale`:
  - Satış tamamlanmadan önce stok kontrolü yapar:
    - Eğer herhangi bir üründe `catalogProduct.stockQuantity < item.quantity` ise **satış iptal edilir** (`null` döner).
  - Başarılıysa, her ürün için `ProductRepository.decreaseStock` çağrılır ve ardından `SalesRepository.createSale` çalışır.

### 4. Fiyatlandırma

- `PriceResolver.resolveSellPrice` kuralları:
  - Eğer `product.isManualPrice == true` ve `product.salePrice > 0` → manuel fiyatı döner.
  - Aksi halde:
    - Eğer `lastPurchasePrice <= 0` → 0 döner.
    - `margin <= 0` → `lastPurchasePrice` döner.
    - Yoksa: `lastPurchasePrice * (1 + margin / 100)`
- `ProductRepository.increaseStock`:
  - Eğer ürün manuel fiyatlı **değilse** ve yeni alış fiyatı ile `marginPercent` verilmişse:
    - `salePrice` ve `marginPercent` otomatik güncellenir.

### 5. Müşteri ekstresi PDF hesapları

- `CustomerStatementPdfService.generateStatementPdf`:
  - Güvenli toplama yapar (`NaN` guard):
    - `periodSalesTotal` = tüm `LedgerEntryType.sale` kayıtlarının `amount` toplamı
    - `periodPaymentsTotal` = tüm `LedgerEntryType.payment` kayıtlarının `amount` toplamı
  - `safePreviousBalance` = `previousBalance.isFinite ? previousBalance : 0`
  - `endBalance = safePreviousBalance + periodSalesTotal - periodPaymentsTotal`

### 6. Kullanıcı kimlik doğrulama

- Şifreler hiçbir zaman plaintext olarak saklanmaz.
- Hash fonksiyonu: `sha256(salt=username :: password)` → `passwordHash` alanına yazılır.

### 7. ID tutarlılığı

- `HiveMigrations.runAll()`
  - `products`, `customers`, `suppliers`, `customer_ledger`, `stock_entries`, `sales` box’larında:
    - Eğer kayıt `Map` değilse atlanır.
    - `map['id']` string ve dolu değilse yeni UUID atanır.
    - Mevcut ID’ler **değiştirilmez**.

---

## E) Eksikler / Teknik Borçlar & Öneriler

### 1. TypeAdapter eksikliği

- Tüm Hive kayıtları **ham Map** olarak saklanıyor:
  - Tip güvenliği sınırlı (runtime’da yanlış tipler gelebilir).
  - Refactoring sırasında field isimlerinin değişmesi kolayca şema drift’e yol açar.
- Öneri:
  - Kritk entity’ler (User, Customer, Product, Supplier, StockEntry, Sale) için `TypeAdapter` tanımlayıp, versioned schema ile çalışmak.

### 2. Şema drift riski

- `CustomerLedgerEntry`, `Sale`, `Product` gibi modellerde yeni alanlar eklendiğinde:
  - Eski kayıtlar bu alanları içermeyecek.
  - Kod kısmı çoğunlukla varsayılanlarla (null/0) iyi idare ediyor, ancak **zorunlu alanlar** için dikkat gerekli.
- Öneri:
  - Yeni alan eklerken mutlaka migration adımı yazmak veya `fromMap`’te sağlam default’lar koymak.

### 3. Migration kapsamı sınırlı

- `HiveMigrations` şu an sadece `id` alanını garanti ediyor.
- Diğer alanlar için (örn. `createdAt` tipi değişimi, `role` alanı eklenmesi vs.) migration yok.
- Öneri:
  - Version bazlı migration sistemi:
    - Örn: `app_schema_version` key’i ile hangi schema sürümünde olunduğunu tutup, sırayla migration çalıştırmak.

### 4. Foreign key bütünlüğü Hive tarafında enforce edilmiyor

- Tüm ilişkiler **string ID** üzerinden, application-level kontrollere bırakılmış.
- Örnek riskler:
  - Silinen `Customer`’ın ledger ve sales kayıtları kalmaya devam edebilir.
  - Silinen `Product` için `stock_entries` veya `sales.items` kayıtları kalabilir.
- Öneri:
  - Silme operasyonlarında ilgili box’larda cascade / soft-delete mantığı uygulamak.
  - Alternatif: `isDeleted` flag’i ile soft delete.

### 5. `barcode_cache` şemasının belirsizliği

- Kodda explicit model yok; muhtemelen dış API cevabı doğrudan saklanıyor.
- Öneri:
  - Cache formatını tanımlayan bir model eklemek (örn. `CachedExternalProduct`), en azından `barcode`, `rawJson`, `createdAt` alanlarını standart hale getirmek.

---

Bu doküman, `flutter_app/` içindeki mevcut kod gerçekliğine göre hazırlanmıştır. Ek alanlar veya yeni feature’lar eklendiğinde, özellikle **A) Hive Storage Haritası** ve **C) İlişki Haritası** bölümlerinin güncellenmesi önerilir.
