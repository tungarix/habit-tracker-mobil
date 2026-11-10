# 02a Arayüz A: kabuk, Bugün, Görevler

## Yapılan
- **Kabuk** (`lib/app.dart`): `NavigationBar` ile Bugün / Görevler / Aylık / İstatistik, `IndexedStack` (sekmeler kaydırma konumunu korur), Bugün ile açılır. Alışkanlıklar ve Ayarlar Bugün ekranının sağ üst menüsünden `Navigator.push` ile açılır. B'nin sınıfları dosya yollarıyla içe aktarıldı. Eski `lib/kabuk.dart` yer tutucusu silindi.
- **Tema** (`lib/shared/theme.dart`, masaüstü `AppColors`/`AppTheme` uyarlandı): Sistem/Koyu/Açık, varsayılan Sistem. Alt menü, düğme (en az 48 dp) ve dokunma boyutu (`MaterialTapTargetSize.padded`) temaya işlendi. Ortak parçalar: `habit_style`, `habit_actions` (dokun = döngü, uzun bas = miktar), `status_mark`, `habit_avatar`, `streak_badge`, `count_entry_dialog`.
- **Bugün** (`lib/features/today/`): üst özet (X/Y, 7 günlük yüzde, açık/geciken görev, ilerleme çubuğu), bugünün alışkanlık listesi (✓ → ✗ → – → boş), sayılabilirde uzun basınca miktar, planlı olmayanlar ayrı grupta, her satırda açılıp kapanan 30 günlük ısı şeridi (15+15 iki satır, hücre başına `Semantics`), mood seçici (48 dp) + not + 30 günlük mood çizgisi, odak kartı, "Bu hafta" görevleri + hızlı görev ekleme.
- **Odak arayüzü**: `lib/features/today/focus_controller.dart` içinde `FocusController` soyut sınıfı (`state` = `ValueListenable<FocusState>`, `results` akışı, `start`, `stop`, `dispose`), bellek içi `MemoryFocusController` ve `focusControllerProvider`. Kart yalnız bu arayüze bağlı; gerçek uygulama sağlayıcıyı override ederek takılır.
- **Görevler** (`lib/features/tasks/`): aciliyete göre gruplu liste (Geciken, Bugün, Yarın, Bu hafta, Sonra, Tarihsiz), Bitenler gösterme/temizleme, ekleme/düzenleme penceresi, boş durum daveti. Dokun = bitir, uzun bas = düzenle.
- **Metinler**: arayüz metinleri `lib/ui_metin.dart` içinde tek sınıfta (`Metin`).
- **Erişilebilirlik**: durum etiketi "Kitap, 10 Kasım: yapıldı" biçiminde (satır ve ısı hücreleri), görev satırı durum/öncelik/tarih okur, mood ve süre hazırları `selected` bilgisi taşır, grup başlıkları `header`.

## Doğrulananlar (gerçekten çalıştırıldı)
- Gerçek repoda `flutter analyze`: No issues found (B'nin gerçek ekranları ile).
- Testler (gerçek repoda, B'nin gerçek ekranlarıyla): `kabuk_test` (4 sekme, dar ekranda alt menü, Rail yok, varsayılan tema Sistem, Ayarlar/Alışkanlıklar push edilir), `bugun_test` (dokunuş döngüsü etiketle doğrulandı; sayılabilirde uzun basış → miktar → DB'de ✓ ve 8; ısı şeridi 30 hücre açılıp kapanır; mood kaydı/silme; hızlı görev), `gorevler_test` (gruplar, bitirme, boş durum), `odak_karti_test` (kart yalnız arayüze bağlı; `MemoryFocusController` 1 dakikadan kısa seansı yazmaz, uzun olanı yazar, süre dolunca kendiliğinden biter), `erisilebilirlik_test` (Flutter'ın `androidTapTargetGuideline`, `labeledTapTargetGuideline`, `textContrastGuideline` kuralları açık ve koyu temada Bugün ve Görevler üzerinde geçti; 12 px altı yazı taraması geçti).
- `tool/test_calistir.ps1` ile 19 test dosyasının tamamı, benim dosyalarımın bulunduğu geçici kopyada (B ekranları yer tutucuyla) geçti; motor çökmesi iki dosyada görüldü, yeniden denemede geçti.

## Doğrulanmayanlar
- Gerçek telefonda/emülatörde açılmadı; TalkBack ile elle denenmedi (yalnız Semantics ağacı testle okundu).
- Kontrast kuralı yalnız çizilen metinleri ölçer; durum işaretlerinin ikon/kenarlık kontrastı (3:1) elle hesaplanmadı, koyu temadaki onay işareti rengi göz kararı seçildi.
- Gerçek `FocusController` (C ajanı) ile birlikte çalışma: arayüz derleniyor, kart sahte denetleyiciyle test edildi; `main.dart` içinde override edilip edilmediği benim kapsamımda değil, doğrulanmadı.
- Çok büyük yazı ölçeği (sistem yazı boyutu %200) elle denenmedi.

## Sapmalar / engeller
1. **Tema sağlayıcısı**: `data/providers.dart` içindeki `themeModeProvider` varsayılanı koyu (senkron kopyası, dokunulmadı). Plan "varsayılan Sistem" diyor. Geçici çözüm: `lib/shared/tema_modu.dart` içinde `temaModuProvider` (varsayılan Sistem, `themeModeProvider` değişikliklerini yansıtır). Sınır: Ayarlar ekranı hâlâ `themeModeProvider` ile okuyup yazıyor; kayıtlı değer yokken seçici "Koyu"yu gösterir, oysa uygulama Sistem'dedir. Kalıcı çözüm: `providers.dart` varsayılanını `ThemeMode.system` yap, `kaynak_ozet.json` `bilincli_sapmalar` bölümüne gerekçeyi yaz, `app.dart` içinde `themeModeProvider`'ı izle, `tema_modu.dart` dosyasını sil.
2. **Dosya çakışması**: `test/odak_test.dart` C ajanının dosyası; yanlışlıkla üzerine yazdım, `git show HEAD` ile commit'li sürümünü geri koydum, benim testimi `test/odak_karti_test.dart` adına taşıdım. C'nin commit'lenmemiş değişikliği varsa kaybolmuş olabilir, kontrol edilmeli.
3. Sayılabilir alışkanlıkta dokunma da ✓ → ✗ → – → boş döngüsünü çalıştırır (plan böyle), tamamlanmış miktar ✓ sonrası ✗'ya geçince sıfırlanır. Masaüstünde dokunuş doğrudan miktar penceresi açıyordu.
4. `MemoryFocusController` saniye sayar (duvar saati değil); arka planda düşük sayar. Gerçek denetleyici zaman damgası kullanmalı (kodda `shortcut` notu var).
5. Ana ekran görev bloğunda masaüstündeki "genişlet" düğmesi yerine Görevler sekmesine geçen ok var.

## Açık işler
- `providers.dart` tema varsayılanı ve `tema_modu.dart` temizliği (yukarıdaki 1).
- `focusControllerProvider` gerçek denetleyiciyle override edilmeli (`main.dart`/kök).
- Cihazda TalkBack ve gerçek yedekle denemeler (planın Faz 1 çıkış koşulu).
