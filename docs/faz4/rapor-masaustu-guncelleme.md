# Masaüstü uygulama içi güncelleme: rapor

Çalışma yeri: `C:\Users\Arda\Desktop\Aktenak\Projeler\habit-tracker-guncelleme-calisma` (worktree, yerel dal `masaustu-guncelleme`, `mobil-senkron-v5` ucundan). Masaüstü master (`habit-tracker`) ve gerçek veri dokunulmadı. Hiçbir şey yayımlanmadı: push, etiket, release, GitHub isteği, imza anahtarı yok. İki yerel commit (`b4138e2`, `e0075fd`), mesajlarda Claude/Co-Authored-By yok.

## Yapılanlar

- **Çekirdek (`lib/data/update/`)**: `saf.dart` (sürüm karşılaştırma, GitHub izin listesi host+port+yol, `yayinCoz`, `ozetCoz`; zip adı `aktenak-habit-tracker-v<sürüm>-windows.zip`, sınır 200 MiB), `ag.dart` (elle yönlendirme izleme, boyut sınırı, `Iptal`), `guncelleyici.dart` (günde bir denetim, ETag, indir, SHA-256, zip aç, yalnız daha yüksek sürüm), `ayarlar.dart` (`update_check`, `update_record`), `paket.dart` (zip-slip/sıkıştırma bombası/özel girdi denetimi, zorunlu dosyalar), `uygula.dart` (uygulayıcı), `akis.dart` (enjekte edilebilir `Kurucu`, sağlayıcılar).
- **Kurulum modeli**: yeni sürümün kendi exe'si `--guncelle-uygula=1 --hedef --sonuc --pid` ile çalışır; eski `*.exe`, `*.dll`, `data/` öğelerini `.eski/` altına taşır, yenileri kopyalar, hata olursa geri alır; veri klasörüne ve küme dışı dosyalara dokunmaz. `main.dart` bu bayrağı veritabanı/tepsi açılmadan yakalar. Tepsideki Çıkış ile güncelleme aynı `TrayService.quit()` yolunu kullanır.
- **Arayüz**: Yedek & Ayarlar'da "Güncelleme" kartı (sürüm, son denetim, denetim anahtarı, Şimdi denetle, yeni sürüm + boyut, İndir ve doğrula, ilerleme, İptal, Kapat ve güncelle, Sonra, sürüm notları, hata için Türkçe metin + kod). İlk açılışta tek seferlik "denetleyeyim mi" penceresi; seçilene kadar ağ isteği yok. Düğmeler en az 48x48. Açılışta önceki güncellemenin sonucu snackbar ile bildirilir, `.eski` ve hazırlık klasörü temizlenir.
- `lib/surum.dart` (= pubspec 1.3.3, eşitlik testi var), `lib/core/sha256.dart` (mobille aynı saf SHA-256), `archive: 4.6.0` bağımlılığı eklendi.
- **Tasarımdan sapmalar**: (1) Eski sürecin kapanması `tasklist` ile PID yoklanarak beklenir; tasarımdaki "exe'yi yeniden adlandırmayı dene" yöntemi bırakıldı çünkü Windows çalışan exe'nin yeniden adlandırılmasına izin verir, yani bekleme sinyali olmaz. (2) Hazırlık klasörü `%APPDATA%\com.aktenak\aktenak_habit_tracker\guncelleme\` (veri klasörünün altı; tasarımda LOCALAPPDATA). (3) Veritabanı ayrıca kapatılmıyor; pencere konumu kaydedilip normal çıkış yapılıyor. (4) Yedek için mevcut `AutoBackup.runIfDue` (bugünün yedeği varsa yenisi alınmaz); yedek hata verirse kurulum başlamaz. (5) `adresUygun` sorgu dizisi hariç ham yolda `%2e/%2f/%5c` arar (mobildeki kopyada `Uri` normalleştirmesi yüzünden bu denetim etkisizdi; imzalı indirme adreslerinde sorguda meşru `%2F` olur).

## Denenenler (hepsi geçti)

- `flutter analyze`: temiz. Tüm testler dosya dosya (çökmede yeniden deneyerek) geçti; yeni testler `test/update/` altında: sürüm karşılaştırma ve pubspec eşitliği, host/port/yol izin listesi, boyut sınırı, SHA reddi, `ozet_bulunamadi`, fazla/eksik gövde, izinsiz yönlendirme, iptal, `surum_dusuk`, zip-slip, eksik zorunlu dosya, ilk onay yokken ağ isteği yok, günde bir denetim, 403 limit; uygulayıcı: başarı, kopyalama hatasında tam geri alma, süreç kapanmazsa `uygulama_mesgul`, argüman doğrulama, sonuç dosyası; `Kurucu` sırası (yedek, uygulayıcı, kapat) ve yedek hatasında durma; arayüz akışı sahte GitHub (yerel `HttpServer`) + sahte kurucu ile.
- `flutter build windows --release` derlendi; çıktıdaki dosyalar `paketZorunluDosyalar` ile eşleşti (`aktenak_habit_tracker.exe`, `flutter_windows.dll`, `data/app.so`, `data/icudtl.dat`). `Compress-Archive` ile üretilen gerçek zip 14,6 MB; girdi adları `\` ayırıcılı ve dizin girdili, `paketiAc` bunu geçici klasöre sorunsuz açtı (geçici deneme, dosya depoya girmedi).

## Denenmeyenler ve riskler

- **Gerçek kurucu hiç çalıştırılmadı** (kural gereği): `--guncelle-uygula` ile gerçek bir kurulum klasörünü değiştirme, tepsiden kapanma, yeni exe'nin yeniden açılması, başlangıç kaydı, SmartScreen, kilitli DLL davranışı sahte klasörlerle test edildi, gerçek Windows kurulumunda değil. Uygulayıcı penceresinin Flutter runner'da gerçekten açılıp bayrağı alması elle denenmedi.
- Gerçek GitHub'a hiç gidilmedi; `releases/latest` yanıtı ve yönlendirme zinciri yalnız sahte sunucuyla. `tool/` altında python sahte sunucu yazılmadı (testler Dart içi sunucu kullanıyor).
- **Sıkıştırma bombası sınırı kısmi**: `archive` açarken başlıktaki boyuta güveniyor; yalan başlık o dosya bitene kadar yazar (zip 200 MiB ve SHA-256 zaten daraltır). Kodda `shortcut` notu var.
- Açıldıktan sonra hazırlık klasörü yeniden özetlenmiyor; yalnız açmadan hemen önce zip yeniden özetleniyor.
- Ed25519 imzası yok (karar Arda'da, anahtar üretilmedi); kartta "imzalı değil, yalnız SHA-256" uyarısı görünür. GitHub hesabı ele geçirilirse SHA-256 yetmez.
- Çalışan odak sayacını ve (henüz bu dalda olmayan) Wi-Fi eşleştirme oturumunu tespit eden kod yok; yalnız metinle uyarılıyor.
- Geri alma yalnız dosya kopyalama aşaması için; yeni sürüm bir kez açılıp şemayı yükselttiyse eski sürüme dönüş yok (yedek bu yüzden alınır).
- Güncelleyiciyi taşıyan ilk sürüm kullanıcıya elle kurulur. `release.yml` değişmedi. `flutter test` Windows'ta yine rastgele çöküyor; yeniden denendi (bir kez `tasks_test.dart` yükleme çökmesi, yeniden çalışınca geçti).
- Windows kullanıcı hesabı denetimi ile korunan klasörlere (Program Files) kurulum desteklenmiyor; `klasor_yazilamaz` ile uyarılır.
