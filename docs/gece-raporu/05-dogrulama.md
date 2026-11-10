# 05 - Emulatorde gercek calisma dogrulamasi

Ortam: yeni AVD `Telefon35` (pixel_6, mevcut android-35 sistem imaji, indirme yok), debug APK (`HABIT_YEREL_NDKSIZ=1`; NDK klasoru bu makinede bos, strip atlandi). Ekran goruntuleri: `docs/gece-raporu/ekran/`.
Not: `Tablet35` AVD'si bu makinede yoktu (SDK `C:\Android\Sdk`).

## Dogrulandi (emulatorde calistirildi)
- Derleme + kurulum + acilis; 04:00'dan once (02:43) "9 Kasim" gunu gosteriyor (gun donumu davranisi gorsel olarak dogru).
- Bugun listesi, alisanlik isaretleme (adb tap), kapat-ac sonrasi kalicilik (force-stop sonrasi 2/10).
- Aylik tablo, Istatistik, Gorevler (gorev ekleme + listede gorunme), Ayarlar acildi.
- Masaustu verisinin ice aktarimi: canli-veri'deki SQLite (v4, kopyasi) JSON v4 yedegine cevrildi (canli-veri'de hazir JSON yoktu), adb push + Birlestir: "10 alisanlik, 19 kayit" = kaynak sayilari. Istatistikte Toplam 20 = 19 + 1 isaret; Egzersiz en uzun seri 2, kayit tarihleri kaynakla uyumlu.
- Bildirim izni: Odak baslatinca Android izin penceresi cikti, izin verilince sayac basladi; `dumpsys alarm`de tam zamanli (exact) bitis alarmi 25 dk sonraya kurulu.
- Aksam hatirlatici: 20:00'a ayarli, 7 gunluk tek seferlik inexact alarm kurulu (dumpsys).
- Widget: ana ekrana surukle-birak ile eklendi (3x3), liste gorundu, widget'a dokunma ile "10 bin adim" isaretlendi, widget 2/10'a gecti ve uygulama yeniden acilinca ayni (2/10).
- Gun donumu: `dates_test` (03:59/04:00 sinirlari), `hatirlatici_plani_test`, `odak_test` birim testleri gecti. Tum test dosyalari `tool/test_calistir.ps1` ile gecti (2 dosya cokme sonrasi yeniden denemede).

## Dogrulanmadi
- Ekran kapaliyken 25 dk sayacin zamaninda calmasi (sure/zaman nedeniyle denenmedi; yalniz alarm kaydi goruldu).
- Bildirimin gercekten gelmesi (20:00 beklenmedi), "tamamsa gelmez".
- Uygulama ici guncelleme e2e (sahte GitHub): HATA/ENGEL, asagida. Sahte sunucu ve yeni.apk (0.1.1+2, debug imzali) hazirlandi, sunucu acildi ama uygulamada tetikleyecek arayuz yok.
- Imzali release APK denenmedi (anahtar uretmek yasak); debug APK kullanildi.
- Gercek masaustu v5 `.habitsync` ile uygulamadan ice aktarma emulatorde denenmedi (yalniz JSON yedegi).
- Android 12 / farkli ekran boyutlari, boot sonrasi yeniden kurma denenmedi.

## Bulunan sorun (duzeltilmedi, kapsam)
- Uygulama ici guncelleme arayuzu hic bagli degil (`guncelleyiciKur` hicbir ekrandan cagrilmiyor; Ayarlar'da guncelleme bolumu yok). 03-birlestirme raporunda da "bagli degil" yaziyordu; plan Faz 2 madde 4 ("ilk acilista onay") eksik. v0.1.0 cikmadan ayarlar ekranina baglanmali, sonra e2e (`tool/e2e/guncelleme_sahte_github.py`, `--dart-define=GUNCELLEME_TABAN=http://10.0.2.2:8123`) calistirilmali. Yeni ekran eklemek plan disi sayildigi icin yapilmadi.

## Sapmalar
- `Tablet35` yerine yeni `Telefon35` AVD olusturuldu (AVD `~/.android/avd` altinda).
- Sahte sunucu icin `taskkill /IM python.exe` kullanildi (tum python surecleri kapandi).
- Kod degisikligi yok; yalniz rapor ve ekran goruntuleri eklendi.
