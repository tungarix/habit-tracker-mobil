// Wi-Fi eşleştirme sözleşmesinin SAF kısmı (docs/faz4/TASARIM.md A2-A5): QR metni, özel IPv4 denetimi,
// ad temizleme, hata kodları ve sunucu yanıtlarının şema doğrulaması. Flutter ve ağ yok.
//
// Not: tasarım bu dosyanın masaüstüyle ortak (`esitle.ps1` ile kopyalanan) olmasını öngörür. Masaüstü
// tarafı yazılana kadar mobilin kendi dosyasıdır; sabitler ve kurallar tasarımdaki tabloyla birebirdir.
import 'dart:convert';

const wifiProtokolSurumu = 1;
const qrEnFazlaUzunluk = 400;
const adresEnFazla = 3;
const adEnFazla = 40;
const sessionGovdeEnFazla = 1024;

/// QR süresi geçtikten sonra uyarı vermeden önceki saat farkı hoşgörüsü (A6).
const qrHosgorusuSn = 120;

/// Ağ yanıtı sınırları (istemci tarafı).
const hataGovdeEnFazla = 4096;
const sessionYanitEnFazla = 4096;

/// İstemci zaman aşımları (A3 tablosu).
const baglanmaZamanAsimi = Duration(seconds: 4);
const sessionZamanAsimi = Duration(seconds: 75);
const getZamanAsimi = Duration(seconds: 30);
const postZamanAsimi = Duration(seconds: 90);

/// Kullanıcıya gösterilen kısa kod. Sunucunun gönderebildikleri [sunucuKodlari], gerisi yerelde üretilir.
const sunucuKodlari = {
  'istek_bozuk',
  'protokol_surumu',
  'senkron_bozuk',
  'senkron_surumu',
  'yetkisiz',
  'reddedildi',
  'yok',
  'metot',
  'sure_doldu',
  'mesgul',
  'iptal',
  'sira_hatali',
  'uzunluk_gerekli',
  'cok_buyuk',
  'tur_hatali',
  'cok_istek',
};

const istemciKodlari = {
  'qr_gecersiz',
  'adres_izinsiz',
  'wifi_degil',
  'ag_ulasilamiyor',
  'parmak_izi_uyusmadi',
  'zaman_asimi',
  'yanit_bozuk',
  'kamera_izni',
  'yedek_alinamadi',
  'senkron_bozuk_yerel',
  'uygulama_hatasi',
};

/// [kod] arayüzde yerelleştirilir; ham istisna metni buraya asla girmez.
class WifiHatasi implements Exception {
  const WifiHatasi(this.kod);
  final String kod;
  @override
  String toString() => 'WifiHatasi($kod)';
}

/// QR'daki bağlantı bilgisi.
class EslestirmeBaglantisi {
  const EslestirmeBaglantisi({
    required this.adresler,
    required this.port,
    required this.parmakIzi,
    required this.jeton,
    required this.bitis,
    required this.ad,
  });

  final List<String> adresler;
  final int port;
  final String parmakIzi;
  final String jeton;
  final DateTime bitis;
  final String ad;

  /// Yerel saatle süre geçtiyse (hoşgörüyle) true. Yalnız uyarıdır.
  bool suresiDolmusOlabilir(DateTime simdi) =>
      simdi.isAfter(bitis.add(const Duration(seconds: qrHosgorusuSn)));
}

final _ipv4 = RegExp(
  r'^(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})\.(0|[1-9]\d{0,2})$',
);
final _parmak = RegExp(r'^[A-Za-z0-9_-]{43}$');
final _jeton = RegExp(r'^[0-9a-f]{32}$');
final _sayi = RegExp(r'^\d{1,12}$');
final _oturum = RegExp(r'^[A-Za-z0-9_-]{43}$');
// Kontrol karakterleri ve çift yönlü yazı denetimleri (bidi).
final _yasakKar = RegExp(
  r'[\u0000-\u001f\u007f-\u009f\u200e\u200f\u202a-\u202e\u2066-\u2069]',
);

/// Noktalı dörtlü IPv4 mü ve özel aralıkta mı (10/8, 172.16/12, 192.168/16, 169.254/16).
/// Loopback, genel, CGNAT (100.64/10), çok noktalı yayın ve baştaki sıfır: hayır.
bool ozelIpv4(String s) {
  final m = _ipv4.firstMatch(s);
  if (m == null) return false;
  final o = [for (var i = 1; i <= 4; i++) int.parse(m[i]!)];
  if (o.any((x) => x > 255)) return false;
  return o[0] == 10 ||
      (o[0] == 172 && o[1] >= 16 && o[1] <= 31) ||
      (o[0] == 192 && o[1] == 168) ||
      (o[0] == 169 && o[1] == 254);
}

/// Gösterim adı: yasak karakterler atılır, kırpılır, en çok [adEnFazla] karakter. Güvenlik kararı vermez.
String adTemizle(String s) {
  final t = s.replaceAll(_yasakKar, '').trim();
  final r = t.runes.take(adEnFazla).toList();
  return String.fromCharCodes(r).trim();
}

/// `habitsync://p?v=1&a=..&p=..&f=..&t=..&e=..&n=..` -> bağlantı. Kural dışı her şey `qr_gecersiz`
/// (adres özel değilse `adres_izinsiz`); sürüm büyükse `protokol_surumu`.
EslestirmeBaglantisi qrCoz(String metin) {
  final s = metin.trim();
  if (s.isEmpty || s.length > qrEnFazlaUzunluk) {
    throw const WifiHatasi('qr_gecersiz');
  }
  final Uri u;
  try {
    u = Uri.parse(s);
  } on FormatException {
    throw const WifiHatasi('qr_gecersiz');
  }
  if (u.scheme != 'habitsync' ||
      u.host != 'p' ||
      u.hasPort ||
      u.userInfo.isNotEmpty ||
      u.path.isNotEmpty ||
      u.hasFragment ||
      !u.hasQuery) {
    throw const WifiHatasi('qr_gecersiz');
  }
  final Map<String, List<String>> q;
  try {
    q = u.queryParametersAll;
  } on FormatException {
    throw const WifiHatasi('qr_gecersiz');
  }
  // Aynı anahtar iki kez: ret (belirsizlik).
  if (q.values.any((l) => l.length != 1)) throw const WifiHatasi('qr_gecersiz');
  String? al(String k) => q[k]?.first;

  final v = al('v');
  if (v == null || !_sayi.hasMatch(v)) throw const WifiHatasi('qr_gecersiz');
  final surum = int.parse(v);
  if (surum > wifiProtokolSurumu) throw const WifiHatasi('protokol_surumu');
  if (surum != wifiProtokolSurumu) {
    throw const WifiHatasi('qr_gecersiz');
  }

  final a = al('a');
  if (a == null || a.isEmpty) throw const WifiHatasi('qr_gecersiz');
  final adresler = a.split(',');
  if (adresler.length > adresEnFazla ||
      adresler.toSet().length != adresler.length) {
    throw const WifiHatasi('qr_gecersiz');
  }
  for (final x in adresler) {
    if (!_ipv4.hasMatch(x)) throw const WifiHatasi('qr_gecersiz');
  }
  if (!adresler.every(ozelIpv4)) throw const WifiHatasi('adres_izinsiz');

  final p = al('p');
  if (p == null || !_sayi.hasMatch(p)) throw const WifiHatasi('qr_gecersiz');
  final port = int.parse(p);
  if (port < 49152 || port > 65535) throw const WifiHatasi('qr_gecersiz');

  final f = al('f');
  if (f == null || !_parmak.hasMatch(f)) throw const WifiHatasi('qr_gecersiz');
  final t = al('t');
  if (t == null || !_jeton.hasMatch(t)) throw const WifiHatasi('qr_gecersiz');
  final e = al('e');
  if (e == null || !_sayi.hasMatch(e)) throw const WifiHatasi('qr_gecersiz');
  final bitis = DateTime.fromMillisecondsSinceEpoch(int.parse(e) * 1000);

  return EslestirmeBaglantisi(
    adresler: adresler,
    port: port,
    parmakIzi: f,
    jeton: t,
    bitis: bitis,
    ad: adTemizle(al('n') ?? ''),
  );
}

/// `POST /v1/session` gövdesi.
List<int> oturumIstegiBayt({required String ad, required String surum}) {
  final b = utf8.encode(
    jsonEncode({
      'protocol': wifiProtokolSurumu,
      'client': {
        'name': adTemizle(ad),
        'app': 'habit-tracker-mobile',
        'version': surum,
      },
      'sync_version': 1,
    }),
  );
  assert(b.length <= sessionGovdeEnFazla);
  return b;
}

class OturumYaniti {
  const OturumYaniti({
    required this.oturum,
    required this.sunucuAdi,
    required this.kalanSn,
  });
  final String oturum;
  final String sunucuAdi;
  final int? kalanSn;
}

Map<String, dynamic> _nesne(List<int> bayt) {
  try {
    final j = jsonDecode(utf8.decode(bayt));
    if (j is Map<String, dynamic>) return j;
  } on FormatException {
    // aşağıda
  }
  throw const WifiHatasi('yanit_bozuk');
}

OturumYaniti oturumYanitiCoz(List<int> bayt) {
  final j = _nesne(bayt);
  final o = j['session'], s = j['server'];
  if (j['protocol'] != wifiProtokolSurumu ||
      o is! String ||
      !_oturum.hasMatch(o) ||
      s is! Map) {
    throw const WifiHatasi('yanit_bozuk');
  }
  final ad = s['name'];
  final kalan = j['remaining_s'];
  return OturumYaniti(
    oturum: o,
    sunucuAdi: ad is String ? adTemizle(ad) : '',
    kalanSn: kalan is int ? kalan : null,
  );
}

/// Hata gövdesi `{"error":"kod"}`. Bilinmeyen kod ya da bozuk gövde: `yanit_bozuk`.
String hataKoduCoz(List<int> bayt) {
  try {
    final j = _nesne(bayt);
    final k = j['error'];
    if (k is String && sunucuKodlari.contains(k)) return k;
  } on WifiHatasi {
    // aşağıda
  }
  return 'yanit_bozuk';
}

/// Masaüstünün birleştirme raporu: yalnız gösterilen toplamlar.
class MasaustuRaporu {
  const MasaustuRaporu({
    required this.eklenen,
    required this.guncellenen,
    required this.silinen,
  });
  final int eklenen, guncellenen, silinen;
}

const _raporTurleri = ['habit', 'entry', 'mood', 'task', 'session', 'setting'];

MasaustuRaporu sonucYanitiCoz(List<int> bayt) {
  final j = _nesne(bayt);
  final r = j['report'];
  if (j['result'] != 'merged' || r is! Map) {
    throw const WifiHatasi('yanit_bozuk');
  }
  var e = 0, g = 0, s = 0;
  for (final t in _raporTurleri) {
    final c = r[t];
    if (c is! Map) throw const WifiHatasi('yanit_bozuk');
    final a = c['added'], u = c['updated'], d = c['deleted'];
    if (a is! int || u is! int || d is! int || a < 0 || u < 0 || d < 0) {
      throw const WifiHatasi('yanit_bozuk');
    }
    e += a;
    g += u;
    s += d;
  }
  return MasaustuRaporu(eklenen: e, guncellenen: g, silinen: s);
}
