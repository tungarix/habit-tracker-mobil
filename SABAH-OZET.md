# Sabah özeti (10 Kasım 2026)

Bu dosya gece işinin bağımsız son doğrulamasından sonra yazıldı. Önceki raporlar doğru kabul edilmedi; aşağıdaki "çalıştırıldı" ibareleri bu turda gerçekten koşulan komutlardır. Ayrıntı: `docs/gece-raporu/10-son-dogrulama.md`.

## a) Bu gece ne yapıldı

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
| 3 Masaüstü şema v5 + `.habitsync` | Var, masaüstünde yerel dal `mobil-senkron-v5` | Birim testi + e2e (mobil/masaüstü senkron kodu, geçici DB) + gerçek verinin kopyasında migration; `.habitsync` içe aktarma emülatörde (VIEW intent) |
| 4 Wi-Fi eşleştirme, mobil istemci | Var, mobil `main` | Birim/widget testi; masaüstü sunucusuyla gerçek TLS e2e (127.0.0.1, 6 senaryo); emülatörde 10.0.2.2 üzerinden tam akış (QR yerine bağlantı yapıştırılarak) |
| 4 Wi-Fi eşleştirme, masaüstü sunucu + "Telefonla eşleştir" penceresi | Var, masaüstü yerel dal `mobil-senkron-v5` | Birim testi (gerçek HttpServer, loopback) + e2e; inceleme bulguları düzeltildi |
| 4 Masaüstü uygulama içi güncelleyici | Var, aynı dalda (`masaustu-guncelleme` birleştirildi) | Birim testi (sahte GitHub, sahte kurucu); gerçek kurucu, gerçek GitHub, gerçek kurulum denenmedi; imza yok (yalnız SHA-256) |
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

## d) Karar bekleyenler

- Uygulama adı: şu an "Habit Tracker" (manifest etiketi). Kimlikler (`com.aktenak.habit_tracker`) sabit kalacak.
- Dokunma alanı: Aylık hücre 48 dp yapıldı (karar kapandı), erişilebilirlik testinde muafiyet yok.
- Plan dışı izinler: `FOREGROUND_SERVICE`, `WAKE_LOCK`, `VIBRATE` birleşik manifestte var (paket bağımlılıklarından geliyor). Plan "ön plan servisi yok" diyor; kaldırılsın mı, kalsın mı?
- Kaynak etiketi ve masaüstü v1.4.0 zamanı: `kaynak_ozet.json` etiketi v1.3.3, ama v5 kodu yayımlanmamış dalda. v1.4.0 çıkana dek mobil CI etiket denetiminde kırmızı olur.
- Mobil repo adı ve açılışı: `tungarix/habit-tracker-mobil`, public, MIT (plan kararı); açılış zamanı sende.
- Güncelleme paketi imzası: masaüstü güncelleyici zip'i yalnız aynı release'in `SHA256SUMS.txt`'iyle doğruluyor; GitHub hesabı ya da release ele geçirilirse saldırgan ikisini de değiştirir. Seçenekler: Ed25519 imza (gömülü genel anahtar), attestation doğrulaması ya da bilinen sınır olarak kalması. v1.4.0'dan önce karar gerek (`docs/faz4/inceleme.md`, bulgu 3).
- Boyut: yerel APK 180 MB (NDK'sız, sembol temizlenmemiş). Uygulama içi güncelleyicinin varsayılan indirme sınırı 150 MB; CI'daki APK bunun altında kalmalı, ilk CI çıktısında kontrol et.

## e) Yayın öncesi sıra (yapılmadı, senin onayınla)

1. Masaüstü v1.4.0 çıkışı. Artık yalnız v5 şeması değil Wi-Fi eşleştirme sunucusu ve uygulama içi güncelleyiciyi de içerir (`mobil-senkron-v5` dalı, `masaustu-guncelleme` birleşik). Çıkmadan önce karar: güncelleyici paketi imzası (aşağıda, d) ve güncelleyiciyi taşıyan ilk sürümün kullanıcıya elle kurulacağı (kendi kendine gelmez). Dalın akıbeti ve `masaustu-guncelleme` worktree'sinin kaldırılması da sende.
2. `esitle.ps1` yeniden çalıştır, `kaynak_ozet.json` etiketini güncelle
3. İmza anahtarı üretimi ve iki yedek (`scripts/imza_anahtari_olustur.ps1`)
4. Mobil repo açılışı
5. CI ilk koşu
6. Güvenlik incelemesi (`guvenlik/incelemeler/v0.1.0.md`; `Sonuç:` satırını sen doldurursun)
7. Etiket
8. Taslak release
9. Telefonda deneme (yukarıdaki liste)
10. Yayımla

## f) Bilinen sınırlar

- Gerçek cihazda hiçbir şey denenmedi; emülatör de yalnız Android 15 (API 35), Telefon35. Android 12 ve farklı ekranlar denenmedi.
- Güncelleme kurulumu, SHA reddi, bildirimin gelmesi, ekran kapalıyken sayaç, yeniden başlatma sonrası alarmlar denenmedi.
- `release.yml` ve CI GitHub'da hiç çalışmadı.
- Faz 4 gerçek ağda ve gerçek cihazda hiç denenmedi: yalnız loopback testleri ve emülatörde 10.0.2.2 üzerinden bir akış. Kamerayla gerçek QR okuma, Windows Güvenlik Duvarı sorusu, gerçek telefon ve gerçek Wi-Fi yok. Sertifika kabulü yalnız bir emülatör imajında ve debug derlemede görüldü.
- Kotlin `wifiBagli` (ücretli Wi-Fi düzeltmesi) derlenip çalıştırılmadı; yalnız Dart tarafı sahte köprüyle test edildi. VPN üzerinden Wi-Fi'da yanlış "Wi-Fi değil" çıkabilir (denenmedi).
- Masaüstü sunucu portu artık 49152-65535 arasından seçiliyor (Linux için); Linux'ta denenmedi. Güncelleme bölümü Windows dışında gizli.
- Masaüstü güncelleyicisi: gerçek kurucu, gerçek GitHub, SmartScreen/antivirüs davranışı denenmedi; paket imzasız (yalnız SHA-256); geri alma yalnız dosya kopyalama aşaması için.
- Eşleştirmede telefon sonuç yanıtını alamazsa "bilgisayarın sonucu belli değil" der; kullanıcı bilgisayardaki pencereye bakmalı. Birleştirme tekrarlanabilir (veri bozulmaz).
- Veritabanı tetikleyicisi değeri değişmeyen UPDATE'i de düzenleme sayıyor; sıralama düzeltildi ama başka toplu yazma eklenirse aynı sorun doğar (`inceleme.md`, bulgu 4).
- Mobil klasör artık git deposu (yerel `main`, uzak depo yok); `docs/faz4/ekran/` ve bazı raporlar önceki turdan işlenmemiş duruyor.
- Yerel release APK NDK'sız ve 180 MB; yayın APK'sı yalnız CI'dan çıkar.
- Windows'ta `flutter test` rastgele çöker (0xC0000005); testler dosya dosya yeniden denemeyle koşuyor.
- Gerçek veri denemesi `canli-veri` (12 Ağustos görüntüsü, küçük veri) üzerinde yapıldı; seri eşitliği zayıf sinyal.
- Aylık tablo sistem yazısı %130 üstünde büyümüyor (sabit geometri); erişilebilirlik kararı sende.
- `home_widget` eklentisi KGP uyarısı veriyor (derlemeyi bozmuyor).
