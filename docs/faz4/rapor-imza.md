# Rapor: masaüstü güncelleme paketine Ed25519 imzası (Karar 1)

Depo: `habit-tracker-v5-calisma`, dal `mobil-senkron-v5`, commit `6796394`.
Push, etiket, uzak depo, GitHub isteği, yayın: **yok**. Commit mesajında Claude/Co-Authored-By yok.

## Ne yapıldı

- **Güncelleyici** (`lib/data/update/imza.dart`, `guncelleyici.dart`, `ag.dart`, `saf.dart`): `SHA256SUMS.txt`
  ham baytlarıyla indirilir, `SHA256SUMS.txt.sig` (ham 64 bayt) koda gömülü açık anahtarla doğrulanır.
  Doğrulama zip indirilmeden ve özet satırı ayrıştırılmadan ÖNCE yapılır. `imza_yok` (sürümde .sig yok ya da 404) ve
  `imza_gecersiz` (bozuk, yanlış uzunluk, başka anahtar, kurcalanmış özet) = kurulum reddi, hazırlık klasörü silinir.
  Türkçe hata metinleri `guncelleme_bolumu.dart`'ta. İmzasız sürüm yine "yeni sürüm" olarak görünür, ama kurulmaz.
  Kart satırı "imzalı değil" yerine "Kurulumdan önce sürümün imzası ve SHA-256 özeti doğrulanır." oldu.
- **Bağımlılık:** `pinenacl 0.6.0` (tam sürüm sabit). Neden: pubspec.lock'taki `pointycastle 4.0.0` kaynağında
  Ed25519 yok (yalnız OID tablosunda geçiyor; TASARIM'daki "doğrulanmadı" maddesi böylece kapandı). `pinenacl` saf
  Dart, çalışma zamanı bağımlılığı sıfır, ffi yok, TweetNaCl portu. `cryptography` (ffi/collection/crypto/meta çeker)
  ve `ed25519_edwards` (4 geçişli paket) daha ağır olduğu için seçilmedi.
- **release.yml:** `SHA256 hesapla` ile attestation arasında `SHA256SUMS.txt imzala` adımı; sır
  `HABIT_UPDATE_SIGNING_KEY` yalnız o adımın `env`'inde. Sır yoksa/boşsa/yanlışsa (gömülü açık anahtarla doğrulanmazsa)
  betik hata verir, release oluşmaz. `.sig` release'e ve manuel artifact'a eklendi. Güvenlik kapısı, izinler, Flutter sürümü,
  draft release dokunulmadı. Anahtar hiçbir yerde basılmaz.
- **Betik:** `scripts/guncelleme_imza.dart` (`uret <klasor>` ve `imzala <dosya> <cikti.sig>`). `uret` klasör ACL'ini
  (`icacls`, miras kapalı, yalnız kullanıcı) ANAHTARDAN ÖNCE ayarlar, özel anahtarı ekrana basmaz, var olan dosyanın
  üzerine yazmaz. `imzala` üretilen imzayı açık anahtarla kendi doğrular.
- **Belge:** `docs/guncelleme-imzasi.md` (kullanım, sır tanımlama, yedek talimatı, sınır). CHANGELOG'a satır.

## Anahtar

- Özel anahtar: `C:\Users\Arda\Documents\HabitTracker-anahtar\guncelleme-ozel-anahtar.b64` (44 karakter, base64 tohum).
  Klasör ve dosya yalnız `DESKTOP-NUUAJN3\Arda` tam yetkili (icacls ile görüldü). Repo, log, rapor, commit içinde yok
  (depoda özel anahtar metni için tarama yapıldı: eşleşme yok).
- Açık anahtar `lib/data/update/imza.dart` içinde gömülü. Gerçek anahtarla betik uçtan uca denendi (imzala, gömülü açık
  anahtarla doğrulandı).

## Arda'nın yapacakları

1. **Sırrı tanımla:** dosya içeriğini GitHub deposunda `HABIT_UPDATE_SIGNING_KEY` adlı Actions sırrı olarak ekle
   (Settings > Secrets and variables > Actions). Ben GitHub'a dokunmadım; sır olmadan sonraki etiketli release düşer.
2. **Yedekle:** anahtar dosyasının en az bir kopyasını bu diskten ve repodan bağımsız, kendi seçeceğin güvenli bir yerde
   sakla. Kaybolursa güncelleme zinciri kopar: yeni anahtarlı sürümü mevcut kurulumlar kabul etmez, elle indirme gerekir.
   Kopyayı bulut klasörüne/repoya düz metin bırakma.
3. **Koruma ne zaman başlar:** eski sürümler imza doğrulamaz; imzalı sürümü eskisi gibi yalnız SHA-256 ile kurar. İmza
   zorunluluğu, kullanıcı bu kodu taşıyan ilk sürüme geçtikten SONRAKİ güncellemeler için geçerlidir. Bu ilk sürümün
   release'inde de `.sig` bulunmalı (sır tanımlıysa iş akışı zaten üretir).

## Testler (hepsi Windows'ta, dosya dosya)

- `test/update/imza_test.dart` (yeni, 4): geçerli imza; mesaj/imza/anahtar/uzunluk bozulması; `.sig` ayrıştırma.
- `test/update/guncelleyici_test.dart` (+9, toplam 24 geçti): geçerli imza, bozuk imza (zip indirilmediği de doğrulandı),
  yanlış uzunluk, başka anahtar, uygulamadaki anahtar farklı, `.sig` listede yok, `.sig` 404, kurcalanmış SHA dosyası,
  sonuna satır eklenmiş SHA dosyası.
- `saf_test`, `guncelleme_bolumu_test`, `uygula_test`, `surum_test`: geçti. Testler gerçek anahtarı kullanmaz; sahte
  sunucu her seferinde yeni test anahtarı üretir.
- `flutter analyze` (lib/data/update, lib/features/update, test/update, scripts): sorun yok.
- İlk çalıştırmada üç dosya birlikte koşulunca guncelleyici_test "did not complete" ile çöktü (bilinen Windows
  rastgele çökmesi); aynı dosya tek başına yeniden koşulunca 24/24 geçti, gerçek hata yoktu.

## Denenmedi / dikkat

- **Tüm `flutter test` paketi koşulmadı**, yalnız `test/update/*`. Diğer testler bu değişiklikten etkilenmez ama denenmedi.
- **`release.yml` gerçek CI'da çalıştırılmadı** (yasaktı); YAML elle gözden geçirildi, ayrıştırıcıyla doğrulanmadı.
  `dart run` komutu yerelde çalıştı; CI'daki `dart` yolu (flutter-action) varsayım.
- İmza adımı sırrı `env`'den alır; GitHub sırları logda maskeler, ama deposunda iş akışı yazabilen biri sırrı
  okuyabilir. TASARIM'daki "anahtar çevrimdışı olmalı" tavsiyesi bu kararla gevşemiştir: koruma, release
  varlıklarını değiştirebilen ama iş akışı yazamayan saldırgana karşıdır.
- Arayüzde yeni hata metinleri için ayrı widget testi yok (metinler `guncellemeHataMetni` tablosunda).
- Yan etki: `dart format lib` yanlışlıkla 36 ilgisiz dosyayı yeniden biçimledi; güvenlik aracı geri almayı engellediği
  için bunlar `git stash` içine alındı (etiket `imza-format-geri-al`, yalnız biçim farkı). Çalışma ağacı temiz, commit
  yalnız imza işini içerir. Stash girdisi silinmedi (silme engellendi); istersen `git stash drop` ile sil.
- Mobil depoya (`habit-tracker-mobil`) dokunulmadı; `esitle.ps1` kapsamında `imza.dart` paylaşılan dosya değil.
