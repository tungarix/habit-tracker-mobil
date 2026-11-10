# 07: Veri bütünlüğü incelemesi (v5 migration ve senkron)

Salt okunur inceleme. Hiçbir repo dosyası değiştirilmedi; deneyler scratchpad'deki kopyalarda yapıldı.
Gerçek veri `habit-tracker\canli-veri\AppData\aktenak.sqlite` yalnız kopyalandı. SHA-256'sı iş başında ve sonunda aynı (`543aa98a...`), yani dokunulmadı.

Bağımsız test dosyası: `...\scratchpad\v5\test\bagimsiz_test.dart` (22 test). Masaüstü v5 çalışma ağacının (`habit-tracker-v5-calisma`, commit 7a6046a) kopyasında koşturuldu.

## Doğrulananlar (çalıştırıldı, çıktısına bakıldı)

1. **Mevcut testler:** `migration_v5_test` (14) ve `sync_test` (37) kopyada geçti. Gerçek veri testi `HABIT_CANLI_KOPYA` ile açıkken koştu.
2. **Gerçek veri v4 -> v5** (10 alışkanlık, 19 hücre, 0 mood/görev/seans):
   - Eski her sütun, ham sqlite3 ile satır satır karşılaştırıldı: bayt bayt aynı (`bagimsiz_test.dart` A grubu).
   - `user_version`=5, `integrity_check`=ok, `foreign_key_check` boş.
   - uid'ler benzersiz. `updated_at`, `created_at` ile dolu (alışkanlıkta `MAX(1,created,archived)`). `silinenler` boş.
   - Tetikleyici sayısı beklenen 25 (5 tablo x 4 + 3 uid + 2 ayar).
   - İkinci açılışta migration değişiklik yapmadı.
3. **Seri:** Dart `computeStreaks` (migrasyon sonrası veri) ile Python'da sıfırdan yazılan bağımsız hesap, 10 alışkanlık x 2 referans gün (2026-08-12 ve 2026-11-10) için aynı çıktı verdi.
4. **v1 ve v2 yedekleri** (`...v1-backup...`, `...faz0-backup...`) v5'e çıkıyor, satır kaybı yok.
5. **Yarım kalmış yükseltme** (uid ve updated_at sütunu eklenmiş, sürüm hâlâ 4) sonraki açılışta tamamlanıyor. Önceden verilmiş uid korunuyor, yenileri benzersiz.
6. **Tetikleyiciler** (gerçek kopya üzerinde):
   - uid üretimi.
   - `updated_at=0` ise "şimdi", açık verilen değer korunuyor.
   - Upsert yolu (`setEntryStatus` çakışmada) damgalıyor.
   - Sync tarzı açık `updated_at` ve uid benimseme damgayı oynatmıyor.
   - Hücreyi boşa çekmek `habitUid|date` izi bırakıyor, yeniden işaretleyince iz siliniyor.
   - Alışkanlık silme tek `habit` izi bırakıyor, cascade hücreler için iz yok.
   - Mood yaz/sil/yaz.
   - Görev silme: seans görevsiz kalıyor, görev izi var.
   - Aynı saniyede iki düzenleme sonsuz döngüye girmiyor.
   - Gün başlangıcı damga satırı yalnız o anahtarda tutuluyor.
7. **Senkron senaryoları** (iki bellek-içi cihaz):
   - İdempotency: ikinci içe aktarma `changed=false`, iki cihazın durumu eşit.
   - LWW iki yönde. Eşit damgada her taraf kendi değerini koruyor (spec §9 ile uyumlu).
   - Boşa çekilen hücre geri gelmiyor. Eski dosya silinmiş hücre, mood, görev ve alışkanlığı geri getirmiyor. Sonradan işaretleme canlandırıyor.
   - Alışkanlık silme ile daha yeni düzenleme çakışınca kayıt hücreleriyle geri geliyor. Silme daha yeniyse iki tarafta da siliniyor.
   - İlk eşleştirme: iki cihazda ayrı ayrı girilmiş aynı veri 4 kayıt benimsiyor, ikilenmiyor. Adı aynı ama `created_at` farklı alışkanlık ayrı kalıyor.
   - v5 yedekten "tamamen değiştir" geri dönüşte yedekte olmayan satır karşı cihazdan da siliniyor.
   - v4 biçimli (uid'siz) yedekle geri dönüşten sonra senkron kaydı ikilemiyor.
   - Ölçek: 3000 hücre, durum eşit.
8. **Gün başlangıcı:**
   - LWW iki yönde yakınsıyor.
   - Hiç ayarlanmamış cihaz diğerinin değerini ezmiyor, ayarı ve damgasını alıyor.
   - Hücreler gün metniyle gidiyor. 01:30'da oluşan alışkanlıkta gün başlangıcı 0 ve 4 iken seri hesabı farklı çıkıyor (etki gerçek). Senkrondan sonra iki cihaz aynı saati kullanıyor ve seri eşitleniyor.
9. **Testlerin gerçekten yakaladığı (mutasyon):**
   - Tetikleyici `AND NEW.uid IS OLD.uid` koşulu kaldırılınca B grubu kırıldı.
   - İçe aktarmada hücre LWW `>` yerine `>=` yapılınca idempotency ve LWW testleri kırıldı.
   - Silmede `<=` yerine `<` yapılınca testler kırıldı (v4 yedek senaryosu yakaladı).
   - Hepsi geri alındı.
10. **Mobil uyum bekçisi** (mobilin scratchpad kopyasında; gerçek repoya dokunulmadı):
    - `test/uyum_test.dart` kopyalanan bir dosyaya satır eklenince, `sync_schema.dart` tetikleyici metni bozulunca ve kopya dosya silinince kırıldı (hepsini tek tek yakaladı).
    - CRLF dönüşümü yanlış alarm vermedi. Geri alınca geçti.
    - `streak.dart` davranışı bozulunca (`run++` yerine `run += 2`) kopyalanan `widget_test`, `dates_dst_test`, `night_creation_test` kırıldı. `stats_test` kırılmadı, yani seriyi yalnız bu üç test koruyor.
    - Mobil `migration_v5_test`, tetikleyici bozulunca kırıldı.
    - `scripts/uyum_bekcisi.py` doğru çalışıyor. Etiket farklıysa hata (çıkış 1), yalnız master farklıysa uyarı (çıkış 0).
    - `kaynak_ozet.json`'daki 42 dosyanın 42'si hem mobilde hem masaüstü v5 ağacında özetle tutuyor.

## Bulgular ve riskler

1. **Önemli, bilinen ama ilerideki CI'yı kıracak:** `kaynak_ozet.json` `etiket`=`v1.3.3`. v1.3.3 etiketinde v5 yok. 42 dosyanın 17'si etiketle tutmuyor (sync/, sync_schema, tables, database(.g), backup_repository, constants, senkron.md, 6 test). Mobil `ci.yml` etiketi checkout edip `uyum_bekcisi.py` çalıştıracağı için masaüstü v1.4.0 etiketlenip `esitle.ps1` yeniden çalışana kadar mobil CI kırmızı olur. `kaynak_ozet.json` notu bunu söylüyor, yayın sırasında unutulmamalı.
2. **Küçük, belge tutarsızlığı:** `lib/platform/db_baglanti.dart` yorumu `kaynak_ozet.json` içindeki `bilincli_sapmalar` girdisine atıf yapıyor, ama liste boş. Sapma `database.dart`'a değil `main.dart`'taki `AppDatabase.forTesting(dbBaglantisi())` ile yapılıyor. `database.dart` kopyası dokunulmamış, bekçi bozulmuyor. Yalnız yorum yanıltıcı.
3. **Küçük, tasarım notu (kod okumasıyla, test edilmedi):** `reorderHabits` her alışkanlığa `UPDATE` atar. `AFTER UPDATE` tetikleyicisi değer aynı kalsa bile tüm alışkanlıkların `updated_at`'ini "şimdi" yapar. Bir cihazda sıralama, öbür cihazda daha önce yapılmış bir yeniden adlandırmayı LWW ile ezebilir. Veri kaybı küçük, spec'te yazılı değil.
4. **Zayıf sinyal:** gerçek veri küçük (10 alışkanlık, 19 hücre, hepsi `current`=0, `longest` 0-2). Seri eşitliği güçlü bir kanıt değil, yalnız bozulma olmadığını gösterir. Seri mantığının kendisi mutasyon testleriyle ayrıca korunuyor (madde 10).
5. **Kapsam sınırı:** `canli-veri` 12 Ağustos tarihli bir görüntü. Arda'nın bugünkü gerçek veri klasörü (data_location) bu değilse onun üzerinde denenmedi. Gerçek yedeği (JSON) mobile aktarma yolu emülatörde 05-dogrulama.md'de.

## Doğrulanmayanlar

- `tool/e2e/` (mobil uçtan uca) çalıştırılmadı.
- Android emülatör ve gerçek cihaz bu aşamada kullanılmadı.
- Tüm masaüstü test seti çalıştırılmadı. `migration_v5_test`, `sync_test` ve kendi 22 testim koştu.
- Windows'ta `flutter_tester` rastgele çöktü (0xC0000005 imzası, "did not complete"). Yeniden denemede geçti, test hatası değil.

## Sapma ve engel

Yok. Yayınlama, push, anahtar üretimi yapılmadı. Hiçbir repo değişmedi.
