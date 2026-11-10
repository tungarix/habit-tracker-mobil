import '../../core/enums.dart';

/// User-facing Turkish strings of the monthly / stats / habits / settings
/// screens. Kept in its own file for now; the merge folds it into
/// `lib/ui_metin.dart`.
class MetinB {
  MetinB._();

  // Shared
  static const iptal = 'İptal';
  static const kaydet = 'Kaydet';
  static const sil = 'Sil';
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
  static String gunBasligi(DateTime day, bool isToday) =>
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
  static const gunlukHedef = 'Günlük hedef';
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
  static const son30Gun = 'Son 30 gün';
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
  static String hatirlaticiSesli(int h) => 'saat $h';
}
