# Faz 4 mobil istemci raporu (QR + Wi-Fi senkron)

Durum: kod yerel dalda (`main`) iki commit olarak duruyor. Hiçbir şey yayımlanmadı: push, etiket, release, GitHub isteği, imza anahtarı yok. Masaüstü (`habit-tracker`) deposuna dokunulmadı.

## Yapılanlar

- `lib/platform/wifi/sozlesme.dart` (mobilin kendi dosyası): QR ayrıştırma (`habitsync://p?...`, uzunluk, çift anahtar, bilinmeyen anahtar, port aralığı, 43 karakter parmak izi, 32 hex jeton), özel IPv4 denetimi (10/8, 172.16/12, 192.168/16, 169.254/16), ad temizleme (bidi/kontrol karakterleri), hata kodları, sunucu yanıtı şema doğrulaması.
- `lib/platform/wifi/istemci.dart`: sistem güven deposu yok, sertifika yalnız DER SHA-256 parmak iziyle + QR'daki adres/port ile kabul; `DIRECT` vekil, yönlendirme hata, sınırlı gövde okuma, adresler sırayla (4 sn), oturum/GET/POST zaman aşımları, jeton ve oturum anahtarı yalnız bellekte, hatalarda yalnız kod (ham istisna yok).
- `lib/platform/wifi/onizle.dart`: kuru çalıştırma. Mevcut `importSyncBytes` bir transaction içinde çalışıp geri sarılır; özet sayıları gerçek birleştirme koduyla aynı.
- `lib/platform/wifi/qr_tarayici.dart`: `mobile_scanner` 7.5.0 (tam sürüme sabit) sarmalayıcısı; testler için sahte tarayıcı sağlayıcısı. İlk geçerli QR'da kamera durdurulur, sonra ağ isteği başlar.
- `lib/features/settings/wifi_eslestir_ekrani.dart`: giriş (açıklama, "QR'ı tara", "Bağlantıyı yapıştır"), kamera izni reddi ekranı (açıklama, Yeniden dene, Uygulama ayarlarını aç, yapıştırma açık), Onay 1 (bilgisayar adı + adresler; bu noktaya kadar ağ isteği yok), bağlanma, Onay 3 özeti (eklenecek/güncellenecek/silinecek, türe göre kırılım, silme uyarısı, 50 ve üstünde ek açıklama, silme varsa "Vazgeç" odakta), yerel yedek, birleştirme, telefonun tam durumunu gönderme, sonuç; masaüstü POST'u reddederse "Yarım kaldı: telefon güncellendi, bilgisayar değişmedi" açıkça yazılır. Özet ekranında uygulama arka plana giderse oturum kapatılır. Ayarlar'a "Bilgisayarla eşitle" girişi eklendi.
- Birleştirmeden önce `yedekler/aktenak-sync-<tarih>.json` yazılır; yedek alınamazsa birleştirme yapılmaz (`yedek_alinamadi`).
- Android: `CAMERA` izni ve `uses-feature camera required=false`; `Kopru.uygulamaAyarlariniAc` + `MainActivity.kt` kanalı (`ACTION_APPLICATION_DETAILS_SETTINGS`). `permission_handler` kullanılmadı. `usesCleartextTraffic=false` aynen duruyor.
- `esitle.ps1` ile kopyalanan dosyalara dokunulmadı; `uyum_test` geçiyor. Tasarımdaki paylaşılan `previewSyncBytes` yerine mobilde `onizle.dart` yazıldı (paylaşılan `sync_import.dart` kopya olduğu için). Masaüstü tarafı aynı dosyayı eklerse ikisi birleştirilebilir.
- Metinler Türkçe (`Metin.wifi*`), tüm düğmeler en az 48 dp, durum değişimleri `liveRegion`.

## Denenenler

- `flutter analyze`: temiz.
- `tool/test_calistir.ps1` ile tüm test dosyaları: geçti (41 dosya; yeni 4 dosya dahil). Motor çökmeleri ("did not complete") yalnız yeniden denendi, gerçek hata yeniden denenmedi.
- Yeni testler: `wifi_sozlesme_test` (QR geçerli/geçersiz vektörleri, özel/genel IP, yanıt şemaları, hata metinleri, manifest izinleri), `wifi_onizle_test` (önizleme veriyi değiştirmez, rapor gerçek birleştirmeyle aynı), `wifi_istemci_test`, `wifi_eslestir_ekrani_test` (tam akış, Vazgeç, reddedilme, yarım kalma, bozuk veri, geçersiz bağlantı, Wi-Fi yok, kamera izni reddi, 48 dp / etiket / kontrast açık+koyu tema, %200 yazı).

## Denenmeyenler ve riskler

- **Sertifika parmak izinin kabul edildiği (olumlu) yol hiç denenmedi.** Gerçek TLS sunucusuyla istemci testi için test sertifikası (`.pem`) üretmeye çalıştım; komut güvenlik kancası tarafından engellendi ("secret.ext.pem") ve yeniden denemedim, alternatif yol aramadım. Bu yüzden `wifi_istemci_test` yalnız şunları kapsıyor: özel olmayan adrese bağlanılmaması, kapalı port, TLS konuşmayan sunucu, sessiz sunucu zaman aşımı. Doğru/yanlış parmak izi, gerçek `session`/`state` yanıtları, gövde sınırları, yönlendirme reddi **ağ düzeyinde test edilmedi**; arayüz testleri sahte istemci kullanıyor.
- Tasarımdaki 10 senaryolu masaüstü sunucusuyla uçtan uca test (`tool/e2e/wifi_e2e.*`) yazılmadı (masaüstü sunucusu bu görevin dışında).
- **Android derlemesi doğrulanamadı.** `flutter build apk --debug` bu makinede `C:\Android\Sdk\ndk\28.2.13676358` boş olduğu için (yalnız `source.properties`, `llvm-strip` yok) strip aşamasında çöktü. NDK'yı yeniden kurmadım. Bu nedenle `mobile_scanner` 7.5.0'ın minSdk/AGP/KGP uyumu, manifest birleştirmesi ve Kotlin kanalı derlenerek sınanmadı.
- Gerçek kamera, gerçek izin penceresi, emülatör/telefon, TalkBack, gerçek LAN ve Windows güvenlik duvarı denenmedi. Sertifikanın Android'de kabulü (tasarımdaki kapı koşulu) denenmedi.
- İstemci cihaz adı sabit "Android telefon" (cihaz modeli okunmuyor); masaüstü onayında bu ad görünür.
- `Stream.timeout` yanıt gövdesinde olay başına işler, toplam süre değil; sunucu tarafı toplam sınırı masaüstünde.
- `ACCESS_LOCAL_NETWORK` eklenmedi (targetSdk 37'ye çıkınca gerekir, tasarımdaki gibi).
- Dikkat: oturum başında yanlışlıkla tüm `lib` klasörüne `dart format` çalıştırdım; paylaşılan dosyalar dahil biçimlendi. Değişikliği geri aldım (diff yedeği alınıp ters uygulandı), `git diff` boş ve `uyum_test` geçiyor; yine de `git status` bazı dosyaları satır sonu nedeniyle değişmiş gösterebilir (içerik aynı).
