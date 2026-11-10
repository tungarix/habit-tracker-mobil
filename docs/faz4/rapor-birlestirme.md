# Faz 4 birleştirme ve uçtan uca doğrulama raporu

Hiçbir şey yayımlanmadı: push, uzak depo, etiket, release, GitHub isteği, imza anahtarı yok. `habit-tracker` (masaüstü master, `2a445df`) ve gerçek `%APPDATA%` verisi dokunulmadı; masaüstü testleri ve e2e geçici SQLite dosyalarıyla çalıştı. Commit mesajlarında Claude/Co-Authored-By yok.

## Yapılanlar

- **Birleştirme** (`habit-tracker-v5-calisma`, dal `mobil-senkron-v5`): `masaustu-guncelleme` yerel olarak birleştirildi, commit `6b35913`. Üç çakışma vardı, üçü de "iki tarafı da koru" ile çözüldü:
  - `lib/features/backup/backup_screen.dart`: iki import da duruyor (`eslestir_dialog`, `guncelleme_bolumu`). Ayarlar ekranında hem "Telefonla eşleştir (Wi-Fi)" + .habitsync kartları hem "Güncelleme" bölümü var.
  - `pubspec.yaml`: `qr 4.0.1`, `basic_utils 5.8.2` ve `archive 4.6.0` üçü de var.
  - `pubspec.lock`: `archive` artık `direct main` (diğer taraf `transitive` idi).
- `masaustu-guncelleme` dalı, worktree'si (`habit-tracker-guncelleme-calisma`) ve `mobil-senkron-v5` worktree'si silinmedi/kaldırılmadı; karar Arda'da. `masaustu-guncelleme` worktree'sindeki işlenmemiş `generated_plugin*` değişikliklerine dokunulmadı.
- **Yeni e2e düzeneği** (uçtan uca için):
  - Masaüstü: `tool/e2e/wifi_kontrol_sunucu_test.dart` (v5 worktree'sinde, yerel commit `374a33a`). GERÇEK `EslestirmeSunucusu`'nu geçici SQLite ile 127.0.0.1'de açar, mobil testin yönetmesi için düz HTTP kontrol arayüzü sunar.
  - Mobil: `tool/e2e/wifi_e2e_test.dart` (6 senaryo) ve `tool/e2e/wifi_calistir.ps1` (masaüstü kontrol sürecini başlatır, mobil testi koşar, yalnız kendi PID'sini `taskkill /PID` ile kapatır, motor çökmesinde yeniden dener).
- Emülatör ekran görüntüleri: `docs/faz4/ekran/`.

## Geçenler

| Ne | Sonuç |
|---|---|
| Masaüstü `flutter analyze` (birleşik dal) | temiz |
| Masaüstü tüm testler (32 dosya, dosya dosya) | hepsi geçti; motor çökmesi nedeniyle `dashboard_layout_test` 4., `sync_test` 2. denemede (gerçek hata yok) |
| Mobil `flutter analyze` | temiz |
| Mobil tüm testler (41 dosya, `uyum_test` dahil = esitle uyumu) | hepsi geçti. Not: 4 dosya (`tasks`, `uyum`, `widget_servisi`, `widget`) ilk koşuda `build\native_assets\windows\sqlite3.dll` silinemedi hatasıyla düştü; sebep benim aynı anda ikinci bir flutter süreci (e2e) çalıştırmamdı, test hatası değil. Tek başına yeniden koşunca 4'ü de ilk denemede geçti. |
| Mobil `tool/e2e/calistir.ps1` (.habitsync e2e, ölçek testi dahil) | geçti |
| `tool/e2e/wifi_calistir.ps1` (aşağıda) | 6/6 geçti |

### Masaüstü sunucu <-> mobil istemci (gerçek TLS, 127.0.0.1, Dart VM)

1. **Sözleşme uyumu**: masaüstünün `kodla()` çıktısı, adres 10.0.2.2 yapılınca mobilin `qrCoz`'ünde aynı alanlarla çözülüyor; 127.0.0.1 mobilde reddediliyor (özel IP kuralı).
2. **İki yönlü eşitleme**: telefon yeni alışkanlık ekler, masaüstü yeni ekler: iki tarafta birleşim. Telefon adı değiştirir (daha yeni damga) ve masaüstü yeni ekler: ikisi iki tarafa yayılır. Telefon bir, masaüstü bir kaydı siler: ikisi de iki tarafta silinmiş, iki tarafta da silinen izi var. Sonraki eşitleme 0/0/0 (idempotent). Masaüstü her birleştirmeden önce yedek aldı (yedek sayısı 1).
3. **Yanlış parmak izi** reddedilir: `parmak_izi_uyusmadi`; sunucu hiç HTTP isteği görmedi (durum `bekliyor`), jeton yanmadı (ardından doğru parmak izi çalıştı).
4. **Süresi dolmuş jeton** (QR ömrü 2 sn): sunucu `sureDoldu` oldu ve kapandı, istemci `ag_ulasilamiyor` aldı (yani sunucu artık dinlemiyor; ayrı bir "jeton süresi doldu" kodu görmüyor).
5. **İkinci kez kullanılan jeton**: oturum açıkken ikinci istemci `yetkisiz` (401) aldı, ilk oturum etkilenmeden tamamlandı; oturum bittikten sonra üçüncü deneme `ag_ulasilamiyor` (sunucu kapalı).
6. **Masaüstü "bu telefon değil" derse**: `reddedildi`.

İlk e2e denemesinde masaüstü test motoru çalışırken çöktü (Windows'taki bilinen rastgele flutter_tester çökmesi); betik bunu tanımıyordu, `HasExited` kontrolü eklendi. Sonraki tam koşu ilk denemede geçti.

### Android emülatörü (AVD Telefon35, debug APK, x64)

APK `HABIT_YEREL_NDKSIZ=1 flutter build apk --debug --target-platform android-x64` ile güncel koddan yeniden derlendi ve kuruldu.

- **QR ekranına kadar**: Bugün > menü > Ayarlar > "Bilgisayarla eşitle" > ekranda "QR'ı tara" ve "Bağlantıyı yapıştır": DOĞRULANDI (`ekran/eslestir-giris.png`).
- **Kamera izni, reddetme yolu**: "QR'ı tara" Android'in kamera izin penceresini açtı; "Don't allow" sonrası uygulama "Kamera izni verilmedi" ekranını gösterdi (Yeniden dene, Uygulama ayarlarını aç, Bağlantıyı yapıştır) (`ekran/kamera-izni-reddedildi.png`): DOĞRULANDI.
- **Android BoringSSL sertifikayı kabul ediyor mu: EVET (bu emülatörde).** Masaüstü gerçek sunucusu 127.0.0.1'de çalışırken emülatör `10.0.2.2` üzerinden bağlandı. Bağlantı yapıştırıldı (adb ile yazıldı), Onay 1 "«E2E-PC» · 10.0.2.2" çıktı, "Bağlan" sonrası sunucu "Bağlantı geldi, onay bekleniyor / Bağlantı onaylandı" kaydetti (yani kendinden imzalı ECDSA P-256 sertifika, parmak izi sabitlemesiyle TLS el sıkışmasını geçti), telefon Onay 3 özetini ("1 eklenecek") gösterdi, "Birleştir ve gönder" sonrası sunucu "Telefondan veri geldi / Birleştirildi / Oturum bitti: tamam" kaydetti, telefon "Eşitleme tamamlandı: Telefon 1 eklendi; Bilgisayar 172 eklendi" yazdı. Masaüstü DB'sine telefonun 5 alışkanlığı geçti, yedek alındı (`ekran/onay1-10.0.2.2.png`, `onay3-ozet.png`, `esitleme-tamam.png`).
- Emülatörün uygulama verisine uydurma "Masaustu Emulator" alışkanlığı eklendi (veri zaten uydurmaydı).

## Doğrulanmayanlar

- **Kamerayla gerçek QR okuma** denenmedi (emülatörün sanal kamerasına QR gösterilmedi); bağlantı elle yapıştırıldı. Kamera izninin VERİLDİĞİ yol da denenmedi (izni vermedim); `mobile_scanner`'ın Android'de gerçekten kare yakalaması doğrulanmadı. "Uygulama ayarlarını aç" düğmesine basılmadı.
- **Gerçek LAN, Windows Güvenlik Duvarı, gerçek telefon**: denenmedi. Emülatör denemesinde sunucu loopback'e bağlıydı (testte `loopbackIzinli`; emülatör bağlantısı sunucuya 127.0.0.1 kaynağıyla görünür) ve QR'daki adres 10.0.2.2 olarak elle yazıldı. Üretimde sunucu yalnız özel arayüz adreslerine bağlanır; bu yol Windows'ta güvenlik duvarı izni isteyebilir, bu denenmedi.
- Sertifika kabulü yalnız bu emülatör imajında (API düzeyi başka sürümlerle karşılaştırılmadı) ve yalnız debug derlemede görüldü; release derlemesi ve diğer Android sürümleri denenmedi.
- Onay 4 reddi, 429 / toplam hata sınırı, büyük veri süresi, yarı açık bağlantı yığma: e2e'de denenmedi (masaüstü birim testleri bir kısmını kapsıyor, rapor-masaustu-sunucu.md).
- **Birleşik Ayarlar ekranı** masaüstünde elle (GUI'de) açılıp görsel olarak bakılmadı; birleşik dalın analyze'ı ve tüm testleri geçti (`settings_screen_test`, `sync_ui_test`, `guncelleme_bolumu_test` dahil) ama iki bölümü aynı ekranda birlikte çizen ayrı bir test yok.
- Güncelleyicinin gerçek kurucusu, Android "bilinmeyen uygulama kurma" izni ve SHA/kurulum akışı (önceki raporlardaki açık maddeler) bu turda da denenmedi; imza (Ed25519) yok.
- Mobil klasör git deposu değil: mobil dosya değişiklikleri sürüm kontrolünde izlenmiyor.

## Kalan karar/iş (Arda)

- `mobil-senkron-v5` (birleşik, 2 yeni commit) ve `masaustu-guncelleme` dallarının akıbeti; worktree'lerin kaldırılması.
- Gerçek telefonla kamera taraması + gerçek Wi-Fi'da ilk deneme, sonra yayımlama kararı.
