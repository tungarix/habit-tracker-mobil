# 10 Bağımsız son doğrulama

Önceki raporlar doğru kabul edilmedi; her şey bu turda yeniden çalıştırıldı.

## Mobil (habit-tracker-mobil)
- `flutter pub get`: tamam.
- `flutter analyze`: 1 uyarı, `tool/e2e/habitsync_uret_test.dart:8` kullanılmayan `package:drift/drift.dart` içe aktarımı. Düzeltilmedi (kozmetik, kapsam dışı).
- `tool/test_calistir.ps1`: 37 test dosyasının tamamı geçti (alisanlik_yonetimi, bugun, migration, sync dosyaları motor çökmesi sonrası 2-4. denemede). `uyum_test` (esitle özetleri + masaüstü testleri) geçti. esitle.ps1 yeniden çalıştırılmadı (kopyaları değiştirirdi); uyum_test kopya özetlerini denetliyor.
- `tool/e2e/calistir.ps1`: 15 senaryo geçti (a-f, ek 1-4, ölçek: 5.0 MB dosya, dışa 297 ms, içe 2633 ms).
- `HABIT_YEREL_NDKSIZ=1 flutter build apk --release --target-platform android-arm64`: başarılı, 180 MB. Yerelde NDK'sız; imza durumu denetlenmedi.

## Birleşik release manifest (aapt2 ile APK'dan ve Gradle ara dosyasından)
Plana uyan: INTERNET var; ACCESS_NETWORK_STATE, REQUEST_INSTALL_PACKAGES, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, USE_EXACT_ALARM, SCHEDULE_EXACT_ALARM (maxSdk 32); CAMERA yok; `allowBackup=false`; `usesCleartextTraffic=false`.
Plan dışı (not): FOREGROUND_SERVICE, WAKE_LOCK, VIBRATE. Ayrıca bağımlılıktan DYNAMIC_RECEIVER_NOT_EXPORTED_PERMISSION (uygulamaya özel, zararsız).
Exported bileşenler: MainActivity, HabitWidgetProvider, Glance RemoteViewsService (BIND_REMOTEVIEWS), WorkManager SystemJobService (BIND_JOB_SERVICE), DiagnosticsReceiver ve ProfileInstallReceiver (DUMP izinli). MY_PACKAGE_REPLACED intent filtresi bu turda ayrıca doğrulanmadı.
Uyarı: 180 MB APK, güncelleyicinin varsayılan 150 MB sınırının üstünde; CI'daki (NDK'lı) APK için ayrıca kontrol gerekir.

## Masaüstü v5 çalışma kopyası (habit-tracker-v5-calisma)
23 test dosyasının tamamı geçti (delete_habit, sync_ui 2. denemede). git status temiz. HEAD b6e4467, yerel dal `mobil-senkron-v5`.

## Masaüstü master (habit-tracker)
- `git status`: yalnız `habit-tracker-kaynak/` untracked. Master = 2a445df.
- `canli-veri/AppData/aktenak.sqlite` SHA-256 `543aa98a...` = 07 raporundaki değer (değişmemiş). Yalnız bu dosya karşılaştırıldı (raporlardaki tek özet).

## Yayın izi
- Mobil: remote yok, etiket yok, tek dal `main`; commit mesajlarında Claude/Anthropic/Co-Authored-By yok. Masaüstü: tek eşleşme eski public commit 2736a60 (".claude/ gitignore"), atıf değil.
- Masaüstü: remote yalnız `origin`; push bu tur yapılmadı; 8 etiket (v1.x); dallar master, mobil-senkron-v5.
- Takip edilen dosyalarda `.jks/.keystore/.pem/key.properties/.env` yok. `password/token/secret` taraması yalnız `${{ secrets.* }}`, `System.getenv`, betik açıklamaları ve TLS spike örnek değişkenlerini buldu; gerçek değer yok.
- Kişisel veri: canli-veri'deki alışkanlık/görev adları takip edilen dosyalarda arandı; eşleşenler genel adlar (Egzersiz, Gitar, 10 bin adım; masaüstü public testlerinde de var) ve 05 raporundaki genel adlar. İncelenen iki ekran görüntüsü (bugun, gorevler) uydurma veri. Diğer 7 ekran görüntüsü tek tek açılmadı; 09 raporu uydurma veri diyor, görsel doğrulanmadı.

## Doğrulanmadı
Emülatör ve gerçek cihaz bu turda kullanılmadı. Güncelleme kurulumu, bildirim, ekran kapalı sayaç, TalkBack, yeniden başlatma: denenmedi. SABAH-OZET.md bunları kullanıcı listesine taşıdı.
