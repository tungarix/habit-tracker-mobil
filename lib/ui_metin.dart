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

  // --- Aylık, İstatistik, Alışkanlıklar, Ayarlar ----------------------------

  // Shared
  static const gun = 'gün';
  static const herGun = 'Her gün';
  static String hata(String e) => 'Hata: $e';

  static const aylar = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  static const _gunAdlari = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];

  // Monthly
  static const bugunDon = 'Bugüne dön';
  static const oncekiAy = 'Önceki ay';
  static const sonrakiAy = 'Sonraki ay';
  static const mood = 'Mood';
  static const buAyMoodYok = 'Bu ay mood kaydı yok';
  static const alsizBaslik = 'Henüz alışkanlık yok';
  static const alsizAciklama =
      'İlk alışkanlığını ekleyerek tabloyu doldurmaya başla.';
  static const alisanlikEkle = 'Alışkanlık ekle';

  static String _gunAy(DateTime d) => '${d.day} ${aylar[d.month - 1]}';

  /// Spoken label of a day-number header, e.g. "12 Kasım Perşembe, bugün".
  static String aylikGunBasligi(DateTime day, bool isToday) =>
      '${_gunAy(day)} ${_gunAdlari[day.weekday - 1]}${isToday ? ', bugün' : ''}';

  /// Spoken label of one grid cell, e.g. "Kitap, 12 Kasım: yapıldı".
  static String hucreEtiketi({
    required String habitName,
    required DateTime day,
    required EntryStatus? status,
    required int? value,
    required int? target,
    required bool isFuture,
    required bool beforeCreated,
    required bool scheduled,
  }) {
    final String state;
    if (status != null) {
      state = switch (status) {
        EntryStatus.done => 'yapıldı',
        EntryStatus.missed => 'yapılmadı',
        EntryStatus.skipped => 'atlandı',
      };
    } else if (value != null && target != null && value > 0) {
      state = '$value / $target';
    } else if (isFuture) {
      state = 'henüz gelmedi';
    } else if (beforeCreated) {
      state = 'alışkanlık başlamadan önce';
    } else if (!scheduled) {
      state = 'planlı gün değil, işaretlenmedi';
    } else {
      state = 'işaretlenmedi';
    }
    return '$habitName, ${_gunAy(day)}: $state';
  }

  static String moodGrafigiEtiketi(int n) =>
      'Mood grafiği, bu ay $n gün için kayıt var';

  // Habits
  static const alisanliklariYonet = 'Alışkanlıkları yönet';
  static const alisanlikFab = 'Alışkanlık';
  static const aktifYok = 'Henüz aktif alışkanlık yok.';
  static const arsiv = 'Arşiv';
  static const duzenle = 'Düzenle';
  static const arsivle = 'Arşivle';
  static const silNokta = 'Sil…';
  static const geriYukle = 'Geri yükle';
  static String menuAc(String name) => '$name için seçenekler';
  static const kaliciSilBaslik = 'Kalıcı olarak sil?';
  static String kaliciSilAciklama(String name, bool offerArchive) =>
      '"$name" ve tüm kayıtları silinecek. Bu geri alınamaz.'
      '${offerArchive ? '\n\nGeçmişi saklamak istiyorsan silmek yerine Arşivle.' : ''}';

  static const alisanligiDuzenle = 'Alışkanlığı düzenle';
  static const yeniAlisanlik = 'Yeni alışkanlık';
  static const ad = 'Ad';
  static const adIpucu = 'Örn. Sabah egzersizi';
  static const aciklama = 'Açıklama (opsiyonel)';
  static const tur = 'Tür';
  static const gunlukHedefAlan = 'Günlük hedef';
  static const gunlukHedefIpucu = 'Örn. 10000 (adım) veya 90 (dakika)';
  static const gunlukHedefYardim = 'Hedefe ulaşıldığında gün ✓ sayılır.';
  static const kategori = 'Kategori';
  static const renk = 'Renk';
  static const ikon = 'İkon';
  static const planliGunler = 'Planlı günler';
  static const seciliGunlerde = 'Seçili günlerde';

  // Order follows kHabitColors / kHabitIcons in shared/habit_style.dart.
  static const _renkAdlari = [
    'Yeşil',
    'Mavi',
    'Mor',
    'Turuncu',
    'Kırmızı',
    'Turkuaz',
    'Çivit mavisi',
    'Pembe',
    'Kahverengi',
    'Gri mavi',
  ];
  static const _ikonAdlari = [
    'Spor',
    'Meditasyon',
    'Kitap',
    'Su',
    'Koşu',
    'Uyku',
    'Kod',
    'Çizim',
    'Müzik',
    'Çiçek',
    'Yemek',
    'Temizlik',
    'Birikim',
    'Sigarayı bırakma',
    'Kalp',
    'Okul',
    'Bisiklet',
    'Evcil hayvan',
    'Spa',
    'İş',
  ];
  static String renkAdi(int i) =>
      i < _renkAdlari.length ? _renkAdlari[i] : 'Renk ${i + 1}';
  static String ikonAdi(int i) =>
      i < _ikonAdlari.length ? _ikonAdlari[i] : 'İkon ${i + 1}';

  // Stats
  static const istatistik = 'İstatistik';
  static const istatistikAlt = 'Serilerin, oranların ve mood ilişkin';
  static const alisanliklar = 'Alışkanlıklar';
  static const moodTamamlama = 'Mood ↔ Tamamlama';
  static const toplamIsaret = 'Toplam ✓';
  static const mevcutSeri = 'Mevcut seri';
  static const enUzunSeri = 'En uzun seri';
  static const enUzun = 'En uzun';
  static const buAy = 'Bu ay';
  static const tamamlama = 'Tamamlama';
  static const moodYetersiz =
      'Yeterli veri yok — birkaç gün mood işaretle,\n'
      'mood ile tamamlama ilişkisi burada belirecek.';
  static String moodAciklama(int n) =>
      'O günkü mood\'a göre ortalama tamamlama oranı ($n gün)';
  static String seritEtiketi(
    String name, {
    required int done,
    required int missed,
    required int skipped,
  }) =>
      '$name, son 30 gün: $done gün yapıldı, $missed gün yapılmadı, $skipped gün atlandı';
  static String moodCubuguEtiketi(String label, int? pct, int count) =>
      pct == null
      ? '$label: veri yok'
      : '$label: ortalama tamamlama yüzde $pct, $count gün';

  // Settings
  static const ayarlarBaslik = 'Yedek & Ayarlar';
  static const veriYalnizBuTelefonda =
      'Verilerin yalnızca bu telefonda. Başka bir cihaza taşımak için '
      'dışa aktar, oradan içe aktar.';
  static const disaAktar = 'Dışa aktar';
  static const disaAktarAciklama =
      'Tüm alışkanlık ve kayıtları bir .json dosyası olarak paylaş.';
  static const iceAktar = 'İçe aktar';
  static const iceAktarAciklama =
      'Bir .json yedeğinden geri yükle (birleştir veya değiştir).';
  static String disaAktarmaHata(String e) => 'Dışa aktarım başarısız: $e';
  static String iceAktarmaHata(String e) => 'İçe aktarım başarısız: $e';
  static String iceAktarildi(int h, int e, int m, int t, int s) =>
      'İçe aktarıldı: $h alışkanlık, $e kayıt, $m mood, $t görev, $s seans.';
  static const iceAktarModuBaslik = 'İçe aktarma modu';
  static const iceAktarModuAciklama =
      'Mevcut verilerle nasıl birleştirilsin?\n\n'
      '• Birleştir: aynı alışkanlık/görev güncellenir, farklı olanlar yeni olarak '
      'eklenir. Aynı gün+alışkanlık kaydının üzerine yazılır; aynı odak seansı '
      'tekrar eklenmez.\n'
      '• Tamamen değiştir: bu telefondaki tüm veriler silinir, yerine yedek konur. '
      'Geri alınamaz.';
  static const birlestir = 'Birleştir';
  static const tamamenDegistir = 'Tamamen değiştir';

  // Bilgisayarla senkron (.habitsync)
  static const senkronBaslik = 'Bilgisayarla senkron';
  static const senkronDisaAktar = 'Bilgisayar için dışa aktar';
  static const senkronDisaAktarAciklama =
      'Tüm veriyi bir .habitsync dosyasına yaz, bilgisayarda aç.';
  static const senkronIceAktar = 'Bilgisayardan içe aktar';
  static const senkronIceAktarAciklama =
      'Bilgisayarın .habitsync dosyasını bu verilerle birleştir. '
      'Aynı kayıtta son değişiklik kazanır.';
  static const senkronOnayBaslik = 'Senkron dosyası';
  static String senkronOnayIcerik(int h, int e, int t, int s, int silinen) =>
      'Dosyada $h alışkanlık, $e işaret, $t görev, $s odak seansı var.\n\n'
      'Bu telefondaki verilerle birleştirilir: aynı kayıtta son değişiklik '
      'kazanır, hiçbir kayıt ikilenmez.\n\n'
      '${silinen == 0 ? 'Dosyada silinmiş olarak işaretli kayıt yok.' : 'Dosyada silinmiş olarak işaretli $silinen kayıt var; bunlar bu telefonda varsa silinir.'}';
  static const senkronIceAktarDugme = 'İçe aktar';
  static String senkronGecersiz(String e) => '$e Hiçbir şey değişmedi.';

  // Bilgisayarla eşitle (QR + Wi-Fi)
  static const wifiGiris = 'Bilgisayarla eşitle';
  static const wifiGirisAciklama =
      'Aynı Wi-Fi\'daki bilgisayarla QR kodu okutarak iki yönlü eşitle.';
  static const wifiBaslik = 'Bilgisayarla eşitle';
  static const wifiAnlatim =
      'Bilgisayarda Habit Tracker\'ı aç, "Telefonla eşleştir (Wi-Fi)" de. '
      'Çıkan QR kodu burada okut. İkisi de aynı Wi-Fi\'da olmalı.\n\n'
      'Kamera yalnız QR kodu okumak için açılır; görüntü kaydedilmez ve hiçbir yere gönderilmez.';
  static const wifiQrTara = 'QR\'ı tara';
  static const wifiBaglantiYapistir = 'Bağlantıyı yapıştır';
  static const wifiBaglantiAlani = 'Eşleştirme bağlantısı';
  static const wifiBaglantiIpucu = 'habitsync://p?...';
  static const wifiBaglantiTamam = 'Devam';
  static const wifiTarayiciEtiket =
      'Kamera önizlemesi, bilgisayardaki QR kodu çerçeveye getir';
  static const wifiTaramaYonerge = 'Bilgisayardaki QR kodu çerçeveye getir.';
  static const wifiIzinBaslik = 'Kamera izni verilmedi';
  static const wifiIzinAciklama =
      'QR kodu okumak için kamera gerekir. Kamera yalnız bu iş için açılır. '
      'İstersen izni uygulama ayarlarından ver ya da bağlantıyı elle yapıştır.';
  static const wifiKameraAcilamadi =
      'Kamera açılamadı. Bağlantıyı elle yapıştırabilirsin.';
  static const wifiYenidenDene = 'Yeniden dene';
  static const wifiAyarlariAc = 'Uygulama ayarlarını aç';
  static const wifiOnay1Baslik = 'Bu bilgisayara bağlanılsın mı?';
  static String wifiOnay1(
    String ad,
    List<String> adresler,
    bool suresiDolmus,
  ) =>
      '${ad.isEmpty ? 'Bilinmeyen bilgisayar' : '«$ad»'} · ${adresler.join(', ')}\n\n'
      'Bu, şu an ekranına baktığın bilgisayar mı? Bağlanınca bilgisayar da senden onay isteyecek.'
      '${suresiDolmus ? '\n\nQR\'ın süresi dolmuş olabilir.' : ''}';
  static const wifiBaglan = 'Bağlan';
  static const wifiBaglaniyor =
      'Bilgisayara bağlanılıyor. Bilgisayarda "evet" demen gerekebilir.';
  static const wifiVeriAliniyor =
      'Bilgisayarın verisi alınıyor ve kontrol ediliyor.';
  static const wifiUygulaniyor =
      'Birleştiriliyor ve bilgisayara gönderiliyor. Lütfen bekle.';
  static const wifiOzetBaslik = 'Bilgisayardan gelecekler';
  static const wifiEklenecek = 'Eklenecek';
  static const wifiGuncellenecek = 'Güncellenecek';
  static const wifiSilinecek = 'Silinecek';
  static const wifiDegisiklikYok =
      'Bilgisayardan gelecek değişiklik yok. Telefondaki veri bilgisayara gönderilecek.';
  static const wifiGonderSonra =
      'Birleştirilince telefondaki tüm veri bilgisayara gönderilir; bilgisayar da senden ayrıca onay ister. '
      'Birleştirmeden önce telefondaki verinin yedeği alınır.';
  static const wifiSilmeUyari =
      'Dikkat: bazı kayıtlar silinecek (bir alışkanlık silinirse işaretleri de gider).';
  static const wifiCokSilme =
      'Bu eşleştirmede çok kayıt silinecek; yedek alınıp öyle uygulanır. Emin değilsen Vazgeç.';
  static const wifiBirlestirGonder = 'Birleştir ve gönder';
  static const wifiGonder = 'Gönder';
  static const wifiVazgec = 'Vazgeç';
  static String wifiTur(String tur, int n) => switch (tur) {
    'habit' => '$n alışkanlık',
    'entry' => '$n işaret',
    'mood' => '$n ruh hali',
    'task' => '$n görev',
    'session' => '$n odak seansı',
    _ => '$n kayıt',
  };
  static const wifiBitti = 'Eşitleme tamamlandı';
  static String wifiTelefonSonuc(int e, int g, int s) =>
      'Telefon: $e eklendi, $g güncellendi, $s silindi.';
  static String wifiBilgisayarSonuc(int e, int g, int s) =>
      'Bilgisayar: $e eklendi, $g güncellendi, $s silindi.';
  static const wifiYarimBaslik = 'Yarım kaldı';
  static const wifiYarimTelefon =
      'Telefon güncellendi, ama bilgisayar değişmedi.';
  static const wifiBelirsizBaslik = 'Bilgisayarın sonucu belli değil';
  static const wifiBelirsizTelefon =
      'Telefon güncellendi. Yanıt gelmediği için bilgisayara ulaşıp ulaşmadığı belli değil. '
      'Bilgisayardaki pencere "tamamlandı" diyorsa iş bitmiştir; emin değilsen eşleştirmeyi yeniden yap, veri bozulmaz.';

  /// Telefon verisi gönderildikten sonra yanıt alınamadı: bilgisayar birleştirmiş olabilir.
  static bool wifiSonucBelirsizMi(String? kod) =>
      kod == 'zaman_asimi' || kod == 'ag_ulasilamiyor' || kod == 'yanit_bozuk';
  static const wifiTamam = 'Tamam';
  static const wifiHataBaslik = 'Eşitlenemedi';
  static const wifiIptalEkran = 'Ekran kapandığı için eşleştirme iptal edildi.';
  static const wifiVazgecildi = 'Vazgeçildi. Hiçbir şey değişmedi.';
  static String wifiHata(String kod) => switch (kod) {
    'istek_bozuk' => 'Bilgisayarla anlaşılamadı. İki uygulamayı da güncelle.',
    'protokol_surumu' => 'Uygulama sürümleri uyumsuz. Telefondaki ve bilgisayardaki uygulamayı güncelle.',
    'senkron_bozuk' => 'Dosya geçersiz; hiçbir şey değişmedi.',
    'senkron_bozuk_yerel' =>
      'Bilgisayarın verisi geçersiz; hiçbir şey değişmedi.',
    'senkron_surumu' => 'Dosya daha yeni bir sürümden. Uygulamayı güncelle.',
    'yetkisiz' => 'Bağlantı geçersiz ya da kullanılmış. Bilgisayarda yeniden "Telefonla eşleştir"e bas.',
    'reddedildi' => 'Bilgisayar eşleştirmeyi reddetti.',
    'sure_doldu' => 'Süre doldu.',
    'mesgul' || 'cok_istek' => 'Bilgisayar meşgul, biraz sonra dene.',
    'iptal' => 'Bilgisayarda eşleştirme iptal edildi.',
    'cok_buyuk' => 'Veri çok büyük; dosya ile senkronu dene.',
    'qr_gecersiz' => 'Bu QR kod Habit Tracker eşleştirmesine ait değil.',
    'adres_izinsiz' =>
      'Bu bağlantı özel bir ağ adresi değil; güvenlik için bağlanılmadı.',
    'wifi_degil' =>
      'Önce Wi-Fi\'a bağlan; mobil veriyle bilgisayara ulaşılamaz.',
    'ag_ulasilamiyor' =>
      'Bilgisayara ulaşılamadı. İkisi de aynı Wi-Fi\'da mı? Misafir ağlar cihazları birbirinden '
          'ayırabilir. Windows Güvenlik Duvarı\'nda "Özel ağlar" iznini de kontrol et.',
    'parmak_izi_uyusmadi' => 'Güvenlik uyarısı: bağlanılan cihaz QR\'daki cihaz değil. Bağlantı kesildi, hiçbir veri gönderilmedi.',
    'zaman_asimi' => 'Süre doldu; bilgisayardan yanıt gelmedi.',
    'yanit_bozuk' =>
      'Bilgisayarın yanıtı anlaşılamadı. İki uygulamayı da güncelle.',
    'kamera_izni' => 'Kamera izni verilmedi.',
    'yedek_alinamadi' =>
      'Yedek alınamadı, bu yüzden birleştirilmedi. Hiçbir şey değişmedi.',
    _ =>
      'Beklenmeyen bir sorun oldu. Hiçbir şey değişmemiş olabilir; kontrol et.',
  };


  static const otomatikYedekBaslik = 'Otomatik yedek';
  static const otomatikYedek = 'Günlük yedek';
  static const otomatikYedekAciklama =
      'Uygulama açılınca günde bir kez alınır, son 14 gün saklanır.';
  static const otomatikYedekYok = 'Henüz yedek yok, ilk yedek bugün alınır.';
  static String sonYedek(String zaman) => 'Son yedek: $zaman';
  static const yedekUyari =
      'Bu yedekler telefon dışına çıkmaz, ara sıra dışa aktar. '
      'Uygulamayı kaldırırsan bu yedekler de silinir.';

  static const gorunumBaslik = 'Görünüm ve gün';
  static const tema = 'Tema';
  static const temaSistem = 'Sistem';
  static const temaAcik = 'Açık';
  static const temaKoyu = 'Koyu';
  static const gunBaslangici = 'Gün başlangıç saati';
  static String gunBaslangiciSesli(int h) => 'saat $h';
  static String gunBaslangiciAciklama(String hh) =>
      'Saat $hh\'dan önce yapılan işaretler önceki güne yazılır.';
  static const aksamHatirlaticisi = 'Akşam hatırlatıcısı';
  static const hatirlaticiKapali = 'Kapalı.';
  static String hatirlaticiAcik(String hh) =>
      'Bekleyen alışkanlık varsa saat $hh\'da bildirim gösterir.';
  static const hatirlaticiIzinYok =
      'Bildirim izni kapalı, hatırlatıcı gelmeyecek. Telefon ayarlarından '
      'bu uygulamanın bildirimlerine izin ver.';
  static String hatirlaticiSesli(int h) => 'saat $h';

  // --- Güncelleme -----------------------------------------------------------
  static const guncellemeBaslik = 'Güncelleme';
  static const guncellemeDenetle = 'Güncellemeleri denetle';
  static const guncellemeDenetleAciklama =
      'Günde en çok bir kez GitHub\'a sorar. Kapalıyken internet kullanılmaz.';
  static const guncellemeYalnizWifi = 'Yalnız Wi-Fi\'da indir';
  static const guncellemeSimdiDenetle = 'Şimdi denetle';
  static const guncellemeDenetleniyor = 'Denetleniyor...';
  static const guncellemeGuncel = 'Uygulama güncel.';
  static const guncellemeHic = 'Henüz denetlenmedi.';
  static String guncellemeHazir(String s) => 'Yeni sürüm hazır: $s';
  static const guncellemeIndirKur = 'İndir ve kur';
  static const guncellemeIndiriliyor = 'İndiriliyor ve doğrulanıyor...';
  static const guncellemeKurulumAcildi =
      'Doğrulandı. Android\'in kurulum penceresinde onayla.';
  /// PackageInstaller status code (never 0 = success).
  static String guncellemeKurulumSonucu(int durum) => switch (durum) {
    3 => 'Kurulum iptal edildi.',
    6 => 'Telefonda yeterli yer yok, kurulmadı.',
    7 => 'Yeni sürümün imzası kurulu uygulamayla uyuşmuyor, kurulmadı.',
    _ => 'Kurulum tamamlanamadı (kod $durum).',
  };
  static const guncellemeIlkBaslik = 'Güncellemeler denetlensin mi?';
  static const guncellemeIlkGovde =
      'Uygulama günde en çok bir kez GitHub\'a bağlanıp yeni sürüm olup '
      'olmadığına bakabilir. Kişisel veri gönderilmez. İndirme yalnız '
      'Wi-Fi\'da yapılır. İstersen Ayarlar\'dan değiştirebilirsin.';
  static const guncellemeIlkHayir = 'Hayır';
  static const guncellemeIlkEvet = 'Evet, denetle';
  static const guncellemeMobilBaslik = 'Mobil veriyle indirilsin mi?';
  static const guncellemeMobilGovde =
      'Şu an Wi-Fi\'da değilsin. Güncelleme dosyası yaklaşık 60 MB.';
  static const guncellemeMobilEvet = 'Mobil veriyle indir';
  static String guncellemeHata(String kod) => switch (kod) {
    'ag_yok' => 'İnternet bağlantısı yok.',
    'wifi_gerek' => 'İndirme Wi-Fi\'ı bekliyor.',
    'izin_yok' =>
      'Bu uygulamaya kurulum izni ver, sonra geri dönüp tekrar dene.',
    'ozet_uyusmuyor' || 'ozet_bulunamadi' =>
      'İndirilen dosya doğrulanamadı, kurulmadı.',
    'ag_hatasi' || 'limit' => 'İndirme tamamlanamadı, sonra tekrar dene.',
    _ => 'Güncelleme yapılamadı ($kod).',
  };
}
