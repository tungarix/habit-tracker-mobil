# 01 İskelet (Faz 0 + Faz 1 temeli)

## Yapılan
- `git init` (dal: main, remote yok). Flutter Android iskeleti geçici dizinde üretilip taşındı; `PLAN.md` bozulmadı.
- `applicationId` ve `namespace` = `com.aktenak.habit_tracker`; `MainActivity.kt` paketi buna göre taşındı. Derlenen manifestte `package="com.aktenak.habit_tracker"` görüldü. minSdk/targetSdk Flutter varsayılanı (Takvim ile aynı).
- `pubspec.yaml`: sürüm 0.0.1+1, SDK `^3.13.4` (Takvim ile aynı). drift/drift_dev 2.34.0, sqlite3 3.3.3 (override), sqlite3_flutter_libs 0.6.0+eol masaüstüyle birebir. `path_provider_android <2.3.0` override'ı ve `desugar_jdk_libs` (Gradle) Takvim'den alındı. window_manager/screen_retriever/nativeapi alınmadı.
- `tool/esitle.ps1` yazıldı ve çalıştırıldı: 31 dosya kopyalandı (lib/core 7 dosya, database 3, data_location, auto_backup, providers, models, 4 repository, 13 test + helpers). `tool/kaynak_ozet.json`: kaynak v1.3.3 (commit 2a445df), SHA-256'lar (satır sonu LF'ye normalize), `bilincli_sapmalar` boş.
- `lib/data/providers.dart` ve `lib/data/models/` plan listesinde yok ama `providers.dart` (görev metni gereği) ve onun içe aktardığı `models/` kopyalandı.
- `test/uyum_test.dart` (özet tutarlılığı, sapma gerekçesi, kopyalanan testlerin varlığı), `test/surum_test.dart`, `lib/surum.dart`.
- `lib/main.dart` (ProviderContainer, saatlik otomatik yedek), `lib/app.dart` (tema Sistem, Türkçe), `lib/kabuk.dart` (yer tutucu).
- CI: `ci.yml` (Takvim'in Wi-Fi adımı çıkarıldı, uyum bekçisi eklendi), `release.yml`, `guvenlik-kapisi.yml`, `scripts/guvenlik_kapisi.py`, `scripts/uyum_bekcisi.py`, `guvenlik/incelemeler/README.md`, `scripts/imza_anahtari_olustur.ps1` (çalıştırılmadı). HABIT_KEYSTORE* önekleri; `build.gradle.kts` env varsa imza, yoksa debug.
- Kök dosyalar: README (yer tutucular var), LICENSE (masaüstünden), .gitignore, analysis_options.yaml.

## Doğrulananlar
- `flutter pub get` tamam; `flutter analyze`: No issues found.
- `tool/test_calistir.ps1` ile 14 test dosyasının hepsi geçti (auto_backup, backup, core_purity, data_location, dates_dst, dates, migration, night_creation, sessions, stats, surum, tasks, uyum, widget). Motor çökmesi bu koşuda görülmedi.
- `scripts/uyum_bekcisi.py` yerelde masaüstü klasörüne karşı çalıştırıldı: çıkış 0.
- `flutter build apk --debug` derlendi (ilk deneme NDK'sız ortamda `llvm-strip` hatası verdi; `HABIT_YEREL_NDKSIZ=1` ile geçti, Takvim ile aynı düzenek). APK ~1,4 GB (yalnız derleme denemesi, silindi, hiçbir yere kurulmadı).

## Doğrulanmayanlar
- CI iş akışları (ci/release/guvenlik-kapisi) GitHub'da hiç çalışmadı; yalnız yerelde dosyalar elle gözden geçirildi. Uyum bekçisinin `actions/checkout` adımları ve `GITHUB_OUTPUT` ifadesi denenmedi.
- İmzalı yayın APK'sı, imza scripti, secret'lar: üretilmedi/çalıştırılmadı (talimat gereği).
- Uygulama cihazda/emülatörde açılmadı.

## Sapmalar / engeller
1. **file_picker**: masaüstü `^11.0.2` ile share_plus `^13.3.1` (win32 çakışması) birlikte çözülmüyor. `file_picker: ^13.3.2` (Takvim'deki) kullanıldı. Kopyalanan kodda file_picker yok; yalnız mobil arayüzde kullanılacak. Masaüstü pubspec.lock'u ile birebirlik yalnız drift/drift_dev/sqlite3/sqlite3_flutter_libs için sağlandı.
2. **dates_dst_test** "lib/ taranıyor" koruması `lib/` altında 20'den fazla .dart ister; iskelet 20'de kalıyordu. Testi değiştirmek yerine `HabitApp` doğal biçimde `lib/app.dart` dosyasına ayrıldı (masaüstündeki gibi). Faz 1 ekranlarıyla bu zaten aşılır.
3. **`scripts/imza_anahtari_olustur.ps1`**: anahtar dosya adı hâlâ `takvim-surum.jks` (satır 18). Dosya adını değiştiren `sed`, güvenlik kancası tarafından (".jks" yolu kuralı) engellendi; yeniden denenmedi, başka yolla da aşılmadı. Betik çalıştırılmayacağından zararsız ama çalıştırmadan önce elle `habit-surum.jks` yapılmalı. Ayrıca plandaki ikinci yedek konumu (`D:\Yedek-Imza-Anahtarlari\`) betikte yok (Takvim'in betiği tek yere yazıyor); eklenmedi.
4. Windows kurtarma kodu (`data_location.dart`, `Platform.isWindows`) Android'de derlenir, çalışmaz: beklenen, sapma değil.
5. Android manifestine `allowBackup=false` vb. eklenmedi (plan Faz 2 maddesi); yalnız etiket "Habit Tracker" yapıldı. Yerel uygulama adı ürün adı kararı Arda'da.
6. `.gitattributes` yok: Windows'ta git CRLF'e çeviriyor. Özetler LF'ye normalize hesaplandığı için uyum testi/bekçisi etkilenmez.

## Açık işler
- Arda: CI'ın ilk gerçek koşusu (repo açılınca), `imza_anahtari_olustur.ps1` düzeltmesi ve çalıştırılması, ikinci yedek konumu.
- Masaüstü reposunda Flutter sürümünü sabitleme ve PR şablonu maddesi (plan Faz 0/5): bu görevin kapsamı dışında, yapılmadı.
- Faz 1 ekranları (Bugün/Görevler/Aylık/İstatistik), yedek ekranı: sonraki aşama.
