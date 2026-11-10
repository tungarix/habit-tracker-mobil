// Ağ katmanı testleri. NOT: sertifika parmak izi KABUL yolu (gerçek TLS sunucusu) burada denenmez;
// test sertifikası üretimi bu oturumda engellendi (bkz. docs/faz4/rapor-mobil-istemci.md).
import 'dart:io';

import 'package:aktenak_habit_tracker/platform/wifi/istemci.dart';
import 'package:aktenak_habit_tracker/platform/wifi/sozlesme.dart';
import 'package:flutter_test/flutter_test.dart';

EslestirmeBaglantisi baglanti(List<String> adresler, int port) =>
    EslestirmeBaglantisi(
      adresler: adresler,
      port: port,
      parmakIzi: 'A' * 43,
      jeton: 'ab' * 16,
      bitis: DateTime.now().add(const Duration(minutes: 3)),
      ad: 'PC',
    );

WifiIstemci istemci(EslestirmeBaglantisi b, {bool loopback = true}) =>
    WifiIstemci(
      b,
      cihazAdi: 'Test',
      uygulamaSurumu: '0.0.0',
      baglanmaSuresi: const Duration(milliseconds: 600),
      adresDenetimi: loopback ? (a) => a == '127.0.0.1' : ozelIpv4,
    );

Future<void> kodBekle(Future<Object?> Function() f, String kod) => expectLater(
  f(),
  throwsA(isA<WifiHatasi>().having((e) => e.kod, 'kod', kod)),
);

void main() {
  test('özel olmayan adrese hiç bağlanılmaz (adres_izinsiz)', () async {
    final sunucu = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    var baglanan = 0;
    sunucu.listen((s) {
      baglanan++;
      s.destroy();
    });
    addTearDown(sunucu.close);
    // Üretim denetimi: loopback özel değildir.
    final i = istemci(baglanti(['127.0.0.1'], sunucu.port), loopback: false);
    await kodBekle(i.oturumAc, 'adres_izinsiz');
    expect(baglanan, 0);
    expect(i.acik, isFalse);
  });

  test('kapalı port: ag_ulasilamiyor, oturum açılmaz', () async {
    final gecici = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final port = gecici.port;
    await gecici.close();
    final i = istemci(baglanti(['127.0.0.1'], port));
    await kodBekle(i.oturumAc, 'ag_ulasilamiyor');
    expect(i.acik, isFalse);
  });

  test(
    'TLS konuşmayan sunucu: istisna metni sızmaz, kod ag_ulasilamiyor',
    () async {
      final sunucu = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      sunucu.listen((r) => r.response.close());
      addTearDown(() => sunucu.close(force: true));
      final i = istemci(baglanti(['127.0.0.1'], sunucu.port));
      await kodBekle(i.oturumAc, 'ag_ulasilamiyor');
    },
  );

  test('sessiz sunucu (el sıkışma gelmez): bağlanma süresi dolunca ag_ulasilamiyor', () async {
    final sunucu = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    final tutulan = <Socket>[];
    sunucu.listen(tutulan.add);
    addTearDown(() async {
      for (final s in tutulan) {
        s.destroy();
      }
      await sunucu.close();
    });
    final i = istemci(baglanti(['127.0.0.1'], sunucu.port));
    await kodBekle(i.oturumAc, 'ag_ulasilamiyor');
  });

  test(
    'bitir oturum yokken sessizce biter, kapat tekrar çağrılabilir',
    () async {
      final i = istemci(baglanti(['127.0.0.1'], 50000));
      await i.bitir('cancel');
      i.kapat();
      expect(i.acik, isFalse);
    },
  );
}
