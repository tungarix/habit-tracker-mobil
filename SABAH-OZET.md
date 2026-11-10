# Sabah özeti (10 Kasım 2026)

Bu dosya gece işinin bağımsız son doğrulamasından sonra yazıldı. Önceki raporlar doğru kabul edilmedi; aşağıdaki "çalıştırıldı" ibareleri bu turda gerçekten koşulan komutlardır. Ayrıntı: `docs/gece-raporu/10-son-dogrulama.md`.

## a) Bu gece ne yapıldı

> Karar turu (10 Kasım, sonra): Kararlar kapandı ve uygulandı. `mobil-senkron-v5` yerel `master`'a fast-forward birleşti (`masaustu-guncelleme` zaten içindeydi); masaüstü v1.4.0 HAZIRLIĞI commitlendi (pubspec 1.4.0+9, CHANGELOG, README, belgeler; etiket YOK); güncelleme paketi Ed25519 imzasıyla doğrulanıyor; kamera izni kalıcı karar. Mobil `tool/kaynak_ozet.json` v1.4.0 hazırlık commit'ine çekildi. Ayrıntı: `docs/faz4/rapor-karar-uygulama.md`. Hâlâ hiçbir şey yayımlanmadı: push, uzak depo, etiket, release yok.

> Güncelleme (Faz 4 turu): QR + Wi-Fi eşleştirme (mobil istemci + masaüstü sunucu) ve masaüstü uygulama içi güncelleyici yazıldı, birleştirildi ve bağımsız incelemeden geçirildi. Aşağıdaki Faz 4 satırları, deneme listesi, yayın sırası ve sınırlar buna göre güncellendi. Ayrıntı: `docs/faz4/` (özellikle `inceleme.md`). Hâlâ hiçbir şey yayımlanmadı, push/etiket/release/imza anahtarı yok; gerçek telefonda ve gerçek Wi-Fi'da denenmedi.

Mobil uygulama iskeletinden başlayıp masaüstündeki tüm özellikleri (Bugün, Görevler, Aylık, İstatistik, odak sayacı, mood, yedek) Flutter ile taşıdı; Android'e özgü widget, bildirim, odak alarmı ve uygulama içi güncelleme eklendi; masaüstü tarafında şema v5 (uid, updatedAt, silinenler) ve `.habitsync` dosya senkronu yazıldı (yerel, yayımlanmamış dal). İki tur düzeltme, bir güvenlik taslağı, veri bütünlüğü denemesi ve iki emülatör turu yapıldı. Hiçbir şey yayımlanmadı, push edilmedi, imza anahtarı üretilmedi. Sürüm 0.0.1+1; mobil repoda remote ve etiket yok. Gerçek telefonda hiçbir şey denenmedi.

## b) Kod durumu

| Faz | Durum | Doğrulama düzeyi |
|---|---|---|
| 0 İskelet, esitle, uyum testi, CI dosyaları | Var | Birim testi (uyum_test geçti); CI GitHub'da hiç çalışmadı |
| 1 Çekirdek ekranlar, yedek içe/dışa aktarma | Var | Emülatörde (sahte veriyle) + birim testi |
| 2 Widget | Var | Emülatörde: widget'tan işaret uygulamaya yansıdı. Uygulama öndeyken anlık yansıma denenmedi |
| 2 Akşam hatırlatıcısı | Var | Emülatörde yalnız alarm kaydı (dumpsys); bildirimin gelmesi ve "tamamsa gelmez" denenmedi |
| 2 Odak sayacı | Var | Emülatörde tam zamanlı alarm kaydı; ekran kapalıyken çalma denenmedi |
| 2 Uygulama içi güncelleme | Var | Emülatörde arayüz ve ilk onay; indirme, SHA doğrulaması, kurulum, kötü SHA reddi denenmedi (yalnız birim testi) |
| 2 Güvenlik incelemesi | Taslak | `Sonuç:` boş, düşük bulgular açık; Arda dolduracak |
| 3 Masaüstü şema v5 + `.habitsync` | Var, masaüstü yerel `master` (yayımlanmadı) | Birim testi + e2e (mobil/masaüstü senkron kodu, geçici DB) + gerçek verinin kopyasında migration; `.habitsync` içe aktarma emülatörde (VIEW intent) |
| 4 Wi-Fi eşleştirme, mobil istemci | Var, mobil `main` | Birim/widget testi; masaüstü sunucusuyla gerçek TLS e2e (127.0.0.1, 6 senaryo); emülatörde 10.0.2.2 üzerinden tam akış (QR yerine bağlantı yapıştırılarak) |
| 4 Wi-Fi eşleştirme, masaüstü sunucu + "Telefonla eşleştir" penceresi | Var, masaüstü yerel `master` (yayımlanmadı) | Birim testi (gerçek HttpServer, loopback) + e2e; inceleme bulguları düzeltildi |
| 4 Masaüstü uygulama içi güncelleyici | Var, aynı `master`'da (`masaustu-guncelleme` birleşik) | Birim testi (sahte GitHub, sahte kurucu); gerçek kurucu, gerçek GitHub, gerçek kurulum denenmedi; `SHA256SUMS.txt` Ed25519 imzası doğrulanır (birim testi; gerçek anahtarla imzalama betiği denendi, CI'da hiç koşmadı) |
| Yayın (imzalı APK, CI release) | Yok | Hiç denenmedi |

Bu turda koşulanlar (ilk gece turu): `flutter pub get` tamam; `flutter analyze` temiz (tek uyarı, kullanılmayan import, sonradan giderildi); mobilde 37 test dosyasının tamamı geçti (4 dosya motor çökmesi sonrası yeniden denemede); `tool/e2e/calistir.ps1` 15 senaryo geçti; masaüstü v5 çalışma kopyasında 23 test dosyası geçti; `flutter build apk --release --target-platform android-arm64` başarılı (180 MB, NDK'sız, yerel).

Faz 4 inceleme turu (bu güncelleme): iki depoda `flutter analyze` temiz; mobilde 42, masaüstü v5 dalında 33 test dosyası dosya dosya koşuldu ve geçti. Mobilde tam koşuda iki dosya düştü: `uyum_test` (`database.dart` değişti, `tool/kaynak_ozet.json` karması güncellendi) ve `auto_yedek_yasam_dongusu_test` (iki flutter sürecini aynı anda koştuğum için `.tmp` dosyası/silme kilidi zamanlaması; test tek başına koşunca geçti, kod değişikliğiyle ilgisi yok). E2E betikleri (`tool/e2e/*`) bu turda yeniden koşulmadı. Bu bölümün üstündeki gece-turu satırı eski, bu satır güncel.

## c) Senin telefonunda denenecekler

Ön koşul: yayın imzalı APK. Yerel debug APK'yı telefona kurma (imza farkı, veri kaybı).

1. Kurulum: taslak release APK'sını indir, kur. Simge ve ad "Habit Tracker". Açılışta Bugün ekranı gelir.
2. Yedek aktarımı: masaüstünden JSON yedeği al, telefona gönder, Ayarlar > İçe aktar > Birleştir. Alışkanlık/kayıt sayıları, seriler ve Aylık tablo masaüstüyle aynı mı bak.
3. Gün dönümü: saat 03:59 ile 04:05 arasında bir alışkanlık işaretle; 04:00'dan önce önceki güne yazılmalı.
4. Bildirim: akşam hatırlatıcısını birkaç dakika sonrasına kur, izni ver, bildirimin geldiğini gör. Sonra tüm alışkanlıkları işaretle; bugünkü bildirimin gelmediğini doğrula.
5. Ekran kapalıyken sayaç: 25 dakikalık odak başlat, ekranı kapat, telefonu bırak; bitişte bildirim zamanında geliyor mu. Pil tasarrufu açıkken de dene.
6. Widget: ana ekrana ekle, dokunarak işaretle; uygulama açıkken ve kapalıyken yansıma.
7. TalkBack: Bugün listesi her alışkanlığın durumunu okuyor mu; Aylık hücreleri "Kitap, 12 Kasım: yapıldı" biçiminde okunuyor mu. Yazı boyutunu %130 ve %200 yap, taşma var mı bak.
8. Güncelleme: sonraki bir sürümü Ayarlar > Güncelleme > Şimdi denetle ile bul, "Bilinmeyen uygulama kurma" iznini ver, indir ve kur; veri korunuyor mu. Kötü SHA durumunu sahte sunucuyla dene (`tool/e2e/guncelleme_sahte_github.py`).
9. `.habitsync`: masaüstünden `.habitsync` dosyası üret, telefona gönder, dosyaya dokun; onay ekranındaki sayılar doğru mu, içe aktar. Telefonda değiştir, geri dışa aktar, masaüstünde içe aktar (iki yön, silme dahil).
10. Yeniden başlatma: telefonu yeniden başlat; hatırlatıcı ve çalışan sayaç alarmları yeniden kuruluyor mu. Uygulamayı güncelledikten sonra da aynısı.
11. Wi-Fi eşleştirme (ön koşul: masaüstü v1.4.0 ya da `mobil-senkron-v5` derlemesi, aynı Wi-Fi): bilgisayarda Ayarlar > "Telefonla eşleştir (Wi-Fi)" aç, QR çıksın. Telefonda Ayarlar > "Bilgisayarla eşitle" > "QR'ı tara": kamera izni iste, ver, QR'ı okut (gerçek kamera ile okuma hiç denenmedi). Sırayla: telefonda "bu bilgisayar mı" onayı, bilgisayarda "bu telefon mu" onayı, telefonda özet, "Birleştir ve gönder", bilgisayarda veri onayı, iki yanda "tamamlandı" ve sayılar. Ayrıca dene: Windows Güvenlik Duvarı sorusu çıkıyor mu ve izin verince bağlanıyor mu; kamera izni reddi sonrası "Bağlantıyı yapıştır"; Wi-Fi'ı "ücretli" işaretleyip aynı akış (Kotlin `wifiBagli` hiç çalıştırılmadı); mobil veriyle denenince "Önce Wi-Fi'a bağlan" mesajı; QR'ı 3 dakika beklet (süre dolsun); bilgisayardaki İptal ve "reddet" yolları; birleştirme sırasında Wi-Fi'ı kapat (telefon "sonucu belli değil" göstermeli, bilgisayardaki pencereye bakıp doğrula). Sonra telefonda ve bilgisayarda birer değişiklik yapıp tekrar eşleştir, silme dahil iki yönü kontrol et; bilgisayarda yalnız sıralama değiştirip eşleştirdiğinde telefondaki yeniden adlandırma kaybolmamalı.
12. Masaüstü uygulama içi güncelleme (bilgisayarında): v1.4.0'ı elle kur; sonraki bir sürüm yayımlanınca Ayarlar > Güncelleme > "Şimdi denetle", "İndir ve doğrula", "Kapat ve güncelle". Veri korunuyor mu, yeni sürüm açılıyor mu, antivirüs/SmartScreen engellerse kartta Türkçe hata çıkıp uygulama açık kalıyor mu. Gerçek kurucu hiç koşulmadı; ilk deneme yedeği alınmış temiz bir kurulumda yapılmalı. Program Files altındaki kurulumda "klasöre yazılamıyor" mesajı beklenir.

## d) Kararlar

Kapandı (Arda kararı, uygulandı):
- **Dal:** `mobil-senkron-v5` yerel `master`'a birleştirildi (fast-forward, tarih düz). Dal ve worktree'ler (`habit-tracker-v5-calisma`, `habit-tracker-guncelleme-calisma`) SİLİNMEDİ; `habit-tracker` ana klasörü `master`'da.
- **Paket imzası:** Ed25519 (gömülü açık anahtar). İmzasız ya da bozuk imzalı sürüm kurulmaz. Özel anahtar repo dışında; `docs/guncelleme-imzasi.md` (masaüstü repo).
- **Kamera:** `CAMERA` izni kalıcı karar (`PLAN.md`, Kararlar tablosu): yalnız "QR'ı tara"ya basınca istenir, `uses-feature camera required=false`, görüntü kaydedilmez/gönderilmez, izin reddinde "Bağlantıyı yapıştır" yolu. README'de "Gizlilik ve izinler" bölümü.
- **Masaüstü sürümü:** 1.4.0. Hazırlık commit'i `master`'da; etiket ve yayın Arda'nın.
- **Kaynak etiketi:** `kaynak_ozet.json` şimdi `v1.4.0 (etiketlenecek)` + hazırlık commit SHA'sı. Etiket atılana dek mobil CI'nın "Kaynak etiketi" checkout adımı kırmızı olur (`v1.4.0` yok); Arda etiketi AYNI commit'e atınca yeşile döner. Yerelde simüle edildi: bekçi o commit'e karşı temiz geçti.

Hâlâ açık (karar verilmedi, ben kapatmadım):
- Uygulama adı: şu an "Habit Tracker". Kimlikler (`com.aktenak.habit_tracker`) sabit.
- Plan dışı izinler: `FOREGROUND_SERVICE`, `WAKE_LOCK`, `VIBRATE` birleşik manifestte var (bağımlılıklardan). Kaldırılsın mı?
- Mobil repo adı ve açılışı: `tungarix/habit-tracker-mobil`, public, MIT; açılış zamanı sende.
- Boyut: yerel APK 180 MB; güncelleyicinin varsayılan indirme sınırı 150 MB. İlk CI çıktısında kontrol et.
- Güvenlik incelemesinin `Sonuç:` satırı (`guvenlik/incelemeler/v0.1.0.md`).

## e) Yayın sırası (hiçbiri yapılmadı; push, etiket, release, secret ben yapmam)

Arda'nın yapacakları:
1. **Özel anahtarın ikinci yedeği.** `C:\Users\Arda\Documents\HabitTracker-anahtar\guncelleme-ozel-anahtar.b64` dosyasını bu diskten ve repolardan bağımsız bir yere kopyala (şifreli USB ya da parola yöneticisi notu). Kaybolursa güncelleme zinciri kopar.
2. **GitHub secret `HABIT_UPDATE_SIGNING_KEY`.** Masaüstü repoda (`tungarix/habit-tracker`) Settings > Secrets and variables > Actions; değer o dosyanın içeriği. Sır yoksa `release.yml` imza adımında düşer, release oluşmaz.
3. **Etiket.** Önce masaüstü `master`'ı push et, sonra `v1.4.0` etiketini `kaynak_ozet.json`'daki `kaynak_commit` ile AYNI commit'e at. Etiketten önce masaüstüne yeni commit girerse (özellikle `lib/core`, `lib/data`, `test`, `docs/senkron.md`) `tool/esitle.ps1 -Etiket v1.4.0` yeniden çalıştırılmalı. Release iş akışı zip + `SHA256SUMS.txt` + `.sig` üretir; taslak release'i kontrol et.
4. **Telefon denemesi** (yukarıdaki c listesi; özellikle 11 ve 12: gerçek kamerayla QR, Wi-Fi, Güvenlik Duvarı sorusu, uygulama içi güncelleme).
5. Masaüstü release'ini yayımla. Sonra mobilde `tool/esitle.ps1` (parametresiz) çalıştır, `etiketle_ayni: true` gör; mobil repoyu aç, CI ilk koşu (kaynak etiketi adımı bu noktada yeşile döner).
6. Mobil güvenlik incelemesi (`Sonuç:` satırı), mobil etiket, taslak release (imzalı APK yalnız CI'dan), yayımla.

## f) Bilinen sınırlar

- Gerçek cihazda hiçbir şey denenmedi; emülatör de yalnız Android 15 (API 35), Telefon35. Android 12 ve farklı ekranlar denenmedi.
- Güncelleme kurulumu, SHA reddi, bildirimin gelmesi, ekran kapalıyken sayaç, yeniden başlatma sonrası alarmlar denenmedi.
- `release.yml` ve CI GitHub'da hiç çalışmadı.
- Faz 4 gerçek ağda ve gerçek cihazda hiç denenmedi: yalnız loopback testleri ve emülatörde 10.0.2.2 üzerinden bir akış. Kamerayla gerçek QR okuma, Windows Güvenlik Duvarı sorusu, gerçek telefon ve gerçek Wi-Fi yok. Sertifika kabulü yalnız bir emülatör imajında ve debug derlemede görüldü.
- Kotlin `wifiBagli` (ücretli Wi-Fi düzeltmesi) derlenip çalıştırılmadı; yalnız Dart tarafı sahte köprüyle test edildi. VPN üzerinden Wi-Fi'da yanlış "Wi-Fi değil" çıkabilir (denenmedi).
- Masaüstü sunucu portu artık 49152-65535 arasından seçiliyor (Linux için); Linux'ta denenmedi. Güncelleme bölümü Windows dışında gizli.
- Masaüstü güncelleyicisi: gerçek kurucu, gerçek GitHub, SmartScreen/antivirüs davranışı denenmedi; paket imzası Ed25519 ile doğrulanır (gerçek GitHub/CI'da denenmedi); geri alma yalnız dosya kopyalama aşaması için.
- Eşleştirmede telefon sonuç yanıtını alamazsa "bilgisayarın sonucu belli değil" der; kullanıcı bilgisayardaki pencereye bakmalı. Birleştirme tekrarlanabilir (veri bozulmaz).
- Veritabanı tetikleyicisi değeri değişmeyen UPDATE'i de düzenleme sayıyor; sıralama düzeltildi ama başka toplu yazma eklenirse aynı sorun doğar (`inceleme.md`, bulgu 4).
- Mobil klasör artık git deposu (yerel `main`, uzak depo yok); `docs/faz4/ekran/` ve bazı raporlar önceki turdan işlenmemiş duruyor.
- Yerel release APK NDK'sız ve 180 MB; yayın APK'sı yalnız CI'dan çıkar.
- Windows'ta `flutter test` rastgele çöker (0xC0000005); testler dosya dosya yeniden denemeyle koşuyor.
- Gerçek veri denemesi `canli-veri` (12 Ağustos görüntüsü, küçük veri) üzerinde yapıldı; seri eşitliği zayıf sinyal.
- Aylık tablo sistem yazısı %130 üstünde büyümüyor (sabit geometri); erişilebilirlik kararı sende.
- `home_widget` eklentisi KGP uyarısı veriyor (derlemeyi bozmuyor).
