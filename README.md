# EsnafMobil

Bu repo iki ana uygulama içerir:

- **EsnafMobil (Expo/React Native)** – `app/`, `app.json`, `package.json`
- **Flutter mobil uygulaması** – `flutter_app/`

Aşağıdaki adımlar Expo uygulaması içindir.

## Başlangıç

1. Bağımlılıkları yükle:

   ```bash
   npm install
   ```

2. Uygulamayı başlat:

   ```bash
   npx expo start
   ```

Çıktıda aşağıdaki seçenekler yer alır:

- [development build](https://docs.expo.dev/develop/development-builds/introduction/)
- [Android emulator](https://docs.expo.dev/workflow/android-studio-emulator/)
- [iOS simulator](https://docs.expo.dev/workflow/ios-simulator/)
- [Expo Go](https://expo.dev/go)

Geliştirme için **app/** klasörü altındaki dosyaları düzenleyebilirsiniz. Proje [file-based routing](https://docs.expo.dev/router/introduction) kullanır.

## Versiyonlama Kuralı

Her geliştirme (PR/commit) ile mobil uygulama versiyonu artırılmalıdır.

- Versiyon kaynağı (React Native / Expo): `app.json` içindeki `expo.version` (semver – `MAJOR.MINOR.PATCH`)
- Native build numaraları (Expo):
  - iOS: `expo.ios.buildNumber` (string, numerik)
  - Android: `expo.android.versionCode` (number)
- Web / JS tarafı: `package.json` içindeki `version` alanı, `expo.version` ile senkron tutulur.
- Flutter tarafı: `flutter_app/pubspec.yaml` içindeki `version: x.y.z+build` satırı, Expo versiyonuna göre otomatik güncellenir.

### Otomatik versiyon artırma

Aşağıdaki script’ler versiyonlamayı otomatik yönetir:

```bash
# Patch artır (varsayılan tercih)
npm run bump:patch

# Minor artır
npm run bump:minor

# Major artır
npm run bump:major
```

Script şunları yapar:

1. `app.json` içindeki `expo.version` değerini belirtilen tipe göre artırır.
2. `expo.ios.buildNumber` değerini +1 yapar (string olarak yazar).
3. `expo.android.versionCode` değerini +1 yapar.
4. `package.json` içindeki `version` alanını güncellenen `expo.version` ile eşitler.

**Kural:** PR açmadan veya deploy öncesinde uygun `npm run bump:patch|minor|major` komutunu çalıştırmak zorunludur.

## Projeyi sıfırlamak (opsiyonel)

Örnek starter koddan tamamen boş bir proje ile devam etmek isterseniz:

```bash
npm run reset-project
```

Bu komut mevcut starter kodu **app-example** klasörüne taşır ve boş bir **app/** klasörü oluşturur.

## Daha fazla bilgi

- [Expo documentation](https://docs.expo.dev/)
- [Learn Expo tutorial](https://docs.expo.dev/tutorial/introduction/)
