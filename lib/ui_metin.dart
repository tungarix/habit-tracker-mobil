import 'package:intl/intl.dart';

import 'core/enums.dart';

/// Every user-facing string of the shell, Bugün and Görevler screens lives here
/// (one file, Turkish). Other screens add their own groups below when merged.
abstract final class Metin {
  // --- Shell / navigation ---------------------------------------------------
  static const uygulamaAdi = 'Habit Tracker';
  static const sekmeBugun = 'Bugün';
  static const sekmeGorevler = 'Görevler';
  static const sekmeAylik = 'Aylık';
  static const sekmeIstatistik = 'İstatistik';
  static const menu = 'Menü';
  static const menuAliskanliklar = 'Alışkanlıklar';
  static const menuAyarlar = 'Ayarlar';

  // --- Common ---------------------------------------------------------------
  static const iptal = 'İptal';
  static const kaydet = 'Kaydet';
  static const sil = 'Sil';

  // --- Bugün: header --------------------------------------------------------
  static const ozetAliskanlik = 'alışkanlık';
  static const ozet7Gun = '7 günlük';
  static String ozetGorev(int geciken) =>
      geciken > 0 ? 'görev · $geciken geciken' : 'açık görev';

  /// "10 Kasım Salı" style title.
  static String gunBasligi(DateTime d) {
    final s = DateFormat('d MMMM EEEE', 'tr').format(d);
    return s[0].toUpperCase() + s.substring(1);
  }

  // --- Bugün: habit list ----------------------------------------------------
  static const bugunKart = 'Bugün';
  static const aliskanlikYok = 'Henüz alışkanlık yok.';
  static const aliskanliklaraGit = 'Alışkanlıklara git';
  static const planliDegil = 'Bugün planlı değil';
  static const son30Gun = 'Son 30 gün';
  static const isiSeridiAc = 'Son 30 günü göster';
  static const isiSeridiKapat = 'Son 30 günü gizle';
  static const ipucuDokun = 'Dokun: durumu değiştir';
  static const ipucuSayilabilir =
      'Dokun: durumu değiştir. Uzun bas: miktar gir';
  static String seriGun(int n) => '$n gün seri';
  static String seriNotu(String ad, int n) => '$ad: $n gün seri, devam!';

  /// Spoken/visible state of one day mark.
  static String durum(EntryStatus? s) => switch (s) {
    EntryStatus.done => 'yapıldı',
    EntryStatus.missed => 'yapılmadı',
    EntryStatus.skipped => 'atlandı',
    null => 'işaretlenmedi',
  };

  static const isiKismi = 'kısmi';

  /// TalkBack label for one cell, e.g. "Kitap, 12 Kasım: yapıldı".
  static String hucre(String ad, DateTime gun, String durumMetni) =>
      '$ad, ${DateFormat('d MMMM', 'tr').format(gun)}: $durumMetni';

  // --- Bugün: count entry ---------------------------------------------------
  static String gunlukHedef(int n) => 'Günlük hedef: $n';
  static const bugunkuMiktar = 'Bugünkü miktar';
  static const sifirIpucu = '0 girersen gün temizlenir.';
  static const hedefTamam = 'Hedef tamam';
  static const hedefDugme = 'Hedef';

  // --- Bugün: mood ----------------------------------------------------------
  static const moodSoru = 'Bugün nasılsın?';
  static const notTooltip = 'Not';
  static const notBaslik = 'Bugüne kısa not';
  static const notIpucu = 'Örn. yoğun bir gündü';
  static const moodYok =
      'Mood kaydı yok. Bugünü işaretle, çizgi buradan başlasın.';
  static String moodCizgi(int kayit) =>
      'Son 30 gün ruh hali çizgisi, $kayit kayıt';

  // --- Bugün: focus timer ---------------------------------------------------
  static const odak = 'Odak';
  static String gunUstUste(int n) => '$n gün üst üste';
  static String dakika(int m) => '$m dk';
  static String baslat(String tur) => '$tur başlat';
  static const bitir = 'Bitir';
  static const odakBugun = 'Bugün';
  static const odakSon7 = 'Son 7 gün';
  static const odakSeans = 'Seans';
  static const kisaSeans = '1 dakikadan kısa seans kaydedilmedi.';
  static String seansBitti(String tur, String sure) => '$tur bitti · $sure';
  static String kalanSure(String saat) => 'Kalan süre $saat';

  // --- Görevler -------------------------------------------------------------
  static const gorevlerBaslik = 'Görevler';
  static String bitenler(int n) => 'Bitenler ($n)';
  static const gorevEkleKisa = 'Görev';
  static const gorevYok = 'Henüz görev yok';
  static const ilkGorev = 'İlk görevini ekle, sadece başlık yeter.';
  static const gorevEkle = 'Görev ekle';
  static const grupGeciken = 'Geciken';
  static const grupBugun = 'Bugün';
  static const grupYarin = 'Yarın';
  static const grupBuHafta = 'Bu hafta';
  static const grupSonra = 'Sonra';
  static const grupTarihsiz = 'Tarihsiz';
  static const grupBitenler = 'Bitenler';
  static const temizle = 'Temizle';
  static const temizleBaslik = 'Biten görevler silinsin mi?';
  static const temizleGovde =
      'Tamamlanmış tüm görevler kalıcı olarak silinir. Bu geri alınamaz.';
  static const yeniGorev = 'Yeni görev';
  static const gorevDuzenle = 'Görevi düzenle';
  static const baslik = 'Başlık';
  static const baslikIpucu = 'Ne yapılacak?';
  static const oncelik = 'Öncelik';
  static const durumBaslik = 'Durum';
  static const tarih = 'Tarih';
  static const tarihBugun = 'Bugün';
  static const tarihYarin = 'Yarın';
  static const tarihsiz = 'Tarihsiz';
  static const tarihSec = 'Seç';
  static const gorevDuzenleIpucu = 'Uzun bas: düzenle';
  static const gorevBitti = 'bitti';
  static const gorevAcikDurum = 'bitmedi';
  static const yuksekOncelik = 'yüksek öncelik';
  static const yapiliyor = 'yapılıyor';

  static const vadeBugun = 'bugün';
  static const vadeYarin = 'yarın';
  static String vadeGecti(int gun) => '$gun gün geçti';

  // --- Görevler: Bugün'deki hızlı blok -------------------------------------
  static const haftaBaslik = 'Bu hafta';
  static String haftaBugunBitti(int n) => 'bugün $n bitti';
  static const haftaGorevYok = 'Bu hafta için görev yok.';
  static String haftaDisi(int n) =>
      '$n görev var ama hiçbirinin tarihi bu hafta değil.';
  static String dahaFazla(int n) => '+$n daha';
  static const hizliEkleIpucu = 'Bugüne görev ekle…';
  static const hizliEkleEtiket = 'Bugüne görev ekle';
  static const tumGorevler = 'Tüm görevler';
}
