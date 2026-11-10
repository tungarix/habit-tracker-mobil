// Wi-Fi eşleştirme istemcisi (docs/faz4/TASARIM.md A6). Saf Dart + dart:io.
//  - Sistem güven deposu YOK: sertifika yalnız QR'daki parmak iziyle (DER SHA-256) kabul edilir.
//  - Yalnız QR'daki adres/port; vekil yok, yönlendirme yok, her yanıt gövdesi sınırlı okunur.
//  - Jeton ve oturum anahtarı yalnız bellekte; hata olarak yalnız [WifiHatasi.kod] çıkar (ham istisna yok).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../../data/sync/sync_format.dart' show syncMaxFileBytes;
import '../guncelleme/sha256.dart';
import 'sozlesme.dart';

String parmakIziHesapla(List<int> der) =>
    base64Url.encode(sha256(der)).replaceAll('=', '');

class WifiIstemci {
  WifiIstemci(
    this.baglanti, {
    required this.cihazAdi,
    required this.uygulamaSurumu,
    this.baglanmaSuresi = baglanmaZamanAsimi,
    this.sessionSuresi = sessionZamanAsimi,
    this.getSuresi = getZamanAsimi,
    this.postSuresi = postZamanAsimi,
    this.adresDenetimi = ozelIpv4,
  });

  final EslestirmeBaglantisi baglanti;
  final String cihazAdi;
  final String uygulamaSurumu;
  final Duration baglanmaSuresi, sessionSuresi, getSuresi, postSuresi;

  /// Yalnız testte (loopback) gevşetilir; üretim her zaman [ozelIpv4].
  final bool Function(String) adresDenetimi;

  HttpClient? _c;
  bool _pinRed = false;
  String? _adres;
  String? _oturum;

  /// Oturum açıldı mı (jeton yandı, anahtar bellekte).
  bool get acik => _oturum != null;

  HttpClient get _istemci =>
      _c ??= (HttpClient(context: SecurityContext(withTrustedRoots: false))
        ..badCertificateCallback = (cert, host, port) {
          final tamam =
              port == baglanti.port &&
              baglanti.adresler.contains(host) &&
              parmakIziHesapla(cert.der) == baglanti.parmakIzi;
          if (!tamam) _pinRed = true;
          return tamam;
        }
        ..findProxy = ((_) => 'DIRECT')
        ..autoUncompress = false
        ..connectionTimeout = baglanmaSuresi
        ..userAgent = 'HabitTracker');

  Future<(int, Uint8List)> _gonder(
    String adres,
    String metot,
    String yol,
    String yetki,
    List<int>? govde,
    Duration sure,
    int enFazla,
  ) async {
    // Bağlanmadan önce yeniden doğrula: QR'dan gelse bile özel olmayan adrese gidilmez.
    if (!adresDenetimi(adres)) throw const WifiHatasi('adres_izinsiz');
    _pinRed = false;
    final HttpClientRequest istek;
    try {
      istek = await _istemci
          .openUrl(
            metot,
            Uri(scheme: 'https', host: adres, port: baglanti.port, path: yol),
          )
          .timeout(baglanmaSuresi);
    } on TimeoutException {
      throw const WifiHatasi('ag_ulasilamiyor');
    } on IOException {
      throw WifiHatasi(_pinRed ? 'parmak_izi_uyusmadi' : 'ag_ulasilamiyor');
    }
    try {
      istek.followRedirects = false;
      istek.persistentConnection = false;
      istek.headers.set(HttpHeaders.authorizationHeader, 'Bearer $yetki');
      if (govde != null) {
        istek.headers.contentType = ContentType(
          'application',
          'json',
          charset: 'utf-8',
        );
        istek.contentLength = govde.length;
        istek.add(govde);
      }
      final yanit = await istek.close().timeout(sure);
      if (yanit.isRedirect) {
        unawaited(yanit.drain<void>().catchError((_) {}));
        throw const WifiHatasi('yanit_bozuk');
      }
      final okunacak = yanit.statusCode == 200 ? enFazla : hataGovdeEnFazla;
      if (yanit.contentLength > okunacak) throw const WifiHatasi('yanit_bozuk');
      final tampon = BytesBuilder(copy: false);
      await yanit.timeout(sure).forEach((parca) {
        tampon.add(parca);
        if (tampon.length > okunacak) throw const WifiHatasi('yanit_bozuk');
      });
      return (yanit.statusCode, tampon.takeBytes());
    } on WifiHatasi {
      rethrow;
    } on TimeoutException {
      throw const WifiHatasi('zaman_asimi');
    } on IOException {
      throw WifiHatasi(_pinRed ? 'parmak_izi_uyusmadi' : 'ag_ulasilamiyor');
    }
  }

  Uint8List _basari((int, Uint8List) y) {
    if (y.$1 == 200) return y.$2;
    throw WifiHatasi(hataKoduCoz(y.$2));
  }

  /// `POST /v1/session`: jetonu yakar, oturum anahtarını alır. Adresler sırayla denenir.
  Future<OturumYaniti> oturumAc() async {
    final govde = oturumIstegiBayt(ad: cihazAdi, surum: uygulamaSurumu);
    WifiHatasi son = const WifiHatasi('ag_ulasilamiyor');
    for (final a in baglanti.adresler) {
      try {
        final y = await _gonder(
          a,
          'POST',
          '/v1/session',
          baglanti.jeton,
          govde,
          sessionSuresi,
          sessionYanitEnFazla,
        );
        final o = oturumYanitiCoz(_basari(y));
        _adres = a;
        _oturum = o.oturum;
        return o;
      } on WifiHatasi catch (e) {
        // Parmak izi, ret, süre: sıradaki adrese geçilmez.
        if (e.kod != 'ag_ulasilamiyor') rethrow;
        son = e;
      }
    }
    throw son;
  }

  /// `GET /v1/state`: masaüstünün `.habitsync` baytları (doğrulama çağıranın `parseSync`'idir).
  Future<Uint8List> durumAl() async => _basari(
    await _gonder(
      _adres!,
      'GET',
      '/v1/state',
      _oturum!,
      null,
      getSuresi,
      syncMaxFileBytes,
    ),
  );

  /// `POST /v1/state`: telefonun tam durumunu yollar, masaüstünün birleştirme raporunu döner.
  Future<MasaustuRaporu> durumGonder(List<int> bayt) async {
    if (bayt.length > syncMaxFileBytes) throw const WifiHatasi('senkron_bozuk');
    return sonucYanitiCoz(
      _basari(
        await _gonder(
          _adres!,
          'POST',
          '/v1/state',
          _oturum!,
          bayt,
          postSuresi,
          sessionYanitEnFazla,
        ),
      ),
    );
  }

  /// `POST /v1/end`: elinden geleni yapar, asla hata fırlatmaz. Sonra bağlantıyı ve anahtarı bırakır.
  Future<void> bitir(String neden) async {
    final a = _adres, o = _oturum;
    if (a != null && o != null) {
      try {
        await _gonder(
          a,
          'POST',
          '/v1/end',
          o,
          utf8.encode(jsonEncode({'reason': neden})),
          baglanmaSuresi,
          hataGovdeEnFazla,
        );
      } catch (_) {
        // Masaüstü zaten kapanmış ya da ulaşılamıyor olabilir.
      }
    }
    kapat();
  }

  void kapat() {
    _oturum = null;
    _adres = null;
    _c?.close(force: true);
    _c = null;
  }
}
