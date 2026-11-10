# Karar uygulaması: dal birleştirme, v1.4.0 hazırlığı, kamera izni (10 Kasım 2026)

Kapsam: Karar 2 (dallar, v1.4.0 hazırlığı) ve Karar 3 (kamera). Hiçbir şey yayımlanmadı: push, uzak depo, etiket, GitHub release/istek yok. Commit mesajlarında Claude/Co-Authored-By yok. Özel anahtar hiçbir dosyaya, loga, commit'e yazılmadı (iki repoda ve git geçmişinde metni aranıp bulunmadı; anahtar dosyası yalnız varlığı ve boyutuyla kontrol edildi).

## Masaüstü (`habit-tracker`, `master`)

- `mobil-senkron-v5` yerel `master`'a **fast-forward** birleşti (merge commit yok, `2a445df` -> `6796394`). Önce `git status` temizdi (yalnız izlenmeyen `habit-tracker-kaynak/`, dokunulmadı). Dal ve iki worktree (`habit-tracker-v5-calisma`, `habit-tracker-guncelleme-calisma`) SİLİNMEDİ. Ana klasör `master`'da.
- Hazırlık commit'i `201e736` ("Surum 1.4.0 hazirligi ..."): `pubspec.yaml` 1.4.0+9, `lib/surum.dart` 1.4.0 (`surum_test` eşitliği denetler), `CHANGELOG.md` taslaktan gerçek 1.4.0 metnine, `README.md` (Wi-Fi + QR, `.habitsync`, uygulama içi güncelleme + imza, şema v5 "taslak" ibareleri kalktı), `docs/senkron.md` ve `docs/wifi-senkron.md` durum satırları. Bir test sürüm metnini sabit "1.3.3" bekliyordu; `uygulamaSurumu` kullanacak şekilde düzeltildi.
- Etiket yok. Sürüm numarası artık 1.4.0 olduğu için etiket atılana dek yerelde `v1.4.0` yok.

## Gerçek veri ve migration

- Gerçek veritabanının (`%APPDATA%\com.aktenak\aktenak_habit_tracker\aktenak.sqlite`, şema v4, 1 alışkanlık) **kopyası** `scratchpad\canli-kopya` altına alındı (yalnız okuma; orijinalin değişiklik zamanı değişmedi, 1 Kasım 13:29). Yanına `canli-veri` içindeki v1 ve v2 yedekleri kopyalandı.
- `HABIT_CANLI_KOPYA` ile `test/migration_v5_test.dart`: 14 test geçti; v1 -> v5, v2 -> v5 ve v4 -> v5 (gerçek kopya) satır kaybı olmadan, şema taze kurulumla aynı. Test kopyayı geçici klasöre alıp orada yükseltir. Sınır: gerçek v4 verisi çok küçük (1 alışkanlık, 0 işaret); büyük veri üzerinde denenmedi.
- Uygulama gerçek veriyle ayağa kaldırılmadı (v4 -> v5 yükseltmesinin kullanıcı makinesindeki ilk açılışı hâlâ ilk gerçek denemedir; yedek `yedekler/` altında).

## Masaüstü testleri

- `flutter analyze`: temiz.
- 34 test dosyası **dosya dosya** koşuldu (Windows'ta toplu `flutter test` rastgele "did not complete" ile çöküyor; yalnız çöken dosya yeniden denendi). Hepsi geçti. İlk turda gerçek hata yalnız `guncelleme_bolumu_test` (sabit "1.3.3"), düzeltildi, yeniden geçti.

## Mobil (`habit-tracker-mobil`)

- `tool/esitle.ps1 -Etiket v1.4.0`: 45 dosya eşitlendi. `kaynak_ozet.json`: `kaynak_commit` = `201e736...`, `etiket` = `v1.4.0`, `etiketle_ayni` = false, `yayimlandi` = false, not = "v1.4.0 (etiketlenecek) ...". Betiğe iki değişiklik: `-Etiket` parametresi (etiket henüz yoksa karşılaştırma HEAD'e göre, `etiketle_ayni` yalnız etiket varsa true) ve `wifi_*` masaüstü testlerinin kopyalanmaması (ilk çalıştırmada masaüstünün `wifi_sozlesme_test.dart` dosyası mobilin aynı adlı testini ezdi; geri alındı, betik düzeltildi).
- Eşitlemeyle gelenler: masaüstündeki `previewSyncBytes`, `lib/core/sha256.dart`, `test/sync_onizle_test.dart`, `docs/senkron.md` durum satırı.
- `uyum_test` geçti. CI bekçisi: ci.yml "Kaynak etiketi" adımı `etiket` değerini (`v1.4.0`) `tungarix/habit-tracker` reposundan checkout eder; etiket olmadığı sürece o adım **kırmızı** olur. Arda etiketi **`kaynak_commit` ile aynı commit'e** atınca yeşile döner. Yerelde simüle edildi: `git archive 201e736` çıktısına karşı `scripts/uyum_bekcisi.py` çıkış 0. Etiketten önce masaüstüne `lib/core`, `lib/data`, `test` ya da `docs/senkron.md` değiştiren yeni commit girerse `tool/esitle.ps1 -Etiket v1.4.0` yeniden çalıştırılmalı. Bu CI'da hiç koşmadı.
- Testler: `flutter analyze` temiz; `test/` altında 43 dosya tek tek koşuldu, hepsi geçti; CI'daki `tool/e2e/senkron_e2e_test.dart` (15 test) geçti.

## Karar 3: kamera izni (kalıcı)

- `PLAN.md`: Kararlar tablosuna "Kamera izni (KALICI)" satırı; Faz 2 §5 "Kamera izni yok" maddesi ve Faz 4 izin maddesi güncellendi.
- `README.md`: yeni "Gizlilik ve izinler" bölümü (kamera ne zaman, ne için, görüntü kaydedilmez/gönderilmez, izin yoksa "Bağlantıyı yapıştır", diğer izinler).
- Doğrulama: kaynak manifestte `CAMERA` ve `<uses-feature android:name="android.hardware.camera" android:required="false"/>` var (`wifi_sozlesme_test` bunu denetliyor). Gradle'ın ürettiği **birleşik debug manifest** (12:04, kamera değişikliğinden sonra) de `required="false"` gösteriyor; `mobile_scanner` bunu `true` yapmıyor. Birleşik release manifest 05:33 tarihli ve kamera öncesi, bu turda release derlenmedi.
- "İzin yalnız tara düğmesine basılınca": tarayıcı widget'ı (izin istemini `mobile_scanner` kendisi tetikler) yalnız tarama adımında kurulur; `wifi_eslestir_ekrani_test` ekran açıldığında tarayıcının yok olduğunu artık açıkça denetliyor. Gerçek cihazda izin istemi görülmedi.

## Denenmeyenler

GitHub'da CI/release hiç koşmadı; gerçek telefon, gerçek kamera ve gerçek Wi-Fi yok; masaüstü uygulaması gerçek veriyle açılmadı; büyük gerçek veri üzerinde migration yok; release APK/zip bu turda derlenmedi.

## Mobil repoda commit'e girmeyenler

Önceki turlardan izlenmeyen duran `docs/faz4/ekran/`, `rapor-birlestirme.md`, `rapor-imza.md`, `rapor-masaustu-sunucu.md`, `tool/e2e/wifi_*` bu turda commitlenmedi (benim değil).
