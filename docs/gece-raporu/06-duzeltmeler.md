# 06 Düzeltmeler (inceleme bulguları)

Hiçbir yayınlama yapılmadı (push, etiket, release, secret, anahtar üretimi yok). Yalnız yerel commit.

## Yapıldı
- **Güncelleme arayüzü (kritik):** `lib/features/settings/guncelleme_bolumu.dart` Ayarlar'a bağlandı (denetim aç/kapa, yalnız Wi-Fi, "Şimdi denetle", "İndir ve kur"); ilk açılışta tek seferlik onay (`Kabuk` ilk karede), cevaplanana kadar ağ isteği yok. Akış `lib/platform/guncelleme/akis.dart`: ağ kuralı (mobil veride ek onay), kurulum izni, indirme + SHA256SUMS doğrulaması, kurulumdan hemen önce dosyanın yeniden özetlenmesi. Kotlin `apkKur` artık beklenen SHA-256'yı alır ve oturuma yazılan baytları hash'leyip uyuşmazsa commit etmeden iptal eder. `Kopru.apkKur(yol, ozet)`.
- **Gelecek damga (önemli):** `updated_at`/`deleted_at` > şimdi + 1 gün ise dosya reddedilir (kırpma değil: kırpmak idempotansı bozar). `syncMaxFutureSecs`; spec (`docs/senkron.md`), purity testi ve sync testleri. Mobil onay penceresi dosyadaki silinmiş-işaretli kayıt sayısını gösterir.
- **Tür başına sınır:** alışkanlık ve görev ayrı 10.000 (`syncMaxHabits`, `syncMaxTasks`); spec + test.
- **Yedek içe aktarma:** JSON derinlik sınırı (decode öncesi), toplam kayıt sınırı, ad/başlık/not uzunluğu, `TypeError` yerine okunur `FormatException`; her iki modda veri değişmez testi. Mobil Ayarlar bu hata iletisini gösterir.
- **Masaüstü sürüm sabitleme:** `habit-tracker-v5-calisma/pubspec.yaml` drift, drift_dev, sqlite3_flutter_libs tam sürüm, `sqlite3: 3.3.3` override; kilit dosyası aynı kaldı (yalnız "direct overridden" notu).
- **release.yml:** test / derle (salt okuma) / yayın (yazma yetkisi) olarak üç iş; anahtar yalnız etiketli çalıştırmada diske iner ve yalnız APK derleme adımının ortamına verilir (GITHUB_ENV yok); `pub get` anahtarsız; etiketsiz çalıştırmada anahtar hiç yüklenmez; tüm aksiyonlar (ci.yml ve guvenlik-kapisi.yml dahil) commit SHA'sına sabit. `build.gradle.kts` boş `HABIT_KEYSTORE`'u "yok" sayar.
- **Ekran görüntüleri:** `docs/gece-raporu/ekran/` repodan ve yerel git geçmişinden çıkarıldı (`git filter-branch`, reflog/gc ile; geçmişte 0 nesne kaldı). Commit SHA'ları değişti (henüz push yok). Metin raporlarında kişisel alışkanlık adı yok (arandı).
- **Erişilebilirlik testi:** Aylık, İstatistik, Alışkanlıklar, Ayarlar, açık+koyu tema (etiket + kontrast + 48 dp). Aylık yalnız 48 dp kuralından muaf (aşağıda).
- **README:** doğrulanmamış iddialar "DENENMEDİ" notuyla yumuşatıldı; güncelleme cümlesi güncellendi.
- **Güvenlik taslağı** (`guvenlik/incelemeler/v0.1.0.md`): "Düzeltme durumu" bölümü eklendi; `Sonuç:` BOŞ.

## Doğrulananlar (çalıştırıldı)
- Mobil: `flutter analyze lib test` temiz; 37 test dosyasının tamamı geçti (dosya dosya, 0xC0000005 çökmelerinde yeniden denemeyle). Yeni: `guncelleme_akis_test.dart` (Wi-Fi kuralı, mobil onay, izin yok, dosya değişirse reddedilip silinir, ayarlar anahtarları, ilk açılış onayı "Hayır" = sıfır ağ isteği, indir-kur akışı sahte Kopru'ya özet iletir).
- Masaüstü v5 çalışma kopyası: 23 test dosyasının tamamı geçti. Yerel commit `b6e4467`.
- `esitle.ps1 -Kaynak habit-tracker-v5-calisma` çalıştırıldı, `kaynak_ozet.json` yenilendi, `uyum_test` geçti.
- Üç workflow dosyası YAML olarak ayrıştırıldı.

## Doğrulanmadı
- Kotlin değişikliği (özet denetimi, `argument` okuma) DERLENMEDİ ve cihazda çalıştırılmadı (Gradle derlemesi bu aşamada yok).
- Sahte GitHub ile imzalı release APK'da güncelleme e2e (PLAN Faz 2 çıkışı): yapılmadı (imza anahtarı yok, emülatör aşaması dışı).
- `release.yml` yeni yapısı GitHub'da hiç çalışmadı; artifact aktarımı ve `yayin` işi ilk etiketli çalıştırmada görülecek.
- Güncelleme bölümünün gerçek ekranda görünümü (yalnız widget testi).

## Sapmalar / kararlar
- Gelecek damga için "kırp" yerine "reddet" seçildi (idempotans); saati ≥1 gün yanlış cihazın dosyası reddedilir, ileti saati denetlemesini söyler.
- Masaüstü `backup_screen.dart`'ta onay penceresi yok (doğrudan birleştirir); silinecek sayı yalnız mobil onayına eklendi.
- Plan içi çelişki (Arda'ya): Aylık hücre 44 px (Faz 1) ile 48 dp kuralı (Kararlar) çelişiyor; test Aylık'ı yalnız 48 dp'den muaf tutuyor.
- Yedek doğrulaması sync ayrıştırıcısı kadar alan bazlı değil (derinlik, sayı, uzunluk, tür hatası).

## Açık işler
- **Yayın düzenine ekle:** masaüstü v1.4.0 etiketlendikten sonra `esitle.ps1`'i yeniden çalıştır ve `kaynak_ozet.json` etiketini güncelle; o zamana dek mobil CI etiket denetiminde kırmızı olur (kaynak etiketi v1.3.3, v5 kodu yok). Mobil repoyu o zamana dek push etme.
- Sahte veriyle yeni ekran görüntüleri (emülatör aşaması); README/rapora konabilir.
- Güvenlik taslağını yeniden incele, `Sonuç:` ve `Kapsam:` kararı Arda'da; düşük bulgular (B7-B14) açık.
- Gerçek telefon deneme listesine ekle: ekran kapalıyken sayaç, bildirim ve "tamamsa gelmez", imzalı APK, gerçek `.habitsync`, Android 12, yeniden başlatma, TalkBack, güncelleme e2e.
- Faz 4 yalnız spike (HTTPS sunucu, wifi istemci, App Link yok); "yapıldı" sayılmaz. Masaüstü sürüm yükseltmeleri (1.3.3+8, CHANGELOG taslak) Arda kararı.
- 12 px yazı taraması hâlâ yalnız Bugün ve Görevler'de.
