# Habit Tracker Mobil

Aktenak Habit Tracker'ın Android sürümü: hesapsız, internetsiz, verin telefonunda kalır.
Masaüstü sürümü: [tungarix/habit-tracker](https://github.com/tungarix/habit-tracker).

> Durum: **iskelet (v0.0.1, geliştirme)**. Henüz kullanılabilir ekran yok; plan için [PLAN.md](PLAN.md).

## Kurulum

_Yer tutucu: ilk imzalı sürüm yayımlanınca indirme bağlantısı buraya gelecek._

APK yalnız GitHub Release ve aktenak.tech üzerinden dağıtılır (Play Store yok).
Telefonda "bilinmeyen kaynaklardan yükleme" izni gerekir.

## Doğrulama

_Yer tutucu: sertifika SHA-256 parmak izi ve `SHA256SUMS.txt` ile APK doğrulama adımları ilk imzalı sürümle yazılacak._

## Geliştirme

```
flutter pub get
flutter analyze
pwsh tool/test_calistir.ps1    # testleri dosya dosya çalıştırır (Windows'ta flutter_tester çöker)
```

- Ortak kod masaüstünden kopyalanır: `pwsh tool/esitle.ps1`. Kopyalar elle değiştirilmez;
  `test/uyum_test.dart` ve CI uyum bekçisi bunu denetler. Bilinçli sapmalar `tool/kaynak_ozet.json` içinde gerekçesiyle durur.
- Yerel debug APK telefona kurulmaz (imzası yayın sürümünden farklı). Yayın APK'sı yalnız CI'dan çıkar.

## Lisans

[MIT](LICENSE)
