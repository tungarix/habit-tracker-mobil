# Rapor: masaüstü QR + Wi-Fi senkron sunucusu

Worktree: `habit-tracker-v5-calisma`, dal `mobil-senkron-v5` (yerel commit'ler; push/etiket/release/GitHub isteği yok, imza anahtarı üretilmedi, `habit-tracker` master'ına ve stash'e dokunulmadı).

## Yapılanlar

- `lib/core/sha256.dart`: mobildeki saf SHA-256'nın kopyası (sertifika parmak izi için; yeni paket yok).
- `lib/core/wifi_sync/sozlesme.dart`: sabitler (A3 tablosu), hata kodları (enum + HTTP), QR kodlama/ayrıştırma (çift anahtar, genel IP, 44 karakterli parmak izi, uzunluk, bidi ad temizleme), özel IPv4 denetimi, sabit zamanlı karşılaştırma.
- `lib/core/wifi_sync/sertifika.dart`: oturum başına bellekte ECDSA P-256 kendinden imzalı sertifika (`Isolate.run`), parmak izi, anahtar diske yazılmaz. `basic_utils` yalnız burada.
- `lib/core/wifi_sync/ag_adresleri.dart`: yalnız özel IPv4 adayları (en çok 3).
- `lib/core/wifi_sync/sunucu.dart`: `EslestirmeSunucusu` (HttpServer.bindSecure + durum makinesi): tek kullanımlık jeton, IP'ye bağlı oturum anahtarı, 4 uç nokta, Onay 2 ve Onay 4, kuru çalıştırma özeti, birleştirmeden önce yedek (yedek düşerse birleştirme yok), IP başına 5 / toplam 50 hata, istek sayısı, eşzamanlı sınır, gövde süresi, QR ömrü ve oturum üst süresi, `isleniyor` iken İptal'in yok sayılması, hata gövdesi yalnız `{"error":kod}`.
- `lib/data/sync/sync_import.dart`: `previewSyncBytes` (geri sarılan işlemde aynı birleştirme).
- `lib/features/eslestir/`: `eslestir_dialog.dart` (QR, geri sayım, kopyalanabilir bağlantı, yardım metni, Onay 2/Onay 4 ekranları, sonuç, İptal; düğmeler 48 dp, canlı bölge), `qr_cizici.dart` (`qr` paketi, sabit siyah-beyaz, sessiz bölge, Semantics etiketi).
- `lib/features/backup/backup_screen.dart`: yalnız bir import ve bir "Telefonla eşleştir (Wi-Fi)" kartı eklendi (güncelleyici ajanıyla birleşme kolay olsun diye başka düzenleme yok).
- `pubspec.yaml`: `qr 4.0.1`, `basic_utils 5.8.2` (tam sürüm). `docs/wifi-senkron.md` (takipsizdi) commit'lendi, `ic_hata` satırı eklendi.
- Birleştirme öncesi yedek: `<veri klasörü>\yedekler\aktenak-sync-<tarih>.json` (otomatik yedek budaması bu öneki silmez, birikir).

## Tasarımdan sapmalar

1. Dosyalar `lib/data/sync/wifi/` yerine `lib/core/wifi_sync/` altında (görev böyle istedi; `sync_purity_test` `lib/data/sync` içinde `dart:io` yasaklıyor).
2. 17. hata kodu `500 ic_hata` (yedek alınamadı / birleştirme düştü). Tasarımda 16 kod vardı; telefon istemcisi de bunu bilmeli. Belge tablosu güncellendi.
3. Gövdesi okunmamış hata yanıtlarında (413, 411, 408...) Dart yanıtı gövde bitene kadar tuttuğu için bağlantı devralınıp yanıt elle yazılır ve kapatılır.
4. `basic_utils` SAN'ı iPAddress değil metin (dNSName) yazıyor. İstemci parmak iziyle sabitlediği için ana makine adı denetlenmez; sorun değil ama telefon istemcisi ana makine adını doğrulamamalı.
5. Drift, geri sarılan önizleme işleminden sonra `watch()` akışlarını aynı veriyle yeniden yayar (önizleme verisi hiçbir izleyiciye görünmez; test bunu doğruluyor).

## Denenenler (otomatik testler, hepsi 127.0.0.1)

- `wifi_sozlesme_test` (10): QR gidiş-dönüş ve 22 geçersiz örnek, IP aralıkları, hata kodu ve sabit tablosu belgeyle aynı, sertifika (43 karakter, her oturumda farklı).
- `wifi_sunucu_test` (29): tam akış + sızıntı taraması (jeton, oturum anahtarı, parmak izi çıktıda yok), jeton tek kullanım, 401, IP engeli, yanlış parmak izi (HandshakeException), QR/oturum süresi, 411/413/415/408, onay ret/zaman aşımı/iptal, `mesgul`, bozuk dosya sonrası devam, `senkron_surumu`, yedek hatası, `isleniyor` iken iptal, `/v1/end`, GET sınırı, `kapat()`, üretimde loopback reddi.
- `sync_onizle_test` (2): önizleme veriyi ve silinenler izini değiştirmez, rapor gerçek içe aktarmayla aynı.
- `wifi_eslestir_dialog_test` (4): gerçek sunucu + pinleyen istemciyle pencere akışı, yedek dosyası, 48 dp, Semantics, İptal, Hayır, özel ağ yok.
- `flutter analyze`: temiz. Tüm masaüstü testleri: 27 dosyanın 27si geçti (motor çökmesi "did not complete" yalnız yeniden denendi; iki ayrı tam koşuda da gerçek test hatası yok).

## Denenmedi

- Gerçek LAN IP'si, Windows Güvenlik Duvarı istemi/engeli, gerçek telefon/Android sertifika kabulü, kamera, TalkBack.
- Yarı açık TLS bağlantısı yığma ölçümü (tasarımdaki "bilinen sınır") ve `Expect: 100-continue`.
- Eşzamanlı istek sınırı (429) ve toplam 50 hata sınırı (tek IP ile test edilemedi).
- Büyük gerçek veride önizleme süresi (ana isolate'te çalışır).
- Gerçek `%APPDATA%` verisi hiç kullanılmadı; testler bellek içi/geçici DB kullanır.
- Mobil istemci bu işin kapsamında değil.

Arda'ya not: testten kalan, güvenlik hook'u silmeme izin vermediği için scratchpad'de atılabilir tek bir geçici `c.pem` (kendinden imzalı test sertifikası) var.
