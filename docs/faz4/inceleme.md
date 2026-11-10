# Faz 4 inceleme bulguları ve düzeltmeleri

Bağımsız inceleme dokuz bulgu verdi, dokuzu da "orta". Düşük önemli bulgu gelmedi. Her bulgunun yeniden üretimi inceleyenin kendi kopyasında yapıldı; burada her biri için ne değiştiği, hangi testle kilitlendiği ve neyin denenmediği yazılı. Hiçbir şey yayımlanmadı; değişiklikler yerel commit'lerde (masaüstü: `habit-tracker-v5-calisma`, dal `mobil-senkron-v5`; mobil: `habit-tracker-mobil`, dal `main`).

Özet: sekiz bulgu kodda düzeltildi ve regresyon testi eklendi; biri (güncelleme paketi imzası) bir karar olduğu için düzeltilmedi.

| # | Bulgu | Durum |
|---|---|---|
| 1 | Yinelenen `Authorization` başlığı IP hata sınırını atlatıyor | Düzeltildi, test var |
| 2 | Tek kullanımlık jeton yarışı (yarım gövdeli eski istek oturumu eziyor) | Düzeltildi, test var |
| 3 | İndirilen zip yalnız aynı release'in `SHA256SUMS.txt`'iyle doğrulanıyor | Düzeltilmedi, karar Arda'da |
| 4 | Sıralama ekranı tüm alışkanlıkların `updated_at`'ini yeniliyor | Düzeltildi (iki depo), test var |
| 5 | `_bitir` birleştirme sürerken oturumu `sureDoldu`/`hata` yapıyor | Düzeltildi, test var |
| 6 | Mobil: POST yanıtsız bitince "bilgisayar değişmedi" yazıyor | Düzeltildi, test var |
| 7 | Uygulayıcı başlamazsa güncelleme kartı takılı kalıyor | Düzeltildi, test var |
| 8 | Sunucu portu işletim sistemine bırakılıyor (Linux'ta QR geçersiz çıkar) | Düzeltildi, test yalnız sözleşmeyi doğruluyor |
| 9 | Mobil: ücretli işaretli Wi-Fi "mobil" sayılıyor | Düzeltildi, Dart tarafı test var, Kotlin denenmedi |

## 1. Yinelenen Authorization başlığı (`sunucu.dart`, `_kimlik`)

Sorun: `headers.value('authorization')` başlık iki kez gelince `HttpException` atıyordu. `_istekGeldi` bunu 500 `ic_hata` yapıyor ama `_ipHata` artmıyordu; her istek `istekEnFazla` (20) sayacına girdiği için kimliksiz bir LAN istemcisi 21 istekle oturumu `hata` durumuna düşürebiliyordu.

Düzeltme: `headers['authorization']` listesi okunuyor; tek elemanlı değilse kimliksiz sayılıyor. Kimliksiz yol zaten 401 yazıp `_ipHata`'yı artırıyor, yani yinelenen başlık yanlış jetonla aynı muameleyi görüyor (5 hatadan sonra IP yanıtsız kesilir).

Test: `test/wifi_sunucu_test.dart`, "yinelenen Authorization başlığı kimliksiz sayılır". Ham TLS ile iki başlıklı istek: ilk beşi 401, altıncısı yanıtsız, sunucu `bekliyor`da kalır. Düzeltme geri alınınca kırılıyor (denendi).

## 2. Jeton yarışı (`sunucu.dart`, `_session`)

Sorun: kimlik ve sıra denetimi gövde okunmadan önce yapılıyor, `_session` ise jetonun hâlâ geçerli olduğuna ve durumun `bekliyor` olduğuna bakmıyordu. Jetonu bilen biri eksik gövdeyle istek açıp bekleyebiliyor, meşru telefon bağlanıp jetonu yaktıktan sonra gövdeyi tamamlayınca `istemci` eziliyor, durum `hazir`den `baglantiOnayi`ne geri dönüyordu.

Düzeltme: `_session` başında `_jeton == null || _durum != bekliyor` ise 401 `yetkisiz` dönüyor; jeton bu denetimin hemen ardından, araya `await` girmeden yakılıyor. İncelemenin önerdiği "jetonu gövde okunmadan tüket" yerine bu yol seçildi: gövdeyi bekleten bir istek jetonu elinde tutup meşru telefonu engelleyemiyor, jeton ancak gövdesi tam gelen ilk istekte yanıyor.

Kalan sınır: jetonu bilen biri gövdeyi telefondan önce tam gönderirse o kazanır. QR'ı gören biri için bu tasarımın doğal sınırı; masaüstündeki Onay 2 penceresi istemci adı ve IP'yi gösteriyor, kullanıcı tanımadığı bağlantıyı reddeder.

Test: "sızan jeton yarışı". Saldırgan 5 baytlık gövdeyle bekler, meşru telefon oturum açar (`hazir`), saldırgan gövdeyi tamamlar: yanıt 401, `istemci.ad` hâlâ "Pixel 7", durum `hazir`, meşru anahtar `GET /v1/state` 200 alır. Düzeltme geri alınınca kırılıyor.

## 3. Güncelleme paketi imzası (`guncelleyici.dart`, `saf.dart`) - DÜZELTİLMEDİ

Bulgu: zip ve `SHA256SUMS.txt` aynı release'ten geliyor; özet bütünlük sağlıyor, kimlik sağlamıyor. GitHub hesabı ya da release ele geçirilirse saldırgan ikisini birlikte değiştirir ve doğrulama geçer. Önkoşul güçlü (maintainer hesabı). İnceleyici adres denetimini, zip açmayı (zip-slip, ADS, sürücü harfi, simge bağı, büyük/küçük harf çakışması, yalan boyut) ve yönlendirme denetimini 23 URL ve 11 hazırlanmış zip ile denedi; hepsi beklendiği gibi reddetti, SHA-256 uygulaması `sha256sum` ile eşleşti.

Neden düzeltilmedi: çözüm bir imza anahtarı ve gömülü genel anahtar gerektiriyor (Ed25519) ya da `release.yml`'in ürettiği build-provenance attestation'ının doğrulanması. İkisi de anahtar üretimi / yayın süreci kararı; bu turda anahtar üretilmesi yasaktı. Kartta "imzalı değil, yalnız SHA-256" uyarısı duruyor, `rapor-masaustu-guncelleme.md` bunu bilinen sınır olarak yazıyor.

Karar: masaüstü v1.4.0 yayınlanmadan önce (güncelleyici ilk kez gerçek kullanıcıya gidecek) Ed25519 mi, attestation mı, yoksa "bilinen sınır olarak kalsın" mı. Hesap güvenliği (2FA, korunan dal/etiket) bu riskin pratik savunması.

## 4. Sıralama `updated_at`'i eziyor (`database.dart`, `reorderHabits`) - iki depo

Sorun: sıralama ekranı listedeki tüm alışkanlıklara `UPDATE sort_order` yazıyordu. `sync_schema.dart`'taki `AFTER UPDATE` tetikleyicisi değeri değişmeyen UPDATE'i de kullanıcı düzenlemesi sayıp `updated_at`'i "şimdi" yapıyor; kayıt başına son-yazan-kazanır kuralı yüzünden telefonda yapılmış daha eski ama gerçek bir düzenleme (ör. yeniden adlandırma) sonraki eşitlemede eziliyordu. İnceleyici bunu masaüstünde yeniden üretti; mobilde aynı kod olduğu varsayılmıştı. Kod okunarak doğrulandı: mobil `database.dart` aynı `reorderHabits`'e sahip, aynı düzeltme uygulandı.

Düzeltme: `where` koşuluna `sortOrder.isNotValue(i)` eklendi; yalnız yeri gerçekten değişen satır yazılıyor.

Test (iki depoda `test/siralama_damga_test.dart`): üç alışkanlık, damgalar sabitlenir, `[A, C, B]` sıralanır; A'nın damgası aynı kalır, B ve C'ninki yenilenir. Düzeltme geri alınınca masaüstünde kırılıyor (denendi); mobilde geri alma denemesi yapılmadı, test aynı.

Kalan risk: tetikleyici hâlâ değeri değişmeyen herhangi bir UPDATE'i düzenleme sayıyor. Bilinen tek toplu yazan yer sıralamaydı; tetikleyici değiştirilmedi çünkü mevcut veritabanlarına göç gerektirir (`IF NOT EXISTS`). Yeni toplu yazma eklenirse aynı kalıba dikkat.

## 5. `_bitir` birleştirme sürerken (`sunucu.dart`)

Sorun: 600 sn genel süre, istek sayısı sınırı (20) ve toplam hata sınırı (50) `isleniyor` durumunda da `_bitir`'i çağırıyordu. Durum `sureDoldu`/`hata` oluyor, masaüstü "hiçbir şey değişmedi" diyor, oysa DB işlemi sürüyor ve veri birleşiyor; birleştirme 2 sn zorla kapanıştan uzun sürerse telefon da hata görüyor.

Düzeltme: `_bitir(d, {islem})`: `isleniyor`dayken yalnız birleştirmenin kendi sonucu (`islem: true`, `_stateYukle`'nin iki çağrısı) oturumu bitirir; süre, istek sayısı ve hata sınırı yok sayılır. `iptalEt` ve `/v1/end` zaten bunu yapıyordu.

Test: "birleştirme sürerken genel süre dolsa da": `oturumEnFazla` 1,5 sn, yapay olarak tutulan `uygula`, 2,2 sn sonra durum hâlâ `isleniyor`, bırakınca 200 ve `tamam`, veri birleşmiş. Düzeltme geri alınınca kırılıyor.

Not: süre dolmuş ve işlem bitmiş bir oturumun toplam süresi `oturumEnFazla`'yı aşabilir (birleştirme süresi kadar). Birleştirme DB işlemi olduğu için kabul edildi.

## 6. Mobil "Yarım kaldı" metni (`wifi_eslestir_ekrani.dart`)

Sorun: telefon yerelde birleştirdikten sonra `durumGonder` `zaman_asimi`, `ag_ulasilamiyor` ya da `yanit_bozuk` ile biterse ekran kesin olarak "Telefon güncellendi, ama bilgisayar değişmedi" yazıyordu. İstek bilgisayara ulaşmış ve orada birleşmiş olabilir (POST zaman aşımı 90 sn, yalnız bilgisayarın onay beklemesi 60 sn).

Düzeltme: bu üç kodda başlık "Bilgisayarın sonucu belli değil", metin "Yanıt gelmediği için bilgisayara ulaşıp ulaşmadığı belli değil. Bilgisayardaki pencere «tamamlandı» diyorsa iş bitmiştir; emin değilsen eşleştirmeyi yeniden yap, veri bozulmaz." Kesin ret kodları (`reddedildi`, `iptal`, `sure_doldu` vb.) eski "Yarım kaldı / bilgisayar değişmedi" metnini koruyor. Birleştirme idempotent olduğu için yeniden denemek güvenli (rapor-birlestirme.md senaryo 2 sonuncu adımı: sonraki eşitleme 0/0/0).

Test: `test/wifi_eslestir_ekrani_test.dart`, üç kod için döngü: belirsiz başlık ve metin görünür, "bilgisayar değişmedi" metni yok. Eski `reddedildi` testi aynen geçiyor.

## 7. Uygulayıcı başlamazsa kart takılıyor (`guncelleme_bolumu.dart`, `_kur`)

Sorun: `_kur` yalnız `GuncellemeHatasi` yakalıyordu; `Process.start` `ProcessException` fırlatırsa (antivirüs, SmartScreen, Windows dışı sistem) ekran "kuruluyor"da kalıyor, iki düğme de devre dışı, hata metni yok.

Düzeltme: her istisna yakalanıyor; `GuncellemeHatasi` değilse yeni `uygulayici_baslamadi` kodu ve Türkçe açıklama gösteriliyor, düğmeler geri açılıyor, uygulama kapanmıyor. Ayrıca paket Windows zip'i olduğu için Windows dışında hem Ayarlar'daki "Güncelleme" bölümü hem açılış denetimi (`GuncellemeAcilis.etkin`) kapatıldı.

Test: `test/update/guncelleme_bolumu_test.dart`, "uygulayıcı başlatılamazsa": sahte `uygulayiciyiBaslat` `ProcessException` atar; `(uygulayici_baslamadi)` yazılır, `kapat` çağrılmaz, "Kapat ve güncelle" düğmesi tekrar etkin. Düzeltme geri alınınca kırılıyor.

Test edilmeyen: Windows dışı gizleme (`Platform.isWindows` koşulu; testler Windows'ta koşuyor).

## 8. Sunucu portu (`sunucu.dart`, `baslat`)

Sorun: port 0 ile işletim sistemine bırakılıyordu; telefon `qrCoz`'de yalnız 49152-65535'i kabul ediyor. Windows'ta geçici port aralığı bu olduğu için sorun yok; Linux'ta varsayılan 32768-60999, portların yaklaşık %58'i 49152'nin altında kalır ve QR "Habit Tracker eşleştirmesine ait değil" diye reddedilir.

Düzeltme: ilk bağlanışta port `portEnAz`-`portEnCok` (sozlesme.dart, `qrCoz` de aynı sabitleri kullanıyor) arasından rastgele seçiliyor, dolu çıkarsa 30 kez deniyor; sonraki adresler aynı portu kullanıyor (eskisi gibi).

Test: sekiz sunucu açılır, hepsinin portu aralıkta. DİKKAT: bu test Windows'ta düzeltme olmadan da geçiyor (Windows zaten bu aralıktan veriyor); yalnız sözleşmeyi kilitler. Linux'ta gerçek etki denenmedi.

## 9. "Wi-Fi mı" denetimi ücretli ağda yanlış (`MainActivity.kt`, `wifi_eslestir_ekrani.dart`)

Sorun: `agTuru` `isActiveNetworkMetered`'a bakıyor; ücretli işaretlenmiş Wi-Fi ya da başka telefonun hotspot'u "mobil" sayılıp eşleştirme "Önce Wi-Fi'a bağlan" hatasıyla engelleniyordu. Yerel ağ eşitlemesi veri harcamaz.

Düzeltme: `agTuru` aynen kaldı (uygulama içi güncelleme indirmesi ücretli ağda mobil verimi gibi davranmalı, yani doğru kullanım). Köprüye yeni `wifiBagli()` eklendi: Kotlin `NetworkCapabilities` ile etkin ağın taşıyıcısı Wi-Fi ya da Ethernet mi diye bakıyor, ücretli olup olmadığına bakmıyor. Eşleştirme ekranı bunu kullanıyor.

Test: `wifi_eslestir_ekrani_test.dart`, "ücretli (metered) işaretli Wi-Fi engellenmez": `agTuru` 'mobil', `wifiBagli` true döner; tarama başlar. Eski "Wi-Fi yoksa tarama başlamaz" testi (`wifiBagli` false) geçiyor.

DENENMEDİ: Kotlin kodu Android'de çalıştırılmadı, gerçek ücretli Wi-Fi ya da hotspot ile denenmedi; yalnızca Dart tarafı sahte köprüyle test edildi. VPN üzerinden Wi-Fi'da `TRANSPORT_VPN` ayrı taşıyıcı olabilir ve false dönebilir; bu durumda kullanıcı yine "Önce Wi-Fi'a bağlan" görür (denenmedi).

## Düşük önemli bulgular

İnceleme düşük önemli bulgu üretmedi.
