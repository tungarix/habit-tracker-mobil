# 02d: Masaüstü şema v5 ve .habitsync (Faz 3, masaüstü tarafı)

Durum: tamam (yayımlanmadı, yerel commit). Çalışma kopyası: `habit-tracker-v5-calisma`, dal `mobil-senkron-v5`
(master'dan). `habit-tracker` ana ağacına ve `canli-veri`'ye yazılmadı (orijinal dosyaların SHA-256'sı
işten önce ve sonra aynı).

## Commit'ler (yerel, push yok, co-author yok)
1. `0c60220` Şema v5 + yedek biçimi v5
2. `29a564b` .habitsync dışa/içe aktarma + docs/senkron.md
3. `7a6046a` Ayarlar bölümü, README/CHANGELOG taslak notu, CI Flutter sabitleme, PR şablonu

## Ne yapıldı
- **Şema v5** (`lib/data/database/`): `uid` (nullable + `CREATE UNIQUE INDEX IF NOT EXISTS`, tablo tanımı da
  aynı index adlarını kullanır) `habits/tasks/focus_sessions`; `updated_at` (INTEGER, DEFAULT 0, `created_at`'ten
  doldurulur) beş tabloda; `silinenler(kind, anahtar, deleted_at)`. Tetikleyici metni tek dosyada:
  `sync_schema.dart` (mobil bu dosyayı kopyalayabilir). AFTER INSERT uid üretir ve damgalar, AFTER UPDATE damgalar,
  AFTER DELETE silinenler'i doldurur, aynı anahtarla yeniden ekleme izi siler. Migration idempotent.
- `dayStartHour` senkronlanan ayar: damga `Settings`'te `dayStartHourUpdatedAt` satırında (tetikleyici tutar).
- **Yedek v5**: uid/updatedAt/habitUid/taskUid/deleted yazılır; v1-v4 okuma korundu; replace'de değerler korunur;
  merge'de updatedAt dosyadaki değerde kalır; daha yeni sürümlü yedek reddedilir.
- **`lib/data/sync/`** (saf Dart, Flutter/dart:io importu yok): `sync_format.dart` (sabitler, hata, rapor),
  `sync_parse.dart` (doğrulama), `sync_export.dart`, `sync_import.dart` (LWW, silinenler, ilk eşleştirme,
  görev-önce-seans, tek transaction).
- **docs/senkron.md**: tek kaynak spec (biçim, sınırlar, doğrulama, birleştirme, ilk eşleştirme, şema, yedek v5,
  gün başlangıcı notu, bilinen sınırlar). Sınırlar: dosya 16 MiB, 250000 kayıt, JSON derinliği 8, metin 10000,
  ad 100, başlık 200. Kodla aynı olduğunu `test/sync_purity_test.dart` denetler.
- **Arayüz**: Yedek & Ayarlar'da "Telefonla senkron: dosya dışa/içe aktar" bölümü, iki düğme, sonuç özeti
  (snackbar). Yeni sekme yok. Dosya seçilmeden boyut sınırı denetlenir.
- Flutter 3.47.5 `ci.yml` ve `release.yml`'de sabitlendi; PR şablonuna "mobilde esitle.ps1" maddesi eklendi.
- README ve yeni CHANGELOG.md: "taslak, yayımlanmadı, 1.4.0 adayı" olarak yazıldı. `pubspec.yaml`'a dokunulmadı.

## Doğrulananlar (gerçekten çalıştırıldı)
- `flutter analyze`: sorun yok.
- 23 test dosyasının tamamı tek tek çalıştırıldı ve geçti (flutter_tester motor çökmesinde yalnız o dosya
  yeniden denendi; gerçek test hatasında yeniden deneme yok). Ham sayılar: `migration_v5_test` 14 test (11 + gerçek veri kopyası olmadan 3 atlanır),
  `sync_test` 37, `backup_v5_test` 3, `sync_ui_test` 1, `sync_purity_test` 2.
- **Gerçek veri kopyaları üzerinde** (scratchpad'e kopyalanmış `canli-veri/AppData`): v4 `aktenak.sqlite`
  (10 alışkanlık, 19 hücre), v2 `faz0-backup`, v1 `v1-backup` v5'e yükseltildi: satır sayıları ve alışkanlık
  adları aynı, uid'ler benzersiz UUID v4, updated_at doluydu, silinenler boş, şema taze kurulumla birebir aynı
  (tablolar, indexler, tetikleyiciler). Yükseltilmiş gerçek veri dosyaya yazılıp boş cihaza alındı; ikinci içe
  aktarma sıfır değişiklik.
- Sentetik v2/v3/v4 -> v5 ve yarım kalmış yükseltme onarımı; tetikleyici davranışları (uid, damga, açık damga
  korunur, silinenler anahtarları, cascade, yeniden ekleme, gün başlangıç damgası).
- Senkron: biçim/doğrulama (28 bozuk dosya türü, sınırlar, BOM, ileri uyum, "hiçbir şey değişmez"), Takvim a-f
  uyarlaması (iki yönlü, LWW iki sıra iki yön, sil/düzenle, eşitlikte kayıt kalır, ad+saniye eşleşmesi,
  idempotans, ping-pong, silme yankısı, üçüncü cihaz, unicode/uzun metin), planın 4 ek senaryosu, ölçek.
- Ölçek (20 alışkanlık x 3 yıl = 21900 hücre, 2000 görev, 5000 seans; dosya 5,0 MB): dışa aktarma ~0,3 sn,
  boş cihaza içe aktarma ~2,6 sn, ikinci içe aktarma ~0,5 sn.

## Doğrulanmadı
- `flutter build windows` / uygulamanın gerçekten açılıp düğmelerin gerçek `file_picker` ile denenmesi
  (yalnız widget testi: bölüm ve iki düğme var). Dosya seç/kaydet akışı elle denenmedi.
- Mobil taraf ve iki taraf arası gerçek e2e (`tool/e2e/` mobil repoda); burada iki "cihaz" iki bellek içi
  veritabanıdır.
- Gerçek Arda masaüstü yedeğinin (JSON) mobile aktarımı.
- CI'da Flutter 3.47.5 pin'i (iş akışı çalıştırılmadı; yerel Flutter 3.47.5).

## Sapmalar / kararlar
- `updatedAt` Dart tarafında `int` (unix saniyesi), DateTime değil: SQLite'ta `DEFAULT 0` ADD COLUMN ile
  uyumlu ve LWW saniye karşılaştırır.
- Gün başlangıç damgası için Settings'e `dayStartHourUpdatedAt` satırı eklendi (Settings'e sütun eklenmedi;
  plan "beş tablo" diyordu).
- Alışkanlık silinince hücreleri için ayrı iz yazılmaz (cascade sırasında üst satır yok); alışkanlık izi yeter.
  Plan "cascade dahil" diyordu; amaç (silme taşınır) sağlanıyor, hücre izleri yalnız tek hücre boşaltmada var.
- Yedek replace'de silinenler tablosu silinmez: yedekte olmayan satırların izi kalır, sonraki senkron onları
  karşı taraftan da siler (geri yükleme = durum yedek gibi olur). docs'ta yazılı.
- **Mevcut hata düzeltildi**: v1 veritabanını yükseltmek (`habit_entries` yeniden kurma) `value` sütunu
  yüzünden patlıyordu; `newColumns`'a `value` ve `updatedAt` eklendi. Gerçek v1 kopyasında kanıtlandı.
- Tetikleyicilerde `INSERT OR REPLACE` yok, upsert var (dıştaki upsert çakışma kipini ezip UNIQUE hatası
  veriyordu; testte yakalandı).
- `.habitsync` JSON anahtarları snake_case (Takvim gibi), JSON yedek camelCase (mevcut).
- İlk eşleştirme: gerçek veride `created_at` aynı saniye kuralıyla; farklı saniye = iki ayrı alışkanlık.
- Flutter pin'i `release.yml`'e de eklendi (plan yalnız "masaüstü CI" diyor; ikisi aynı sürümü kullanmalı).

## Açık işler
- Mobil: `lib/data/database/sync_schema.dart` + `lib/data/sync/` kopyalanacak, `kaynak_ozet.json`'a girmeli
  (tetikleyici metni dahil); `esitle.ps1` listesine `lib/data/sync/*` ve `sync_schema.dart` eklenmeli.
- Sürüm 1.4.0+9, etiket, güvenlik incelemesi (`guvenlik/incelemeler/v1.4.0.md`), yayın: Arda'nın işi.
- Çalışma kopyası dalı master'a birleştirilmedi; `habit-tracker-v5-calisma` worktree'si duruyor.
- Eşit-damga ve saat-farkı sınırları (docs §9) kabul edilmiş durumda.
