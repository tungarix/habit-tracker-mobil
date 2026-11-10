# 09 Emulator turu 2

Ortam: AVD `Telefon35`, debug APK (`HABIT_YEREL_NDKSIZ=1`, `--target-platform android-x64`). Emulator tur sirasinda 2 kez coktu (exit 139, swiftshader); yeniden baslatildi, uygulama verisi korundu.
Guncelleme denemesi icin derleme: `--dart-define=GUNCELLEME_TABAN=http://10.0.2.2:8123 --dart-define=GUNCELLEME_MAKS_BAYT=1000000000` (debug APK 440 MB; varsayilan 150 MB siniri yuzunden "guncel" gosteriyordu).

## A) Guncelleme e2e - KISMEN dogrulandi, kurulum adimi DOGRULANMADI
Dogrulandi:
- Ilk acilis onayi ("Guncellemeler denetlensin mi?", Hayir / Evet) gorundu; "Evet" sonrasi sahte sunucuya `releases/latest` istegi gitti.
- Ayarlar > Guncelleme bolumu gercek ekranda: denetle, yalniz Wi-Fi, "Simdi denetle", "Yeni surum hazir: 0.1.1", "Indir ve kur" (ekran/ayarlar-guncelleme.png).
- Debug manifestte `usesCleartextTraffic=true` (yalniz `android/app/src/debug/AndroidManifest.xml`, `tools:replace`); ana (release) manifest `false` olarak DEGISMEDI.
- "Indir ve kur" Android'in "Install unknown apps" (bilinmeyen uygulama kurma izni) sayfasina yonlendirdi.
DOGRULANMADI:
- Indirme, SHA256SUMS dogrulamasi, PackageInstaller ile kurulum ve yanlis SHA ("kotu") reddi: bu izin sayfasindaki anahtari acmak sistem/guvenlik ayari degisikligi oldugu icin ACMADIM; akis orada durdu. Arda izni elle verip tekrar denemeli (sahte sunucu: `python tool/e2e/guncelleme_sahte_github.py <apk_klasoru> 0.1.1 [kotu]`, yeni.apk = `--build-name=0.1.1 --build-number=2` ile ayni debug imzali derleme).
- Not: sahte sunucu yalniz kendi PID'imle (15936) kapatildi; `taskkill /IM python.exe` kullanilmadi.

## B) Sahte veriyle ekran goruntuleri - dogrulandi
`docs/gece-raporu/ekran/`: bugun, aylik, istatistik, gorevler, ayarlar, ayarlar-guncelleme, senkron (Ayarlar "Bilgisayarla senkron" bolumu), senkron-onay, aylik-yazi-200. Veri uydurma v4 JSON (Su ic, Kitap oku, Yuruyus, Meditasyon + 3 gorev; `tool/e2e` disinda uretildi). adb push + Ice aktar > Birlestir: "4 aliskanlik, 159 kayit, 0 mood, 3 gorev, 0 seans" (beklenen sayilar). README'ye "Ekran goruntuleri" bolumu eklendi. Emulatordeki eski gercek-veri kopyasi (`canli-yedek-v4.json`) silindi.

## C) .habitsync - dogrulandi
`tool/e2e/habitsync_uret_test.dart` (yeni; `HABITSYNC_CIKTI=<yol>` ile uydurma dosya yazar). adb push, MediaStore content URI'si ile `am start -a VIEW -t application/x-habitsync -f 1`: onay ekrani acildi ("1 aliskanlik, 3 isaret, 0 gorev, 0 seans", silinmis kayit yok). Ice aktar: "Eklenen 4, guncellenen 0, silinen 0"; Istatistik Toplam 159 -> 162, "Dis fircala" eklendi. SEND intent'i denenmedi.

## D) Widget / bildirim
- Widget (3x3) ana ekrana suruklenerek eklendi (adb draganddrop), "Bugun 4/5" listesi gorundu; dokununca Meditasyon isaretlendi, widget 5/5; uygulama acilinca Bugun 5/5 ve seri guncel: DOGRULANDI.
- Uygulama on plandayken widget'tan anlik gorunme: DOGRULANMADI (widget ve uygulama ayni anda gorunmedi; yalniz widget->uygulama yonu denendi).
- `dumpsys alarm`: odak bitis alarmi tam zamanli (`window=0`, exactAllowReason=policy_permission) kayitli; aksam hatirlaticisi acilinca 20:00'a 7 gunluk inexact alarm (1 saat pencere) kayitli: DOGRULANDI. Bildirimin gercekten gelmesi, "tamamsa gelmez": DOGRULANMADI (saat ileri sarilmadi).

## E) %200 yazi boyutu - hata bulundu, duzeltildi, dogrulandi
- Bugun: tasma yok (yalniz metinler satir atladi).
- Aylik: gun basligi satirinda "BOTTOM OVERFLOWED" (sabit 48 yukseklik) ve alisanlik adlari kesildi. Duzeltme: tablo `MediaQuery.withClampedTextScaling(maxScaleFactor: 1.3)` ile sarildi, `_headerH` 48 -> 56. %200'de yeniden denendi: tasma yok (ekran/aylik-yazi-200.png; "Meditasyon" kelimesi tek satirda bolunuyor, kozmetik). font_scale 1.0'a geri alindi.
- Not: sistem yazisi %130 ustunde Aylik tablosunda artik buyumuyor (tablo sabit geometrili); erisilebilirlik karari Arda'da.

## Ek bulgu / duzeltme: durum cubugu cakismasi
Aylik ve Istatistik basliklari durum cubuguyla (saat) ust uste biniyordu (AppBar'i yok, SafeArea yok). `lib/app.dart`'ta iki sekme `SafeArea(bottom: false)` ile sarildi; emulatorde dogrulandi.

## Testler (calistirildi, gecti)
`flutter analyze lib test` temiz; `aylik_tablo_test`, `erisilebilirlik_test`, `kabuk_test`, `surum_test` gecti. Tum 37 dosya yeniden kosulmadi.

## Acik
- A'nin kurulum/SHA/yanlis-SHA kismi (izin Arda'da).
- Gercek cihaz listesi 06 raporundaki gibi aynen duruyor.
