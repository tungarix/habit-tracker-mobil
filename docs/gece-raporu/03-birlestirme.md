# 03 Birlestirme (UI A+B + Android C)

## Yapilan
- `MetinB` tamamen `lib/ui_metin.dart` icindeki `Metin` sinifina katlandi, `ui_metin_b.dart` silindi. Cakismalar: ayni degerli `iptal/kaydet/sil/son30Gun` tek kaldi; `gunBasligi` (B) -> `aylikGunBasligi`, `gunlukHedef` (B, sabit) -> `gunlukHedefAlan`.
- Tema: Ayarlar ekrani artik `temaModuProvider` (varsayilan Sistem) ile okur/yazar; `tema_modu.dart` sadelesti (themeModeProvider dinlemesi kalkti). Kopya `providers.dart`'a dokunulmadi.
- `lib/main.dart` yeniden yazildi: `AppDatabase.forTesting(dbBaglantisi())` (shareAcrossIsolates), `YerelBildirimler.baslat`, `widgetKaydet`, `AndroidFocusController.yukle`, provider override'lari (`databaseProvider`, `focusControllerProvider`, `reminderSettingsProvider` -> `AndroidReminderSettings`), `AutoBackupLifecycle`.
- Yeni `lib/platform/yan_etki_izleyici.dart`: acilista, one gelince ve habits/habitEntries/settings tablolarindaki her degisimde (UI ve widget yazmalari dahil, 500 ms birlestirmeli) `yanEtkileriYenile` calisir (widget + 7 gunluk hatirlatici plani).
- Bildirim izni: `BildirimKapisi.izinIste` arayuze eklendi; odak sayaci baslayinca cagrilir, hatirlatici acilinca zaten cagriliyordu.
- README: ozellik listesi, kurulum notlari, yerel derleme notu; parmak izi alani "ilk surumde yazilacak".
- Testler: `yan_etki_izleyici_test` eklendi; `ayarlar_test` tema adimi (varsayilan artik Sistem) guncellendi; `SahteBildirim`e `izinIste` eklendi.

## Dogrulananlar (calistirildi)
- `flutter analyze`: No issues found.
- `tool/test_calistir.ps1`: 31 test dosyasinin hepsi gecti (uyum_test dahil; kabuk_test bir kez motor cokmesiyle yeniden denendi).
- `HABIT_YEREL_NDKSIZ=1 flutter build apk --release --target-platform android-arm64`: derlendi, 171,3 MB (home_widget'li gercek Gradle derlemesi, indirme gerekmedi; 02c'deki engel kalkti).
- Birlesik release manifesti (`merged_manifests/release`): INTERNET, ACCESS_NETWORK_STATE, REQUEST_INSTALL_PACKAGES, POST_NOTIFICATIONS, RECEIVE_BOOT_COMPLETED, USE_EXACT_ALARM, SCHEDULE_EXACT_ALARM (maxSdk 32), WAKE_LOCK, FOREGROUND_SERVICE (kutuphane kaynakli); CAMERA yok; allowBackup=false; usesCleartextTraffic=false; HabitWidgetProvider ve KurulumAlici manifestte.

## Dogrulanmadi
- Emulatorde/cihazda hicbir sey calistirilmadi: widget dokunusu ve UI'ya anlik yansima, bildirim izni penceresi, zamaninda bildirim, ekran kapaliyken sayac, yeniden baslatma sonrasi bildirimler, gun donumu, TalkBack.
- `YanEtkiIzleyici` yalniz sahte bildirimle test edildi; gercek home_widget kanali ve flutter_local_notifications cagrilmadi.
- APK imzasiz/debug imzali yerel derleme; imzali yayin yok. Release APK aapt ile incelenemedi (SDK build-tools bu yolda yok), manifest ara dosyadan okundu.
- Boot/paket guncelleme: plugin'in kendi alicilari bildirimleri yeniden kurar (manifestte var); widget/plan yeniden hesabi bir sonraki acilista. Ayrica kod yazilmadi.

## Sapmalar
- `FOREGROUND_SERVICE` ve `WAKE_LOCK` izinleri home_widget/WorkManager'dan manifeste giriyor; planda yok, kaldirmak icin manifest `tools:node="remove"` gerekir (karar Arda'da, guvenlik incelemesine not).
- Odak sayaci izin istemi `AndroidFocusController.start` icinde (arayuz yerine); sayac her baslayinca cagrilir, izin verildiyse Android pencere gostermez.

## Acik isler
- Uygulama ici guncelleme arayuzu (`guncelleyiciKur` vb.) ve ayar ekrani hala bagli degil (bu gorevin kapsami disindaydi).
- Emulator dogrulamasi (02c kontrol listesi), `guvenlik/incelemeler/v0.1.0.md`, imza anahtari, CI ilk kosusu, gercek telefon denemesi.
- `android/build/` izlenmeyen klasor (commit'e girmedi).
