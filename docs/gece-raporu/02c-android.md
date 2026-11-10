# 02c Android özellikleri (Faz 2: widget, bildirim, odak sayacı, güncelleme, manifest)

## Yapılan
- **Paylaşımlı DB bağlantısı** `lib/platform/db_baglanti.dart`: `driftDatabase(shareAcrossIsolates: true)`; kullanım `AppDatabase.forTesting(dbBaglantisi())`. `database.dart` kopyası değişmedi. Sapma `tool/kaynak_ozet.json` içinde yeni `bilincli_farklar` anahtarında gerekçesiyle yazıldı (`bilincli_sapmalar` kullanılmadı: o liste esitle'nin dosyayı ezmesini durdurur, burada dosya aynı). `tool/esitle.ps1` bu anahtarı koruyacak şekilde 4 satır genişletildi.
- **Widget**: `HabitWidgetProvider.kt` (home_widget `HomeWidgetProvider`), `res/layout/habit_widget.xml`, `res/xml/habit_widget_info.xml`, string/stil/arka plan. 5 satır (48 dp, ✓/○ işareti + TalkBack etiketi), "+N daha", boş/bayat gün metni. Satıra dokunma `habitwidget://isaretle?id=N` ile Dart arka plan callback'ine gider: `widgetArkaPlan` (yazar, sonra widget'ı ve hatırlatıcıyı yeniler). Dart: `widget_servisi.dart`, `bugun_ozeti.dart`, `yenileme.dart`.
- **Hatırlatıcı**: `hatirlatici_plani.dart` (saf): önümüzdeki 7 gün için tek seferlik bildirimler (id 100-106), bugünkü alışkanlıklar tamamsa bugüne ait olan atlanır, takip günü gece yarısından sonrasını doğru sayar, alışkanlığı olmayan gün atlanır. `bildirimler.dart`: `YerelBildirimler` (izin isteme, `inexactAllowWhileIdle`, tam zamanlı izin geri alınırsa yaklaşığa düşme). Zaman UTC anı olarak verilir, timezone veritabanı/takma ad tablosu gerekmedi.
- **Odak sayacı**: `odak_durumu.dart` (`focus_running` JSON: başlangıç, tür, plan süresi, taskId; seans yalnız bitince `insertSession`, 60 sn altı yazılmaz, silinmiş görev null olur), `odak_denetleyici.dart` (`AndroidFocusController implements FocusController`, duvar saatine göre, süreç ölüp açılınca devam eder ya da bitmişse kaydeder, bitiş bildirimi `exactAllowWhileIdle`). `hatirlatici_ayari.dart` (`AndroidReminderSettings implements ReminderSettings`).
- **Uygulama içi güncelleme**: Takvim 0.4.0 kodu uyarlandı: `lib/platform/guncelleme/{saf,ag,guncelleyici,sha256}.dart`, `ayarlar.dart` (durum Settings tablosunda: `update_check`, `update_record`, `update_wifi_only`), `kur.dart` (`guncelleyiciKur`, `indirmeIzinli`, `GUNCELLEME_TABAN` dart-define yalnız deneme için), `kopru.dart` + `MainActivity.kt` + `KurulumAlici.kt` (PackageInstaller). Depo `tungarix/habit-tracker-mobil`, varlık `Habit-Tracker-X.Y.Z.apk`, SHA256SUMS doğrulaması, varsayılan yalnız Wi-Fi. `tool/e2e/guncelleme_sahte_github.py` uyarlandı (sürüm parametreli).
- **Manifest**: INTERNET, ACCESS_NETWORK_STATE, REQUEST_INSTALL_PACKAGES, POST_NOTIFICATIONS, USE_EXACT_ALARM, SCHEDULE_EXACT_ALARM (maxSdk 32), RECEIVE_BOOT_COMPLETED; `allowBackup=false`, `usesCleartextTraffic=false`; kamera izni yok. Alıcılar: KurulumAlici, widget, home_widget arka plan alıcısı, flutter_local_notifications zamanlı + boot/paket güncelleme alıcıları.
- Bağımlılıklar: `drift_flutter`, `home_widget`, `flutter_local_notifications ^22.3.3`, `timezone`.

## Widget denemesi sonucu (plan Faz 2 madde 1)
- Windows ana makinede `test/db_paylasim_test.dart`: `shareAcrossIsolates` ile açılan bağlantıda ikinci bir isolate 25 satır yazdı, "database is locked" yok, birinci isolate'ın açık `watch()` akışı 26 satırı gördü. Kontrol testi: isolate başına ayrı `NativeDatabase` (masaüstü yöntemi) ile satır diskte ama açık akış haber almıyor. Yani planın varsayımı doğrulandı ve çözüm işliyor.
- **Emülatörde doğrulanmadı**: gerçek home_widget arka plan motoru (WorkManager + ayrı FlutterEngine) ile UI açıkken widget'tan yazma. Yedek plan (SharedPreferences kuyruğu) yazılmadı, çünkü deneme olumsuz değil; emülatör denemesi olumsuz çıkarsa gerekir.

## Doğrulananlar (çalıştırıldı, çıktısına bakıldı)
- `flutter analyze` (tüm proje): No issues found.
- Testler (dosya dosya `flutter test`), hepsi geçti: `guncelleme_test` (Takvim'den uyarlanmış 32 test: sürüm karşılaştırma, release çözümleme, adres denetimi, SHA256SUMS, akışlı SHA-256, sahte yerel GitHub ile indirme/özet uyuşmazlığı/kesik indirme/boyut/ETag/günde bir denetim), `guncelleme_ayarlar_test` (4), `hatirlatici_plani_test` (9: 7 gün, tamamsa bugünü atla, gün başlangıç saati, planlı gün yok, ay geçişi, DB'den plan), `odak_test` (15: focus_running seri hale getirme + bozuk değerler, seans yazma kuralları, denetleyici sahte saat/bildirimle), `widget_servisi_test` (8: URI doğrulama, yazma, count alışkanlık, arşiv/planlı olmayan, gece günü, widget JSON), `db_paylasim_test` (2), `uyum_test` (3).
- Gradle (çevrimdışı, kopya projede): home_widget'sız yapıda `:app:processDebugMainManifest`, `processDebugResources`, `compileDebugKotlin`, `processReleaseMainManifest` BAŞARILI. Release birleşik manifestinde INTERNET, ACCESS_NETWORK_STATE, REQUEST_INSTALL_PACKAGES, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, USE_EXACT_ALARM, VIBRATE (flutter_local_notifications'tan) var; CAMERA yok; allowBackup=false, usesCleartextTraffic=false görüldü. `HabitWidgetProvider.kt` home_widget'ın gerçek kaynağından alınan imzalarla yazılmış bir taslağa karşı derlendi (gerçek sınıfa karşı değil).
- `guncelleme_sahte_github.py` yerelde çalıştırıldı, `releases/latest` ve SHA256SUMS yanıtları beklenen adlarla geldi.

## Doğrulanmayanlar
- **home_widget'lı Gradle derlemesi yapılmadı**: home_widget 0.10.0 eski AGP 8.1.2 + Kotlin eklentisi 1.9.0 + glance/work-runtime/compose bağımlılıkları istiyor, hiçbiri önbellekte yok (`--offline` ile görüldü). İndirme boyutu büyük olacağından kural gereği durdum. Gerçek `flutter build apk --release` ve `apkanalyzer`/`aapt` ile APK manifestinin doğrulanması bu yüzden yapılmadı; widget alıcılarının birleşik manifestte göründüğü ve WorkManager'ın eklediği izinler (WAKE_LOCK, RECEIVE_BOOT_COMPLETED, olası foreground service) görülmedi. Hotspot'tan bağımsız bir ağda `flutter build apk --debug` ile bir kez denenmeli.
- Emülatör/cihazda hiçbir şey denenmedi: widget görünümü ve dokunma, bildirim izni ve zamanında çalma, 25 dk ekran kapalı sayaç, boot/güncelleme sonrası yeniden kurma, PackageInstaller ile güncelleme (imzalı APK + sahte sunucu), gün dönümü.
- `flutter_local_notifications` bildirimleri ve `home_widget` kanalı Dart testlerinde sahte nesneyle değil, hiç çağrılmadı (`BildirimKapisi` sahtesi kullanıldı).
- Yedek SharedPreferences kuyruğu yok (gerekmediği varsayıldı, yukarıya bak).

## Sapmalar / karar notları
1. `flutter_local_notifications` 23.x değil **22.3.3**: 23.x önbellekte olmayan AGP 9.1.1 buildscript'i istiyor.
2. Widget dokunuşu yalnız ✓ yazar, ✓ olanı geri almaz (plan: "dokununca check yazar"). ✗ ya da – olan hücre ✓ olur. Count alışkanlıkta hedef miktarın tamamı yazılır.
3. home_widget arka plan alıcısı `exported=false` (örnekteki `true` değil): widget PendingIntent ile açık bileşene gider; başka uygulama sahte ✓ gönderemez. Güvenlik incelemesine not.
4. Hatırlatıcı "tamam" tanımı masaüstüyle aynı: bugüne planlı ve ✓ olmayan alışkanlık sayısı 0. Gelecek günlerin metni genel ("bugünün alışkanlıklarını işaretlemeyi unutma"), bugününki sayılı.
5. Takvim'den alınan `guncelleme/*.dart` dosyalarındaki iç yorumlar Türkçe kaldı (proje kuralı İngilizce); çevrilmedi. Kendi yazdığım dosyalar İngilizce yorumlu.
6. Güncelleme denemesi için `--dart-define=GUNCELLEME_TABAN=http://10.0.2.2:8123` derleme seçeneği var (Takvim'deki gibi); yayın derlemesinde asla verilmemeli.
7. `flutter pub get` home_widget ile `http` ve drift_flutter ile `sqlcipher_flutter_libs 0.7.0+eol` (boş paket) çekti; APK'ya etkisi emülatör aşamasında boyuttan kontrol edilmeli.

## Bağlama (birleştirme aşaması için)
- `databaseProvider` override: `AppDatabase.forTesting(dbBaglantisi())` (providers.dart kopya, dokunulmaz).
- `main()`: `widgetKaydet()` (her açılışta), `YerelBildirimler().baslat()`; `focusControllerProvider` -> `AndroidFocusController(db:, bildirim:)` + `await yukle()`; `reminderSettingsProvider` -> `AndroidReminderSettings(db, bildirim)`.
- `yanEtkileriYenile(db, bildirim)` çağrılacak yerler: uygulama açılışı, öne gelme, her işaretleme (Bugün/Aylık). Odak başlatılırken `bildirim.izinIste()` bir kez çağrılmalı (arayüz eylemi).
- Güncelleme arayüzü: `guncelleyiciKur`, `Kopru`/`AndroidKopru` (`agTuru`, `kurulumIzniVar/Ac`, `apkKur`), `indirmeIzinli`; Takvim'deki `ui/guncelleme_akisi.dart` örnek.

## Emülatör aşaması kontrol listesi
1. İmzalı yayın benzeri APK kur; widget ekle, uygulama açıkken satıra dokun: Bugün listesi hemen güncellenmeli. Uygulama kapalıyken dokun, sonra aç: işaret orada olmalı.
2. Hatırlatıcı saatini 2 dk sonraya kur: bildirim gelmeli; tüm alışkanlıkları ✓ yap: gelmemeli.
3. 1 dk'lık sayaç, ekranı kapat: bildirim zamanında çalmalı. Uygulamayı öldür, sayaç bitince aç: seans bir kez yazılmış olmalı.
4. Emülatörü yeniden başlat: bekleyen bildirimler yerinde mi.
5. `python tool/e2e/guncelleme_sahte_github.py <klasor> 0.1.1` (+ `kotu`): imzalı APK'da güncelleme akışı; kötü özette kurulum olmamalı.

## Açık işler
- Home_widget'lı gerçek derleme (ağ uygun olunca), release APK manifest denetimi.
- Güncelleme ve ayar ekranları (arayüz aşaması), `guvenlik/incelemeler/v0.1.0.md`.
- Emülatör doğrulaması (yukarıdaki liste); olumsuz çıkarsa SharedPreferences kuyruğu yedeği.
