# 02b Aylık, İstatistik, Alışkanlıklar, Ayarlar (Faz 1 UI, ajan B)

## Yapılan
- `lib/features/monthly/monthly_screen.dart` (MonthlyScreen): alışkanlık x gün tablosu, hücre 44 px, yatay kayar, alışkanlık adları sol sütunda sabit (kaydırma görünümünün dışında), ay ileri/geri + "Bugüne dön", altta mood grafiği. Hücreler `Semantics` etiketli ("Kitap, 12 Kasım: yapıldı", sayılıda "7 / 10", kapalı günlerde nedeni). Dokunma ✓ → ✗ → – → boş, sayılı alışkanlıkta uzun basış miktar girer (A'nın `cycleHabit` / `enterHabitAmount` işlevleri). Başlangıç ayı `todayProvider`'dan (gün başlangıç saatine uyar).
- `lib/features/stats/stats_screen.dart` (StatsScreen): masaüstündeki gibi (genel kartlar, alışkanlık başına seri / en uzun / tamamlama, 30 gün şeridi, mood korelasyonu). Telefon için 2x2 kart, yazılar en az 12 px, şerit ve mood çubukları ekran okuyucuya özet etiketle okunur.
- `lib/features/habits/habits_screen.dart` + `habit_edit_dialog.dart` (HabitsScreen): oluştur / düzenle / arşivle / geri yükle / sil (onaylı), ad, açıklama, tür (bool / sayılabilir + hedef), kategori, renk, ikon, planlı günler, sürükleyerek sıralama. Renk ve ikon seçicileri 48 dp, sesli adlı ve seçili durumlu.
- `lib/features/settings/settings_screen.dart` (SettingsScreen, "Yedek & Ayarlar"): tema (Sistem / Açık / Koyu), gün başlangıç saati (varsayılan 04:00, 0-12 kaydırıcı), akşam hatırlatıcısı saati (`ReminderSettings` üstünden), JSON dışa aktar (`share_plus`, geçiciye yazıp paylaşır), içe aktar (`file_picker`, birleştir / tamamen değiştir seçimi), otomatik yedek durumu + uyarı "Bu yedekler telefon dışına çıkmaz, ara sıra dışa aktar. Uygulamayı kaldırırsan bu yedekler de silinir." "Klasörü aç" ve Windows ayarı yok.
- `lib/features/settings/backup_file_service.dart`: file_picker ve share_plus'ı saran ince arayüz (`BackupFileService`) + sistem uygulaması + provider; testte sahtesi takılır. Seçilen dosya 16 MB üstündeyse reddedilir.
- `lib/features/settings/reminder_settings.dart`: `abstract class ReminderSettings` (`readHour` / `writeHour`), `InMemoryReminderSettings`, `reminderSettingsProvider`. Gerçek bildirim mantığı başka ajanda; o provider'ı override eder.
- `lib/features/settings/auto_backup_lifecycle.dart`: `AutoBackupLifecycle(container).start()` açılışta ve uygulama öne gelince (`WidgetsBindingObserver`) `autoBackup.runIfDue` çağırır; hata yutulur, eşzamanlı çalışma korunur.
- `lib/features/settings/ui_metin_b.dart`: bu ekranların bütün metinleri (`MetinB`). Birleştirmede `ui_metin.dart` içine katlanacak.
- Testler: `aylik_tablo_test` (5), `ayarlar_test` (9), `alisanlik_yonetimi_test` (7), `istatistik_ekrani_test` (1), `auto_yedek_yasam_dongusu_test` (3), ortak `b_test_yardimci.dart`. Masaüstü `add_habit` / `delete_habit` / `settings_screen` / `grid_night_cell` testlerinin karşılıkları bunların içinde (ekle, sil+iptal, tema+veri durumu, gece eklenen alışkanlığın ilk günü işaretlenebilir).

## Doğrulananlar
- `flutter analyze` (monthly, stats, habits, settings + benim 6 test dosyam): No issues found.
- Yukarıdaki 5 test dosyasının hepsi geçti (25 test). Ayrıca `uyum_test`, `core_purity_test`, `dates_dst_test` benim dosyalarım eklenmişken geçti.
- Sabit sütun: yatay kaydırınca etiketin konumu değişmiyor, gün hücresi >100 px sola kayıyor; hücre boyutu tam 44x44 (test).
- İçe aktarma akışı sahte picker ile: birleştir (mevcut veri kalır), tamamen değiştir (yalnız yedek kalır), seçici iptali, mod diyaloğu iptali, bozuk dosya (hata mesajı, veri değişmez). Dışa aktarma sahte paylaşıma `aktenak-backup-*.json` adıyla JSON verir.
- Gün başlangıcı kaydırıcısı ayarı veritabanına yazıyor; hatırlatıcı anahtarı `ReminderSettings`'e yazıyor.

## Doğrulanmayanlar
- Hiçbir şey cihazda veya emülatörde çalıştırılmadı: gerçek `file_picker` (Android içerik URI'si) ve gerçek `share_plus` paylaşma menüsü denenmedi. TalkBack ile okuma denenmedi; yalnız `Semantics` etiketleri testle doğrulandı.
- `SystemBackupFileService` içindeki temp dosya yazımı ve eski paylaşım dosyalarını silme kodu testsiz (path_provider gerçek cihaz ister).
- Ekranlar kabuğun (A) içinde birlikte denenmedi; Aylık / İstatistik sekme gövdesi olarak Scaffold'sız yazıldı, Alışkanlıklar ve Ayarlar kendi Scaffold'larıyla itilen sayfa olarak.
- Testler Windows motor çökmesi nedeniyle bazen yeniden çalıştırıldı (alisanlik_yonetimi, istatistik bazı koşularda "did not complete"); gerçek hata değil, yeniden denemede geçti. `ayarlar_test` içinde `pumpAndSettle` yerine iki kare bekleten `kisaBekle` kullanılıyor (snackbar / diyalogla uzun kare dizisi motoru çökertiyordu).

## Sapmalar / engeller
1. **`withData: true` yok.** Planda `file_picker` için `withData: true` yazıyor; kurulu `file_picker 13.3.2` sürümünde bu parametre yok (`pickFile`, `PlatformFile.readAsBytes()` döndürüyor, içerik URI'sinde de çalışır). `readAsBytes` kullanıldı; amaç (`File(path)` varsayımına bağlı kalmamak) aynı.
2. **Tema varsayılanı.** Kopyalanan `data/providers.dart` içindeki `ThemeModeNotifier` varsayılanı `dark`; plan mobilde Sistem diyor. Ayarlar ekranı `themeModeProvider`'ı gösterir/yazar; kabuk (`app.dart`, A) bunu `themeMode`'a bağlayıp başlangıç değerini Sistem yapmalı (kopya dosyaya dokunulamaz, özet bekçisi bozulur; mobil sapma olarak `kaynak_ozet.json`'a yazılabilir veya app.dart'ta override edilir).
3. **`dart format lib/features` yanlışlıkla klasörün tamamında çalıştı.** Başkalarına ait `tasks/task_edit_dialog.dart`, `tasks/widgets/task_row.dart`, `today/widgets/focus_card.dart`, `today/widgets/mood_card.dart` yalnız biçim olarak değişmiş olabilir (anlam değişmedi). Diğer ajanların bu dosyalarda yarım düzenlemesi varsa eşleşme sorunu çıkabilir.
4. Gün başlangıç ayarı kaydırıcı (0-12); hatırlatıcı 17-23 kaydırıcı + anahtar (masaüstündeki gibi, saat bazlı). Dakika yok, `ReminderSettings` yalnız saat taşıyor.
5. Yönetim ekranı (HabitsScreen) ve Ayarlar için kabukta giriş yolu yok; A'nın kabuğunda (ör. Bugün ekranından) bir yere bağlanmalı. Ben eklemedim.

## Açık işler (birleştirme)
- `main.dart`: `_startAutoBackup(container)` ve saatlik Timer yerine `AutoBackupLifecycle(container).start();` (container zaten orada var).
- `MetinB` → `lib/ui_metin.dart` içine katlanacak; `settings/ui_metin_b.dart` silinecek. (Ekranlar `MetinB.xxx` kullanıyor, toplu yeniden adlandırma yeter.)
- `reminderSettingsProvider` gerçek uygulamayla override edilecek (bildirim ajanı); şu an bellek-içi.
- Dosya adı çakışması yoksa `test/b_test_yardimci.dart` A'nın `ui_yardimci.dart` ile birleştirilebilir.
- Gerçek cihazda: dışa aktar paylaşım menüsü, içe aktar (Drive / İndirilenler / WhatsApp'tan gelen .json), TalkBack ile Aylık hücreler.
