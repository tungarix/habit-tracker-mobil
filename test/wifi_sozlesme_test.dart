import 'dart:convert';
import 'dart:io';

import 'package:aktenak_habit_tracker/platform/wifi/istemci.dart';
import 'package:aktenak_habit_tracker/platform/wifi/sozlesme.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter_test/flutter_test.dart';

final _f = 'A' * 43;
final _t = 'ab' * 16;

String qr({
  String v = '1',
  String a = '192.168.1.20,10.0.0.5',
  String p = '51734',
  String? f,
  String? t,
  String e = '1783000000',
  String n = 'ARDA-PC',
  String ek = '',
}) => 'habitsync://p?v=$v&a=$a&p=$p&f=${f ?? _f}&t=${t ?? _t}&e=$e&n=$n$ek';

void kod(String metin, String beklenen) => expect(
  () => qrCoz(metin),
  throwsA(isA<WifiHatasi>().having((e) => e.kod, 'kod', beklenen)),
);

void main() {
  group('qrCoz', () {
    test('geçerli QR çözülür', () {
      final b = qrCoz(qr());
      expect(b.adresler, ['192.168.1.20', '10.0.0.5']);
      expect(b.port, 51734);
      expect(b.parmakIzi, _f);
      expect(b.jeton, _t);
      expect(b.ad, 'ARDA-PC');
      expect(b.bitis.millisecondsSinceEpoch, 1783000000 * 1000);
    });

    test('bilinmeyen anahtar yok sayılır, ad yüzde kodlu olabilir', () {
      final b = qrCoz(qr(n: 'Ev%20PC', ek: '&x=1'));
      expect(b.ad, 'Ev PC');
    });

    test('geçersiz biçimler reddedilir', () {
      kod('', 'qr_gecersiz');
      kod('https://p?v=1', 'qr_gecersiz');
      kod(qr().replaceFirst('habitsync://p?', 'habitsync://x?'), 'qr_gecersiz');
      kod(qr().replaceFirst('p?', 'p/yol?'), 'qr_gecersiz');
      kod('${qr()}#parca', 'qr_gecersiz');
      kod(qr(ek: '&t=$_t'), 'qr_gecersiz'); // çift anahtar
      kod(qr(f: 'A' * 44), 'qr_gecersiz');
      kod(qr(f: 'A' * 42), 'qr_gecersiz');
      kod(qr(t: 'AB' * 16), 'qr_gecersiz'); // büyük harf hex değil
      kod(qr(t: 'ab' * 15), 'qr_gecersiz');
      kod(qr(p: '80'), 'qr_gecersiz');
      kod(qr(p: '70000'), 'qr_gecersiz');
      kod(qr(e: 'x'), 'qr_gecersiz');
      kod(qr(v: '0'), 'qr_gecersiz');
      kod(qr(a: '192.168.1.20,192.168.1.20'), 'qr_gecersiz');
      kod(
        qr(a: '192.168.1.1,192.168.1.2,192.168.1.3,192.168.1.4'),
        'qr_gecersiz',
      );
      kod(qr(a: '192.168.01.20'), 'qr_gecersiz');
      kod(qr(a: '192.168.1'), 'qr_gecersiz');
      kod(qr(a: '[::1]'), 'qr_gecersiz');
      kod('${qr()}${'x' * 400}', 'qr_gecersiz');
      kod('habitsync://kul@p?v=1', 'qr_gecersiz');
    });

    test('sürüm büyükse protokol_surumu, genel adres adres_izinsiz', () {
      kod(qr(v: '2'), 'protokol_surumu');
      kod(qr(a: '8.8.8.8'), 'adres_izinsiz');
      kod(qr(a: '192.168.1.20,8.8.8.8'), 'adres_izinsiz');
      kod(qr(a: '127.0.0.1'), 'adres_izinsiz');
      kod(qr(a: '100.64.0.1'), 'adres_izinsiz');
      kod(qr(a: '0.0.0.0'), 'adres_izinsiz');
    });

    test('ad: bidi/kontrol karakterleri atılır, 40 karaktere kısaltılır', () {
      final kotu = 'A${String.fromCharCode(0x202e)}B${String.fromCharCode(7)}C';
      expect(adTemizle(kotu), 'ABC');
      expect(adTemizle('x' * 90).length, 40);
    });

    test('süre uyarısı 120 sn hoşgörülü', () {
      final b = qrCoz(qr(e: '1000'));
      final bitis = b.bitis;
      expect(
        b.suresiDolmusOlabilir(bitis.add(const Duration(seconds: 100))),
        isFalse,
      );
      expect(
        b.suresiDolmusOlabilir(bitis.add(const Duration(seconds: 121))),
        isTrue,
      );
    });
  });

  test('ozelIpv4 aralıkları', () {
    for (final ok in [
      '10.1.2.3',
      '172.16.0.1',
      '172.31.255.255',
      '192.168.0.1',
      '169.254.1.1',
    ]) {
      expect(ozelIpv4(ok), isTrue, reason: ok);
    }
    for (final yok in [
      '172.15.0.1',
      '172.32.0.1',
      '192.169.0.1',
      '11.0.0.1',
      '256.1.1.1',
      '1.2.3',
      '1.2.3.4.5',
      '010.0.0.1',
      'a.b.c.d',
      '224.0.0.1',
      '',
    ]) {
      expect(ozelIpv4(yok), isFalse, reason: yok);
    }
  });

  group('yanıt şemaları', () {
    List<int> j(Object o) => utf8.encode(jsonEncode(o));
    final oturum = 'S' * 43;

    test('oturum yanıtı', () {
      final o = oturumYanitiCoz(
        j({
          'protocol': 1,
          'session': oturum,
          'server': {'name': 'PC'},
          'remaining_s': 500,
        }),
      );
      expect(o.oturum, oturum);
      expect(o.sunucuAdi, 'PC');
      expect(o.kalanSn, 500);
      for (final kotu in [
        {'protocol': 2, 'session': oturum, 'server': {}},
        {'protocol': 1, 'session': 'kisa', 'server': {}},
        {'protocol': 1, 'session': oturum},
      ]) {
        expect(() => oturumYanitiCoz(j(kotu)), throwsA(isA<WifiHatasi>()));
      }
      expect(
        () => oturumYanitiCoz(utf8.encode('{')),
        throwsA(isA<WifiHatasi>()),
      );
      expect(
        () => oturumYanitiCoz(utf8.encode('[]')),
        throwsA(isA<WifiHatasi>()),
      );
    });

    test('hata gövdesi yalnız bilinen kodu geçirir', () {
      expect(hataKoduCoz(j({'error': 'reddedildi'})), 'reddedildi');
      expect(hataKoduCoz(j({'error': 'rastgele_kod'})), 'yanit_bozuk');
      expect(hataKoduCoz(utf8.encode('<html>')), 'yanit_bozuk');
    });

    test('sonuç raporu toplanır', () {
      Map<String, Object> s(int a, int u, int d) => {
        'added': a,
        'updated': u,
        'deleted': d,
        'skipped': 0,
      };
      final r = sonucYanitiCoz(
        j({
          'result': 'merged',
          'report': {
            'habit': s(1, 0, 0),
            'entry': s(2, 1, 0),
            'mood': s(0, 0, 0),
            'task': s(0, 0, 3),
            'session': s(0, 0, 0),
            'setting': s(0, 1, 0),
            'adopted': 0,
          },
        }),
      );
      expect((r.eklenen, r.guncellenen, r.silinen), (3, 2, 3));
      expect(
        () => sonucYanitiCoz(j({'result': 'merged', 'report': {}})),
        throwsA(isA<WifiHatasi>()),
      );
      expect(
        () => sonucYanitiCoz(j({'result': 'x'})),
        throwsA(isA<WifiHatasi>()),
      );
    });
  });

  test('her hata kodunun Türkçe metni var, ham istisna sızmaz', () {
    final genel = Metin.wifiHata('bilinmeyen_kod_xyz');
    const genelOlabilir = {
      'yok',
      'metot',
      'sira_hatali',
      'uzunluk_gerekli',
      'tur_hatali',
      'uygulama_hatasi',
    };
    for (final k in [...sunucuKodlari, ...istemciKodlari]) {
      final m = Metin.wifiHata(k);
      expect(m, isNot(contains('Exception')), reason: k);
      if (!genelOlabilir.contains(k)) expect(m, isNot(genel), reason: k);
    }
  });

  test('parmak izi: DER SHA-256, base64url dolgusuz 43 karakter', () {
    final p = parmakIziHesapla(List<int>.filled(10, 7));
    expect(p, matches(RegExp(r'^[A-Za-z0-9_-]{43}$')));
    expect(parmakIziHesapla(List<int>.filled(10, 8)), isNot(p));
  });

  test('manifest: CAMERA var, kamera zorunlu değil, düz HTTP kapalı', () {
    final m = File('android/app/src/main/AndroidManifest.xml')
        .readAsStringSync();
    expect(m, contains('android.permission.CAMERA'));
    expect(
      RegExp(
        r'<uses-feature\s+android:name="android.hardware.camera"\s+android:required="false"',
      ).hasMatch(m),
      isTrue,
    );
    expect(m, contains('android:usesCleartextTraffic="false"'));
  });
}
