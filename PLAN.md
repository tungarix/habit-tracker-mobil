# Habit Tracker Mobil: Plan

Sürüm 2 (2026-11-10). Bu sürüm üç açıdan yapılan eleştiri turuyla düzeltildi: senkron/veri, Android ve sıra/kapsam. Henüz kod yok.

## Kararlar (Arda, 2026-11-10)

| Konu | Karar |
|---|---|
| Repo | Ayrı repo, `tungarix/habit-tracker-mobil` (Takvim'deki gibi). Public, MIT lisanslı. Commit'lerde Claude co-author satırı olmayacak. |
| Senkron | Önce `.habitsync` dosyasıyla iki yönlü, sonra QR + Wi-Fi. Bulut ve hesap yok. |
| İlk public sürüm kapsamı | Masaüstündeki her şey (alışkanlık, aylık tablo, istatistik, görevler, odak sayacı, mood, yedek). Ek olarak akşam hatırlatıcısı, ana ekran widget'ı ve uygulama içi güncelleme. |
| Düzen | Alt menü: Bugün / Görevler / Aylık / İstatistik. Uygulama Bugün ekranıyla açılır ve orada bugünün alışkanlık listesi durur. |

Değişmeyecek kurallar:
- **Kimlikler:** `applicationId` = `com.aktenak.habit_tracker`. Dart paket adı masaüstündekiyle aynı: `aktenak_habit_tracker`. Böylece kopyalanan testler derlenir. İkisi de bir daha değişmez. v1.2.0'da ürün adı değişince uygulama boş bir veritabanı açmıştı.
- **Görünüm:** Arayüz Türkçe. Tema Sistem / Koyu / Açık; mobilde varsayılan Sistem.
- **Erişilebilirlik:** WCAG AA. Alt yazılar en az 12 px, dokunma alanları en az 48 dp. TalkBack her işaretin durumunu okuyabilmeli.
- **Dağıtım:** Yalnız sideload: GitHub Release ve aktenak.tech. Play Store yok.
- **İnternet:** Yalnız kullanıcı açarsa kullanılır. Kullanım yerleri güncelleme ve Wi-Fi senkronu.

## Kod paylaşımı: ayrı repo, kopyalanan kod

Masaüstü de Flutter/Dart ile yazılı. Bu yüzden mobil sıfırdan yazılmaz; masaüstü kodu kopyalanıp mobile göre budanır.

**`tool/esitle.ps1` neleri kopyalar (liste açık):**
- `lib/core/*` (`window_placement.dart` hariç; masaüstüne özgü)
- `lib/data/database/{tables,database,database.g}.dart`. `.g.dart` kopyalanır, mobilde yeniden üretilmez.
- `lib/data/data_location.dart`, `lib/data/repositories/*.dart`, `lib/data/auto_backup.dart`
- Bunların masaüstündeki testleri

**Bilinçli sapmalar:** Mobilin bilerek farklı tuttuğu dosyalar `tool/kaynak_ozet.json` içinde gerekçesiyle yazılır. İlk sapma DB bağlantısıdır (`_openConnection`, Faz 2'deki widget maddesine bakın).

**Sürüm sabitleme:** `drift`, `drift_dev`, `sqlite3` ve `sqlite3_flutter_libs` iki pubspec'te aynı tam sürüme sabitlenir. Flutter iki CI'da da aynı sürümdür (3.47.5). Masaüstü CI şu an `stable` kullanıyor; o da sabitlenir.

**Ayrışma bekçisi (mobil CI'da):**
1. `test/uyum_test.dart` iki şeyi denetler: kopyaların SHA-256 özetleri `kaynak_ozet.json` ile tutuyor mu; masaüstünün kopyalanan testleri mobilde geçiyor mu.
2. `ci.yml` public `tungarix/habit-tracker` reposunu iki noktada checkout eder: `kaynak_ozet.json`'da yazan etiket ve master.
   - Etiketteki dosyalar kopyalarla tutmazsa CI kırılır.
   - Master'daki dosyalar farklıysa yalnız uyarı verir ("masaüstü ilerledi, esitle çalıştır").
3. Masaüstü reposunun `PULL_REQUEST_TEMPLATE.md` dosyasına bir madde eklenir: core/ veya data/ değiştiyse mobilde `esitle.ps1` çalıştırılmalı.

**İlk taşıma yolu:** Senkron gelene kadar (Faz 1–2) masaüstünün JSON yedeği mobilde içe aktarılır. v1–v4 yedekleri okunuyor. Faz 3'teki "ilk eşleştirme" kuralı bu yolla taşınmış veriyi de kapsar.

## Fazlar

"Bitti" demek, işin Arda'nın gerçek telefonunda açılıp denenmiş olması demek. Emülatörde denemek yalnız ara adımdır.

### Faz 0: İskelet ve yayın hattı
1. Proje `flutter create --org com.aktenak --project-name aktenak_habit_tracker --platforms android` ile kurulur. `build.gradle.kts` içinde `applicationId` elle `com.aktenak.habit_tracker` yapılır.
2. Takvim-mobil'den alınanlar:
   - İş akışları ve betikler: `release.yml`, `ci.yml`, `guvenlik-kapisi.yml`, `scripts/guvenlik_kapisi.py`, `guvenlik/incelemeler/README.md`.
   - Test betiği: `tool/test_calistir.ps1`. Windows'ta `flutter_tester` rastgele çöktüğü için testler bu betikle, dosya dosya çalıştırılır.
   - Gradle düzeltmeleri: `desugar_jdk_libs`, `path_provider_android <2.3.0` override, `--target-platform android-arm,android-arm64,android-x64`.
   - Ortam değişkeni ve secret önekleri `HABIT_KEYSTORE*` olarak değiştirilir.
3. Yayın anahtarı `scripts/imza_anahtari_olustur.ps1` ile üretilir. İki ayrı yerde yedeklenir: `Belgeler\habit-tracker-mobil-imza` ve `D:\Yedek-Imza-Anahtarlari\`. Sertifikanın SHA-256 parmak izi README'ye yazılır.
4. `lib/surum.dart` ile pubspec sürümünün aynı olduğunu bir test denetler.
5. Masaüstü reposunda Flutter sürümü sabitlenir ve PR şablonuna yukarıdaki madde eklenir.
6. **Çıkış:** CI imzalı boş bir APK üretir ve bu APK Arda'nın telefonunda açılır.

> Telefona hiçbir zaman yerel debug APK kurulmaz. Debug imzası farklı olduğu için yayın sürümü onun üstüne kurulamaz. `allowBackup=false` olduğu için uygulamayı kaldırıp yeniden kurmak da veriyi siler.

### Faz 1: Çekirdek port → iç ön sürüm v0.0.x
1. `esitle.ps1` yazılır, kopyalar alınır, uyum testi ve CI bekçisi kurulur.
2. Alt menülü kabuk ve ekranlar:
   - **Bugün:** Alışkanlık listesi. Dokundukça ✓ → ✗ → – → boş sırasıyla döner; sayılı alışkanlıkta uzun basınca miktar girilir. Mood seçimi de burada. 30 günlük ısı şeridi kartın içinde açılıp kapanır.
   - **Görevler**, **İstatistik**, **Alışkanlıklar**, **Ayarlar.**
   - **Aylık:** Hücreler 44 px, tablo yatay kayar. Alışkanlık adları sol sütunda sabit kalır.
   - Masaüstüne ait Ctrl kısayolları ve ipuçları alınmaz.
   - Durum işaretlerine ve tablo hücrelerine `Semantics` etiketi verilir, örneğin "Kitap, 12 Kasım: yapıldı".
3. Yedek:
   - Dışa aktarma `share_plus` ile yapılır. Masaüstündeki `saveFile` + `File(path)` deseni Android'deki content URI ile kırılır, kullanılmaz.
   - İçe aktarma `file_picker` ile, `withData: true` ayarıyla yapılır.
   - "Klasörü aç" düğmeleri kaldırılır.
   - Otomatik yedek uygulamanın kendi klasöründe kalır ve açılışta ya da uygulama öne gelince alınır. Uygulama kaldırılınca bu yedekler de silinir. Ayarlar ekranında açık bir uyarı olur: "Bu yedekler telefon dışına çıkmaz, ara sıra dışa aktar". Kullanıcının seçtiği bir klasöre (SAF) otomatik yedek Faz 2 sonrasına bırakılır.
4. **Çıkış:**
   - Arda'nın gerçek masaüstü yedeği telefona aktarılır. Seri, yüzde ve aylık tablo masaüstüyle aynı çıkar.
   - TalkBack Bugün listesini ve Aylık hücrelerini okur.
   - **CI'dan yayın anahtarıyla imzalı v0.0.1 prerelease** çıkar. Arda bunu birkaç gün gerçekten kullanır. Sonraki sürümler bunun üstüne veri kaybı olmadan kurulur ve `versionCode` her sürümde artar.

### Faz 2: Android'e özgü özellikler → public v0.1.0
Bu fazda sıra, risk büyüklüğüne göre.

1. **Widget denemesi (önce bu, en riskli iş):**
   - Masaüstündeki bağlantı kodunda her isolate ayrı bir `NativeDatabase` açıyor; WAL ya da `busy_timeout` ayarı yok. İki isolate aynı anda yazarsa "database is locked" hatası alınır. Ayrıca drift'in `watch()` akışları başka bir bağlantının yaptığı yazmayı görmez.
   - Çözüm: mobilde bağlantı, `drift_flutter` ile `driftDatabase(..., native: DriftNativeOptions(shareAcrossIsolates: true))` kullanılarak açılır. Bu bilinçli bir sapmadır ve kaynak özet listesine yazılır. home_widget'ın arka plan işi aynı süreçte çalıştığı için iki isolate tek bir sunucuyu paylaşır.
   - Ek güvence olarak uygulama öne gelince sorgular yeniden çekilir.
   - Deneme başarısız olursa yedek plan: widget veritabanına değil, home_widget'ın SharedPreferences'ına bir kuyruk yazar. Her girdi işaretleme anını taşır; bu an LWW için gerekir. Uygulama açılınca kuyruğu işler. Veritabanına yeni tablo eklenmez.
2. **Ana ekran widget'ı:**
   - `home_widget` paketi ve Kotlin'de bir `AppWidgetProvider` ile yapılır.
   - Bugünün alışkanlıklarını gösterir; dokununca ✓ yazar.
   - Arka plan işi yazdıktan sonra widget'ı (`saveWidgetData` + `updateWidget`) ve hatırlatıcıyı yeniden kurar.
3. **Bildirimler** (`flutter_local_notifications` + `timezone`; Takvim'in `bildirim.dart` dosyasındaki izin isteme ve izin yoksa yaklaşık zamana geri düşme kodu alınır):
   - **Akşam hatırlatıcısı:**
     - Tekrarlayan bildirim kullanılmaz. Tekrarlayan bildirimde yalnız bugünkünü atlamak mümkün değil, bildirim anında da Dart kodu çalışmaz.
     - Bunun yerine önümüzdeki 7 gün için tek seferlik bildirimler kurulur. Plan her açılışta, her işaretlemede ve widget her yazdığında yeniden hesaplanır.
     - Bugünün alışkanlıkları tamamsa bugünkü bildirim iptal edilir.
     - Zamanlama yaklaşıktır (`inexactAllowWhileIdle`), birkaç dakika kayması sorun değil.
   - **Odak sayacı:**
     - Çalışan sayacın durumu `Settings` tablosunda `focus_running` anahtarında tutulur: başlangıç, tür, plan süresi, taskId. Seans, masaüstünde olduğu gibi yalnız bitince `insertSession` ile yazılır. Böylece yarım kalmış seans satırı oluşmaz, şema ve istatistikler değişmez.
     - Bitiş bildirimi tam zamanlıdır (`exactAllowWhileIdle`). Ön plan servisi (foreground service) kullanılmaz.
   - **İzinler:**
     - `POST_NOTIFICATIONS`: hatırlatıcı ya da sayaç ilk açıldığında istenir.
     - `USE_EXACT_ALARM`, ayrıca yalnız Android 12'de geçerli olan `SCHEDULE_EXACT_ALARM` (maxSdk 32). Uygulama yalnız sideload dağıtıldığı için Play'in kısıtı burada geçerli değil.
     - `RECEIVE_BOOT_COMPLETED` ve `MY_PACKAGE_REPLACED`: bildirimler cihaz yeniden başlayınca ve uygulama güncellenince yeniden kurulur.
4. **Uygulama içi güncelleme:**
   - Takvim-mobil 0.4.0'daki kod alınır: `KurulumAlici.kt`, `PackageInstaller`, `SHA256SUMS.txt` doğrulaması.
   - İlk açılışta bir kez onay istenir. İndirme varsayılan olarak yalnız Wi-Fi'da yapılır.
5. **Manifest:**
   - `INTERNET`. Release yapısında Flutter bunu kendiliğinden eklemez; unutulursa güncelleme sessizce çalışmaz.
   - `ACCESS_NETWORK_STATE`, `REQUEST_INSTALL_PACKAGES`.
   - `allowBackup=false`, `usesCleartextTraffic=false`.
   - Kamera izni yok.
6. **Güvenlik incelemesi:** Güncelleyici, widget'tan gelen yazmalar ve izinler `/security-review` ile incelenir ve `guvenlik/incelemeler/v0.1.0.md` dosyasına yazılır.
7. **Çıkış (v0.1.0):**
   - Uygulama açıkken widget'tan işaretlenen alışkanlık uygulamada hemen görünür.
   - Ekran kapalıyken 25 dakikalık sayaç zamanında çalar.
   - Hatırlatıcı gelir; alışkanlıklar tamamsa gelmez.
   - Gün dönümü (04:00) doğru çalışır.
   - Güncelleme, **imzalı yayın APK'sında** sahte bir GitHub sunucusuyla denenir (Takvim'deki `guncelleme_sahte_github.py`).

### Faz 3: Dosya ile senkron (masaüstü v1.4.0 + mobil v0.2.0, aynı gün)
Kurallar masaüstü reposundaki `docs/senkron.md` dosyasında yazılır; tek kaynak orasıdır. Takvim'in `senkron.md` dosyasındaki kurallar temel alınır.

**Şema v5, iki tarafta aynı migration:**
- **uid:** `Habits`, `Tasks` ve `FocusSessions` tablolarına `uid` eklenir. SQLite, `ADD COLUMN` ile UNIQUE ya da sabit olmayan varsayılan değer eklemeye izin vermez. Bu yüzden sütun nullable eklenir, mevcut satırlar `UPDATE` ile UUID v4 alır, ardından `CREATE UNIQUE INDEX IF NOT EXISTS` çalışır. Tablo tanımında da aynı index adı kullanılır; böylece taze kurulum ile yükseltilmiş kurulum aynı şemayı verir. `migration_test` bunu karşılaştırır.
- **updatedAt:** Beş tabloya da sabit varsayılanla eklenir, sonra `createdAt` ile doldurulur.
  - Değer, Takvim'deki gibi SQLite `AFTER INSERT/UPDATE` tetikleyicileriyle güncel tutulur. Böylece hiçbir yazma yolu unutulamaz.
  - Tetikleyici metni özet listesine girer.
- **Silme kaydı (mezar taşı):** Ayrı bir `silinenler(kind, anahtar, deletedAt)` tablosu tutulur ve `AFTER DELETE` tetikleyicisiyle doldurulur.
  - Hücreyi boşa çekmek, mood'u temizlemek ve alışkanlığı silmek (cascade dahil) satırı gerçekten siler. Bu silmeler de iz bırakır.
  - Anahtarlar: alışkanlık, görev ve seans için `uid`; hücre için `habitUid|date`; mood için `date`.
- **İlişkiler:**
  - Hücre kaydı `(habitUid, date)` ile eşleşir, mood kaydı `date` ile.
  - Seans, bağlı olduğu görevi `taskUid` ile taşır. İçe aktarmada görevler seanslardan önce işlenir. `taskUid` yerelde yoksa ya da silinmişse seansın `taskId` alanı null yapılır.
- **Gün başlangıç saati:** Bu ayar senkronlanır, LWW ile tek bir alan olarak. Alışkanlık, mood ve seansın hangi güne düştüğü bu saate bağlı; iki cihazda farklı olursa gece yapılan bir işaret iki cihazda farklı güne yazılır. `Settings`'in geri kalanı (tema, hatırlatıcı saati, `focus_running`) cihaza özeldir.

**İlk eşleştirme** (kritik: JSON yedekle taşınmış veri iki tarafta ayrı ayrı rastgele uid alır):
- uid bulunamazsa yerel satır mevcut yedek eşleme mantığıyla aranır:
  - Alışkanlık ve görev: `_findKnown`, yani ad/başlık + aynı saniyedeki `createdAt`.
  - Seans: `_sessionKey`, yani kind + startedAt + durationS + day.
- Eşleşen satır dosyadaki uid'i benimser; ikinci bir kopya oluşmaz.

**Yedek biçimi v5:**
- Yedek uid, updatedAt, deletedAt ve habitUid/taskUid alanlarını taşır.
- v5 yedekten geri dönüşte bu değerler korunur.
- v1–v4 yedekleri yukarıdaki ilk eşleştirmeyle okunur.
- "Birleştir" ile içe aktarırken updatedAt dosyadaki değerde bırakılır; "şimdi" yazılmaz, yoksa eski yedek yeni veriyi ezer.

**`.habitsync` dosyası:**
- Biçim UTF-8 JSON: `"format":"habit-sync","version":1`.
- Her seferinde tam durum yazılır. Çakışmada son değişiklik kazanır (LWW).
- İçe aktarma, updatedAt ve deletedAt değerlerini dosyadakine eşitler. Böylece aynı dosyayı iki kez içe aktarmak hiçbir şeyi değiştirmez.
- Sınırlar (dosya boyutu, kayıt sayısı, JSON derinliği) spec'e yazılır ve iki tarafta aynı uygulanır. Takvim'de mobil bu sınırlardan üçünü atlamıştı.
- Android'de `.habitsync` için VIEW ve SEND intent filtreleri eklenir; yalnız `content://` kabul edilir.

**Uçtan uca test:**
- `tool/e2e/` mobil repoda yaşar. CI masaüstü reposunu etiketten checkout eder ve iki tarafın senkron kodunu geçici veritabanlarıyla çalıştırır.
- Takvim'deki a–f senaryoları ve ölçek testi uyarlanır. Ek senaryolar:
  1. JSON ile taşınmış veri iki tarafta ayrı ayrı v5'e yükseltildikten sonra ilk senkron hiçbir kaydı ikilemez.
  2. Bir tarafta boşa çekilen ✓ öbür tarafta geri gelmez.
  3. Yedekten geri dönüş sonrası yapılan senkron doğru çalışır.
  4. İki cihazda farklı gün başlangıcı varken senkron doğru çalışır.

### Faz 4: QR + Wi-Fi senkron (masaüstü v1.5.0 + mobil v0.3.0)
- Takvim'in `senkron-wifi.md` protokolü uyarlanır:
  - QR kod telefonda bir App Link açar: `aktenak.tech/h#...`. Site tarafında `assetlinks.json` dosyasına girdi eklenir.
  - Bağlantı HTTPS'dir. Sertifika parmak iziyle sabitlenir; parmak iz, sertifikanın DER halinin SHA-256'sıdır.
  - 128 bitlik tek kullanımlık token kullanılır.
  - Yalnız özel IPv4 adreslere bağlanılır ve iki onay istenir.
- **Mobil istemci:** Takvim'in `wifi_istemci.dart` ve `sha256.dart` dosyaları alınır; bunlar zaten Dart.
- **Masaüstü sunucusu yeni yazılır, en riskli parça bu:**
  - Dart kendi başına sertifika üretmez. Önce küçük bir deneme yapılır: `basic_utils` (`X509Utils.generateSelfSignedCertificate`) → `SecurityContext.useCertificateChainBytes` ve `usePrivateKeyBytes` → `HttpServer.bindSecure`.
- **İzin:** `INTERNET` zaten Faz 2'de eklendi. targetSdk 37'ye çıkınca `ACCESS_LOCAL_NETWORK` gerekecek.

## Yayın düzeni
1. Sürüm yükseltilir.
2. `/security-review` çalıştırılır.
3. `guvenlik/incelemeler/vX.Y.Z.md` yazılır ("Sonuç: geçti").
4. Etiket push edilir.
5. CI imzalı APK'yı, SHA256SUMS dosyasını ve attestation'ı içeren bir taslak release üretir.
6. Taslaktaki APK Arda'nın telefonunda denenir.
7. Arda release'i yayımlar.
8. aktenak.tech, profil README'si ve vault notu güncellenir.

Faz 3 ve 4'te masaüstü ve mobil sürümleri aynı gün çıkar.

## Riskler
- **İki repo ayrışabilir.** CI bekçisi bunu yakalar, ama esitle çalıştırılmazsa mobil geride kalır. Uyarıyı görmezden gelmemek gerekir.
- **Widget eşzamanlılığı.** Faz 2'nin ilk adımı bunu dener. Yedek plan, SharedPreferences kuyruğu.
- **Faz 3 masaüstü verisine dokunuyor.** Migration ve tetikleyiciler yanlışsa Arda'nın gerçek verisi bozulur. Migration önce `canli-veri/` içindeki gerçek verinin bir kopyasında test edilir; `migration_test` bunun için genişletilir.
- **Yerel derleme.** NDK olmadan yerelde derlenen APK ~170 MB olur; yayın APK'sı yalnız CI'dan çıkar.
- **`sqlite3_flutter_libs 0.6.0+eol`.** Desteği bitiyor. İki repo yeni `sqlite3` yöntemine aynı anda geçmeli.
- **İmza anahtarı.** Kaybolursa güncelleme zinciri kopar. İki yedek konumu şart.
