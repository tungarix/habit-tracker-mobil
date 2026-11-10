# 04a: Mobil senkron (Faz 3, mobil taraf)

Durum: tamam (yayımlanmadı, yerel commit). Masaüstü kaynağı `habit-tracker-v5-calisma`, dal `mobil-senkron-v5`,
commit `7a6046a` (02d raporu "tamam"). Push, etiket, release, anahtar, secret yok.

## Ne yapıldı
- **Eşitleme:** `tool/esitle.ps1` listesine `lib/data/database/sync_schema.dart`, `lib/data/sync/*` ve
  `docs/senkron.md` eklendi (spec'i `sync_purity_test` okuyor). v5 core/data/sync dosyaları kopyalandı,
  `kaynak_ozet.json` yenilendi: `kaynak_commit` 7a6046a, `etiketle_ayni: false`, `yayimlandi: false` ve
  "v1.3.3 sonrası YAYIMLANMAMIŞ dal" notu. Masaüstünün 11 testi mobile geldi (sync_test, migration_v5, backup_v5, ...).
- **Ayarlar > "Bilgisayarla senkron":** `.habitsync` dışa aktar (`share_plus`, MIME `application/x-habitsync`) ve içe
  aktar (`file_picker`, `FileType.any`; Android'de `.habitsync` için MIME yok, gerçek denetim içerikteki `format`
  alanı ve 16 MiB sınırı). Yeni dosyalar: `features/settings/senkron_dosya_servisi.dart`, `senkron_akisi.dart`.
- **Onay ekranı:** dosya önce doğrulanır (bozuksa onay açılmaz, "Hiçbir şey değişmedi"), sonra dosyadaki
  alışkanlık/işaret/görev/seans sayısı ve "birleştirilir, son değişiklik kazanır, ikilenmez" gösterilir; İptal / İçe aktar.
- **Android:** `AndroidManifest.xml`'e Takvim kalıplarıyla VIEW (mime + 3 pathPattern) ve SEND filtreleri;
  BROWSABLE yok. `MainActivity.kt`: `bekleyenDosya` / `dosyaGeldi` köprüsü, yalnız `content://`, en çok 16 MB,
  yeniden yaratılan süreçte aynı intent ikinci kez işlenmez. Dart: `Kopru` genişletildi, `kopruProvider`
  (testte null), `Kabuk` dosyayı dinleyip aynı onay akışına verir.
- **tool/e2e/senkron_e2e_test.dart + calistir.ps1:** iki cihaz = iki geçici SQLite dosyası, değişim gerçek `.habitsync`
  dosyasıyla diskten. Senaryolar: ilk eşleştirme (a: iki gerçek v4 dosyası ayrı ayrı v5'e çıkar, b: masaüstü v4
  dosyası + telefon masaüstünün v4 JSON yedeğini içe aktarmış; ikisinde de ilk senkron hiçbir kaydı ikilemez,
  5 satır uid benimsendi), a, b (iki sıra), c (silme yeni/eski, eşit damga), d (idempotans/ping-pong/silme yankısı),
  e (unicode), f (üçüncü cihaz), ek 2 (boşa çekilen ✓ geri gelmez), ek 3 (yedekten geri dönüş), ek 4 (gün
  başlangıcı), ölçek. `ci.yml`'e e2e adımı eklendi. README güncellendi.
- `test/senkron_ui_test.dart` (4 widget testi): dışa aktarma, onay + iptal, bozuk dosya, dışarıdan açılan dosya
  (soğuk başlangıç ve çalışırken, hata mesajı dahil).

## Doğrulananlar (gerçekten çalıştırıldı)
- `flutter analyze`: benim dosyalarımda sorun yok. Tek kalan 7 `info` (avoid_print) `tool/spike_tls/` içinde:
  paralel çalışan Faz 4 spike'ın dosyası, bana ait değil.
- `tool/test_calistir.ps1` (dosya dosya, düzeltmelerden sonra tam koşu): 37/37 dosya geçti (iki dosya motor
  çökmesi nedeniyle 2. denemede). İlk koşuda `ayarlar_test` (yeni bölüm temayı ListView'in tembel alanından dışarı itti,
  test penceresi 1600 -> 2600) ve `sync_purity_test` (docs/senkron.md yoktu, esitle'ye eklendi) kırılmıştı; ikisi düzeltildi.
- E2E: `tool/e2e/calistir.ps1` 8/8 ardışık koşuda geçti (15 test). Ölçek: 5,0 MB dosya, dışa aktarma ~0,3 sn,
  boş cihaza içe aktarma ~2,6 sn, ikinci içe aktarma ~0,5 sn.
- Release derleme: `HABIT_YEREL_NDKSIZ=1 flutter build apk --release --target-platform android-arm64` başarılı
  (171,4 MB, yalnız derleme denemesi; Kotlin değişikliği derlendi). Birleşmiş manifestte filtreler görüldü.
- `uyum_test`, `sync_purity_test`, `migration_v5_test` geçiyor (kopyalar özetle tutuyor).

## Doğrulanmadı
- **Gerçek cihazda/emülatörde hiçbir şey denenmedi:** dosya yöneticisinden dokununca açılma, Paylaş menüsü,
  `file_picker` ve `share_plus` gerçek akışı, MainActivity.kt'nin çalışma zamanı davranışı (yalnız derlendi),
  onay ekranının TalkBack ile okunması. Widget testleri sahte servis/köprü kullanır. Emülatör bu görevde
  kullanılmadı (talimat).
- Release APK'nın CI imzalı sürümü (yerel APK imzasız yayın modunda ve 171 MB).
- Arda'nın gerçek masaüstü yedeğinin telefona aktarımı (canlı veriye dokunulmadı).

## Sapmalar / dikkat
- **CI uyum bekçisi kırılır:** `kaynak_ozet.json` `etiket: v1.3.3` diyor ama dosyalar v5. Masaüstü v1.4.0 etiketlenip
  `esitle.ps1` yeniden çalıştırılana kadar `ci.yml` "Uyum bekçisi" adımı kırmızı olacak (bilerek; sahte etiket yazmadım).
  Mobil yayın sırasına bağlı: önce masaüstü v1.4.0, sonra burada esitle + etiket.
- `.habitsync` içindeki `device.app` alanı kopya kodda sabit `habit-tracker-desktop` (kopya dosya elle değişmez);
  telefon dışa aktarımı `device.name = Telefon` yazar. Spec bu alanı denetlemiyor.
- E2E "iki cihaz" aynı kodu çalıştırır: masaüstü ve mobil senkron dosyaları özetle birebir aynı (uyum_test). Planın
  "masaüstü reposunu etiketten checkout et" adımı etiket olmadığı için kurulmadı; bekçi zaten bu eşitliği denetliyor.
- E2E'de `created_at` (hücre/mood) karşılaştırmadan çıkarıldı: yedekten geri dönüş (replace) hücreleri "şimdi"
  ile yeniden yaratır, eşit `updated_at`'te eski yerel satır kalır; bu üst veri iki cihazda saniye farkıyla ayrışabilir
  (flaky bir mismatch olarak yakalandı, veri hatası değil).
- Bu makinede `flutter_tester` rastgele çöküyor; e2e betiği çökme imzasında yeniden dener.

## Açık işler
- Emülatör/gerçek telefonda: dosyaya dokun, Paylaş menüsü, dışa/içe aktar, TalkBack.
- Masaüstü v1.4.0 etiketi sonrası `esitle.ps1`, `kaynak_ozet.json` etiket güncellemesi, mobil sürüm yükseltme
  (v0.2.0), `guvenlik/incelemeler/v0.2.0.md` (yeni intent filtreleri ve dosya okuma `/security-review` kapsamına girmeli).
