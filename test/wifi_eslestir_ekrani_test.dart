import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_export.dart';
import 'package:aktenak_habit_tracker/features/settings/settings_screen.dart';
import 'package:aktenak_habit_tracker/features/settings/wifi_eslestir_ekrani.dart';
import 'package:aktenak_habit_tracker/platform/kopru.dart';
import 'package:aktenak_habit_tracker/platform/wifi/istemci.dart';
import 'package:aktenak_habit_tracker/platform/wifi/qr_tarayici.dart';
import 'package:aktenak_habit_tracker/platform/wifi/sozlesme.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

final _gecerliQr =
    'habitsync://p?v=1&a=192.168.1.20&p=51734&f=${'A' * 43}&t=${'ab' * 16}'
    '&e=${DateTime.now().millisecondsSinceEpoch ~/ 1000 + 180}&n=ARDA-PC';

class SahteIstemci extends WifiIstemci {
  SahteIstemci(super.baglanti, this.k)
    : super(cihazAdi: 'Test', uygulamaSurumu: '0.0.0');
  final SahneKaydi k;

  @override
  Future<OturumYaniti> oturumAc() async {
    k.olaylar.add('oturum');
    if (k.oturumHatasi != null) throw WifiHatasi(k.oturumHatasi!);
    return const OturumYaniti(oturum: 'x', sunucuAdi: 'ARDA-PC', kalanSn: 500);
  }

  @override
  Future<Uint8List> durumAl() async {
    k.olaylar.add('al');
    return k.gelen!;
  }

  @override
  Future<MasaustuRaporu> durumGonder(List<int> bayt) async {
    k.olaylar.add('gonder');
    k.gonderilen = utf8.decode(bayt);
    if (k.gonderHatasi != null) throw WifiHatasi(k.gonderHatasi!);
    return const MasaustuRaporu(eklenen: 1, guncellenen: 0, silinen: 0);
  }

  @override
  Future<void> bitir(String neden) async => k.olaylar.add('bitir:$neden');

  @override
  void kapat() => k.olaylar.add('kapat');
}

class SahneKaydi {
  final olaylar = <String>[];
  String? oturumHatasi, gonderHatasi, gonderilen;
  Uint8List? gelen;
  int istemciSayisi = 0;
  void Function(String)? bulundu;
  VoidCallback? izinYok;
}

class SahteKopruWifi implements Kopru {
  SahteKopruWifi(this.tur, {this.wifi});
  String tur;
  final bool? wifi;
  int ayarAcildi = 0;
  @override
  Future<String> agTuru() async => tur;
  @override
  Future<bool> wifiBagli() async => wifi ?? tur == 'wifi';
  @override
  Future<void> uygulamaAyarlariniAc() async => ayarAcildi++;
  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  Future<Uint8List> masaustuDosyasi(List<String> adlar) async {
    final d = await bellekDb();
    for (final a in adlar) {
      await aliskanlikEkle(d, a);
    }
    return Uint8List.fromList(utf8.encode(await exportSync(d)));
  }

  Future<void> ac(
    WidgetTester tester,
    AppDatabase db,
    SahneKaydi k,
    Directory yedek, {
    Kopru? kopru,
    bool ayarlardan = false,
  }) async {
    telefonBoyutu(tester, yukseklik: 1000);
    await tester.pumpWidget(
      ProviderScope(
        // ignore: argument_type_not_assignable
        overrides: [
          databaseProvider.overrideWithValue(db),
          kopruProvider.overrideWithValue(kopru),
          wifiYedekKlasoruProvider.overrideWith((ref) async => yedek),
          wifiIstemciProvider.overrideWithValue((b) {
            k.istemciSayisi++;
            return SahteIstemci(b, k);
          }),
          qrTarayiciProvider.overrideWithValue((
            context, {
            required bulundu,
            required izinYok,
            required hata,
          }) {
            k.bulundu = bulundu;
            k.izinYok = izinYok;
            return const SizedBox.expand(key: Key('sahte-tarayici'));
          }),
        ],
        child: MaterialApp(
          home: ayarlardan
              ? const SettingsScreen()
              : const WifiEslestirEkrani(),
        ),
      ),
    );
    await bekle(tester);
  }

  Directory gecici() {
    final d = Directory.systemTemp.createTempSync('wifi_yedek');
    addTearDown(() => d.deleteSync(recursive: true));
    return d;
  }

  /// QR'ı "okutur" ve Onay 1'i verir.
  Future<void> qrOkutVeBaglan(
    WidgetTester tester,
    SahneKaydi k, {
    String? qr,
  }) async {
    await tester.tap(find.text(Metin.wifiQrTara));
    await bekle(tester);
    k.bulundu!(qr ?? _gecerliQr);
    await bekle(tester);
    expect(find.text(Metin.wifiOnay1Baslik), findsOneWidget);
    await tester.tap(find.text(Metin.wifiBaglan));
    await bekle(tester, 16);
  }

  testWidgets('Ayarlar\'daki girişten açılır', (tester) async {
    final db = await bellekDb();
    await ac(tester, db, SahneKaydi(), gecici(), ayarlardan: true);
    await tester.ensureVisible(find.text(Metin.wifiGiris));
    await tester.tap(find.text(Metin.wifiGiris));
    await bekle(tester);
    expect(find.text(Metin.wifiQrTara), findsOneWidget);
    expect(find.text(Metin.wifiBaglantiYapistir), findsOneWidget);
    await temizle(tester);
  });

  testWidgets('Onay 1 öncesi ağ isteği yok; Vazgeç hiçbir şey yapmaz', (
    tester,
  ) async {
    final db = await bellekDb();
    final k = SahneKaydi();
    await ac(tester, db, k, gecici());
    // Karar: kamera (ve izin istemi) yalnız "QR'ı tara"ya basınca; ekran açılınca tarayıcı yok.
    expect(find.byKey(const Key('sahte-tarayici')), findsNothing);
    await tester.tap(find.text(Metin.wifiQrTara));
    await bekle(tester);
    expect(find.byKey(const Key('sahte-tarayici')), findsOneWidget);
    k.bulundu!(_gecerliQr);
    await bekle(tester);
    expect(find.textContaining('ARDA-PC'), findsOneWidget);
    expect(find.textContaining('192.168.1.20'), findsOneWidget);
    expect(k.istemciSayisi, 0);
    await tester.tap(find.text(Metin.wifiVazgec));
    await bekle(tester);
    expect(k.istemciSayisi, 0);
    expect(find.text(Metin.wifiVazgecildi), findsOneWidget);
    await temizle(tester);
  });

  testWidgets(
    'tam akış: özet sayıları, yedek, birleştirme, telefon verisi gönderilir',
    (tester) async {
      final db = await bellekDb();
      await aliskanlikEkle(db, 'Telefonda');
      final k = SahneKaydi()..gelen = await masaustuDosyasi(['Kitap', 'Su']);
      final yedek = gecici();
      await ac(tester, db, k, yedek, kopru: SahteKopruWifi('wifi'));
      await qrOkutVeBaglan(tester, k);

      // Özet: kuru çalıştırma, veri henüz değişmedi.
      expect(find.text(Metin.wifiOzetBaslik), findsOneWidget);
      expect(find.text('2'), findsOneWidget); // eklenecek
      expect(find.text('0'), findsNWidgets(2)); // güncellenecek, silinecek
      expect(await db.getAllHabits(), hasLength(1));
      expect(k.olaylar, ['oturum', 'al']);

      await tester.tap(find.text(Metin.wifiBirlestirGonder));
      await bekle(tester, 24);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await bekle(tester, 12);

      expect(
        (await db.getAllHabits()).map((h) => h.name),
        containsAll(['Telefonda', 'Kitap', 'Su']),
      );
      final doc = jsonDecode(k.gonderilen!) as Map<String, dynamic>;
      expect(
        (doc['habits'] as List).map((h) => (h as Map)['name']),
        containsAll(['Telefonda', 'Kitap', 'Su']),
      );
      expect(k.olaylar, ['oturum', 'al', 'gonder', 'kapat']);
      expect(find.text(Metin.wifiBitti), findsOneWidget);
      expect(find.text(Metin.wifiBilgisayarSonuc(1, 0, 0)), findsOneWidget);
      // Birleştirmeden önce yerel yedek yazıldı.
      final dosyalar = yedek
          .listSync()
          .map((e) => e.path)
          .where((p) => p.contains('aktenak-sync-'))
          .toList();
      expect(dosyalar, hasLength(1));
      expect(dosyalar.single, endsWith('.json'));
      await temizle(tester);
    },
  );

  testWidgets('özet ekranında Vazgeç: veri değişmez, oturum kapatılır', (
    tester,
  ) async {
    final db = await bellekDb();
    final k = SahneKaydi()..gelen = await masaustuDosyasi(['Kitap']);
    await ac(tester, db, k, gecici());
    await qrOkutVeBaglan(tester, k);
    await tester.tap(find.text(Metin.wifiVazgec));
    await bekle(tester);
    expect(await db.getAllHabits(), isEmpty);
    expect(k.olaylar, contains('bitir:cancel'));
    expect(k.olaylar, isNot(contains('gonder')));
    expect(find.text(Metin.wifiVazgecildi), findsOneWidget);
    await temizle(tester);
  });

  testWidgets('değişiklik yoksa bunu söyler ve yine de gönderir', (
    tester,
  ) async {
    final db = await bellekDb();
    final k = SahneKaydi()..gelen = await masaustuDosyasi([]);
    await ac(tester, db, k, gecici());
    await qrOkutVeBaglan(tester, k);
    expect(find.text(Metin.wifiDegisiklikYok), findsOneWidget);
    expect(find.text(Metin.wifiGonder), findsOneWidget);
    await temizle(tester);
  });

  testWidgets(
    'masaüstü reddederse Türkçe mesaj, telefonda hiçbir şey değişmez',
    (tester) async {
      final db = await bellekDb();
      final k = SahneKaydi()..oturumHatasi = 'reddedildi';
      await ac(tester, db, k, gecici());
      await qrOkutVeBaglan(tester, k);
      expect(find.text(Metin.wifiHata('reddedildi')), findsOneWidget);
      expect(find.text(Metin.wifiHataBaslik), findsOneWidget);
      expect(await db.getAllHabits(), isEmpty);
      await temizle(tester);
    },
  );

  testWidgets(
    'bilgisayar POST sonrası reddederse: "yarım kaldı" açıkça yazılır',
    (tester) async {
      final db = await bellekDb();
      final k = SahneKaydi()
        ..gelen = await masaustuDosyasi(['Kitap'])
        ..gonderHatasi = 'reddedildi';
      await ac(tester, db, k, gecici());
      await qrOkutVeBaglan(tester, k);
      await tester.tap(find.text(Metin.wifiBirlestirGonder));
      await bekle(tester, 24);
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await bekle(tester, 12);
      expect(find.text(Metin.wifiYarimBaslik), findsOneWidget);
      expect(find.text(Metin.wifiYarimTelefon), findsOneWidget);
      expect(find.text(Metin.wifiHata('reddedildi')), findsOneWidget);
      expect((await db.getAllHabits()).single.name, 'Kitap');
      await temizle(tester);
    },
  );

  for (final kod in ['zaman_asimi', 'ag_ulasilamiyor', 'yanit_bozuk']) {
    testWidgets(
      'POST yanıtsız biterse ($kod): "bilgisayar değişmedi" denmez, sonuç belirsiz yazılır',
      (tester) async {
        final db = await bellekDb();
        final k = SahneKaydi()
          ..gelen = await masaustuDosyasi(['Kitap'])
          ..gonderHatasi = kod;
        await ac(tester, db, k, gecici());
        await qrOkutVeBaglan(tester, k);
        await tester.tap(find.text(Metin.wifiBirlestirGonder));
        await bekle(tester, 24);
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 100)),
        );
        await bekle(tester, 12);
        expect(find.text(Metin.wifiBelirsizBaslik), findsOneWidget);
        expect(find.text(Metin.wifiBelirsizTelefon), findsOneWidget);
        expect(find.text(Metin.wifiYarimTelefon), findsNothing);
        expect(find.textContaining('bilgisayar değişmedi'), findsNothing);
        await temizle(tester);
      },
    );
  }

  testWidgets('bozuk masaüstü verisi: önizleme ve birleştirme yok', (
    tester,
  ) async {
    final db = await bellekDb();
    final k = SahneKaydi()
      ..gelen = Uint8List.fromList(utf8.encode('{"format":"baska"}'));
    await ac(tester, db, k, gecici());
    await qrOkutVeBaglan(tester, k);
    expect(find.text(Metin.wifiHata('senkron_bozuk_yerel')), findsOneWidget);
    expect(k.olaylar, contains('bitir:cancel'));
    expect(await db.getAllHabits(), isEmpty);
    await temizle(tester);
  });

  testWidgets('geçersiz yapıştırılan bağlantı: istemci hiç kurulmaz', (
    tester,
  ) async {
    final db = await bellekDb();
    final k = SahneKaydi();
    await ac(tester, db, k, gecici());
    await tester.tap(find.text(Metin.wifiBaglantiYapistir));
    await bekle(tester);
    await tester.enterText(find.byType(TextField), 'https://example.com/x');
    await tester.tap(find.text(Metin.wifiBaglantiTamam));
    await bekle(tester);
    expect(find.text(Metin.wifiHata('qr_gecersiz')), findsOneWidget);
    expect(k.istemciSayisi, 0);
    await temizle(tester);
  });

  testWidgets('geçerli yapıştırılan bağlantı Onay 1\'e gider', (tester) async {
    final db = await bellekDb();
    final k = SahneKaydi();
    await ac(tester, db, k, gecici());
    await tester.tap(find.text(Metin.wifiBaglantiYapistir));
    await bekle(tester);
    await tester.enterText(find.byType(TextField), _gecerliQr);
    await tester.tap(find.text(Metin.wifiBaglantiTamam));
    await bekle(tester);
    expect(find.text(Metin.wifiOnay1Baslik), findsOneWidget);
    expect(k.istemciSayisi, 0);
    await temizle(tester);
  });

  testWidgets('Wi-Fi yoksa tarama başlamaz', (tester) async {
    final db = await bellekDb();
    final k = SahneKaydi();
    await ac(tester, db, k, gecici(), kopru: SahteKopruWifi('mobil'));
    await tester.tap(find.text(Metin.wifiQrTara));
    await bekle(tester);
    expect(find.text(Metin.wifiHata('wifi_degil')), findsOneWidget);
    expect(find.byKey(const Key('sahte-tarayici')), findsNothing);
    await temizle(tester);
  });

  testWidgets('ücretli (metered) işaretli Wi-Fi engellenmez', (tester) async {
    final db = await bellekDb();
    final k = SahneKaydi();
    // agTuru 'mobil' döner (ücretli), ama etkin ağ Wi-Fi.
    await ac(tester, db, k, gecici(), kopru: SahteKopruWifi('mobil', wifi: true));
    await tester.tap(find.text(Metin.wifiQrTara));
    await bekle(tester);
    expect(find.text(Metin.wifiHata('wifi_degil')), findsNothing);
    expect(find.byKey(const Key('sahte-tarayici')), findsOneWidget);
    await temizle(tester);
  });

  testWidgets('kamera izni reddi: açıklama, ayarlar yolu, yapıştırma açık', (
    tester,
  ) async {
    final db = await bellekDb();
    final k = SahneKaydi();
    final kopru = SahteKopruWifi('wifi');
    await ac(tester, db, k, gecici(), kopru: kopru);
    await tester.tap(find.text(Metin.wifiQrTara));
    await bekle(tester);
    k.izinYok!();
    await bekle(tester);
    expect(find.text(Metin.wifiIzinBaslik), findsOneWidget);
    expect(find.text(Metin.wifiIzinAciklama), findsOneWidget);
    expect(find.text(Metin.wifiBaglantiYapistir), findsOneWidget);
    await tester.tap(find.text(Metin.wifiAyarlariAc));
    await bekle(tester);
    expect(kopru.ayarAcildi, 1);
    await tester.tap(find.text(Metin.wifiYenidenDene));
    await bekle(tester);
    expect(find.byKey(const Key('sahte-tarayici')), findsOneWidget);
    expect(k.istemciSayisi, 0);
    await temizle(tester);
  });

  for (final koyu in [false, true]) {
    testWidgets(
      'erişilebilirlik: 48 dp, etiketli hedefler, kontrast (${koyu ? "koyu" : "açık"})',
      (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = koyu
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        final db = await bellekDb();
        final k = SahneKaydi()..gelen = await masaustuDosyasi(['Kitap']);
        await ac(tester, db, k, gecici());

        Future<void> denetle() async {
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }

        await denetle(); // giriş
        await tester.tap(find.text(Metin.wifiQrTara));
        await bekle(tester);
        k.izinYok!();
        await bekle(tester);
        await denetle(); // izin yok
        await tester.tap(find.text(Metin.wifiYenidenDene));
        await bekle(tester);
        k.bulundu!(_gecerliQr);
        await bekle(tester);
        await denetle(); // Onay 1
        await tester.tap(find.text(Metin.wifiBaglan));
        await bekle(tester, 16);
        await denetle(); // özet
        handle.dispose();
        await temizle(tester);
      },
    );
  }

  testWidgets('%200 yazı boyutunda özet taşmaz', (tester) async {
    final db = await bellekDb();
    final k = SahneKaydi()..gelen = await masaustuDosyasi(['Kitap']);
    telefonBoyutu(tester, yukseklik: 2400);
    await tester.pumpWidget(
      ProviderScope(
        // ignore: argument_type_not_assignable
        overrides: [
          databaseProvider.overrideWithValue(db),
          wifiIstemciProvider.overrideWithValue((b) => SahteIstemci(b, k)),
          wifiYedekKlasoruProvider.overrideWith((ref) async => gecici()),
          qrTarayiciProvider.overrideWithValue((
            context, {
            required bulundu,
            required izinYok,
            required hata,
          }) {
            k.bulundu = bulundu;
            return const SizedBox.expand();
          }),
        ],
        child: MaterialApp(
          builder: (c, w) => MediaQuery(
            data: MediaQuery.of(c)
                .copyWith(textScaler: const TextScaler.linear(2)),
            child: w!,
          ),
          home: const WifiEslestirEkrani(),
        ),
      ),
    );
    await bekle(tester);
    await qrOkutVeBaglan(tester, k);
    expect(find.text(Metin.wifiOzetBaslik), findsOneWidget);
    expect(tester.takeException(), isNull);
    await temizle(tester);
  });
}
