// Otomatik güncelleme: sürüm, release çözümleme, ağ (yerel sahte GitHub), doğrulama, durum kuralları.
// Rules are the same as Takvim 0.4.0's updater (adapted: repo, asset name, Settings table storage). No real network.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:aktenak_habit_tracker/platform/guncelleme/ag.dart';
import 'package:aktenak_habit_tracker/platform/guncelleme/guncelleyici.dart';
import 'package:aktenak_habit_tracker/platform/guncelleme/saf.dart';
import 'package:aktenak_habit_tracker/platform/guncelleme/ayarlar.dart';
import 'package:aktenak_habit_tracker/platform/guncelleme/sha256.dart';

const depo = 'tungarix/habit-tracker-mobil';
final yeniApk = Uint8List.fromList(List.generate(13000, (i) => (i * 31 + 7) % 256));

Map<String, Object?> release({Map<String, Object?> degis = const {}, String surum = '0.4.0'}) {
  const taban = 'https://github.com/tungarix/habit-tracker-mobil/releases/download';
  return {
    'tag_name': 'v$surum',
    'draft': false,
    'prerelease': false,
    'html_url': 'https://github.com/tungarix/habit-tracker-mobil/releases/tag/v$surum',
    'assets': <Object?>[
      <String, Object?>{'name': 'Habit-Tracker-$surum.apk', 'size': 58000000, 'browser_download_url': '$taban/v$surum/Habit-Tracker-$surum.apk'},
      <String, Object?>{'name': 'SHA256SUMS.txt', 'size': 90, 'browser_download_url': '$taban/v$surum/SHA256SUMS.txt'},
    ],
    ...degis,
  };
}

final h = 'a' * 64;

// Updater state lives in the Settings table; a file-backed database lets the tests "restart".
final _acik = <AppDatabase>[];
Future<GuncellemeAyarlari> ayarAc(File dosya) async {
  final db = AppDatabase.forTesting(NativeDatabase(File('${dosya.path}.sqlite')));
  _acik.add(db);
  return GuncellemeAyarlari.yukle(db);
}

/// Writes straight into the Settings table of [dosya]'s database (simulates a hand-edited value).
Future<void> ayarYaz(File dosya, String anahtar, String deger) async {
  final db = AppDatabase.forTesting(NativeDatabase(File('${dosya.path}.sqlite')));
  await db.setSetting(anahtar, deger);
  await db.close();
}

Future<String?> ayarOku(File dosya, String anahtar) async {
  final db = AppDatabase.forTesting(NativeDatabase(File('${dosya.path}.sqlite')));
  final d = await db.getSetting(anahtar);
  await db.close();
  return d;
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  tearDownAll(() async {
    for (final d in _acik) {
      await d.close();
    }
  });

  group('sürüm', () {
    test('sayısal karşılaştırma: 0.10.0 > 0.9.0, v öneki, eşit/eski teklif edilmez', () {
      expect(dahaYeniMi('0.10.0', '0.9.0'), isTrue);
      expect(dahaYeniMi('v0.4.0', '0.3.0'), isTrue);
      expect(dahaYeniMi('1.0.0', '0.99.99'), isTrue);
      expect(dahaYeniMi('0.3.0', '0.3.0'), isFalse);
      expect(dahaYeniMi('0.2.9', '0.3.0'), isFalse);
    });

    test('tanınmayan sürüm teklif edilmez', () {
      for (final k in ['0.4', '0.4.0-beta', 'bir.iki.uc', '', '1.2.3.4', null, 5]) {
        expect(surumCoz(k), isNull, reason: '$k');
        expect(dahaYeniMi('$k', '0.3.0'), isFalse);
      }
    });
  });

  group('release çözümleme', () {
    test('geçerli release çözülür', () {
      final y = yayinCoz(release(), depo)!;
      expect((y.surum, y.apkBoyut, y.apkAdi), ('0.4.0', 58000000, 'Habit-Tracker-0.4.0.apk'));
      expect(y.apkUrl, endsWith('/Habit-Tracker-0.4.0.apk'));
    });

    test('taslak, ön sürüm, kararlı olmayan etiket, eksik varlık teklif edilmez', () {
      expect(yayinCoz(release(degis: {'draft': true}), depo), isNull);
      expect(yayinCoz(release(degis: {'prerelease': true}), depo), isNull);
      expect(yayinCoz(release(degis: {'tag_name': 'v0.4.0-rc1'}), depo), isNull);
      expect(yayinCoz(release(degis: {'assets': <Object?>[]}), depo), isNull);
      expect(yayinCoz(release(degis: {'assets': null}), depo), isNull);
      expect(yayinCoz([1, 2], depo), isNull);
      expect(yayinCoz('x', depo), isNull);
    });

    test('APK adı etiketle birebir uyuşmalı (Habit-Tracker-<sürüm>.apk); SHA256SUMS.txt şart', () {
      final r = release();
      (r['assets']! as List)[0] = {'name': 'Habit.apk', 'size': 5, 'browser_download_url': 'https://github.com/tungarix/habit-tracker-mobil/releases/download/v0.4.0/Habit.apk'};
      expect(yayinCoz(r, depo), isNull);
      final eski = release(surum: '0.3.0'); // etiket 0.4.0 ama APK adı 0.3.0
      expect(yayinCoz({...eski, 'tag_name': 'v0.4.0'}, depo), isNull);
      final r2 = release();
      (r2['assets']! as List).removeAt(1);
      expect(yayinCoz(r2, depo), isNull);
    });

    test('geçersiz boyut reddedilir', () {
      for (final b in <Object?>[0, -5, apkEnFazlaBayt + 1, '58', null, 1.5]) {
        final r = release();
        ((r['assets']! as List)[0] as Map)['size'] = b;
        expect(yayinCoz(r, depo), isNull, reason: '$b');
      }
    });

    test('izinsiz adres reddedilir; GitHub depolaması kabul edilir', () {
      const kotuler = [
        'http://github.com/tungarix/habit-tracker-mobil/releases/download/v0.4.0/Habit-Tracker-0.4.0.apk',
        'https://evil.example/Habit-Tracker-0.4.0.apk',
        'https://github.com/baskasi/depo/releases/download/v0.4.0/Habit-Tracker-0.4.0.apk',
        'https://user:pw@github.com/tungarix/habit-tracker-mobil/releases/download/v0.4.0/Habit-Tracker-0.4.0.apk',
        'https://github.com.evil.example/tungarix/habit-tracker-mobil/releases/download/v0.4.0/Habit-Tracker-0.4.0.apk',
        'file:///sdcard/Habit-Tracker-0.4.0.apk',
      ];
      for (final u in kotuler) {
        final r = release();
        ((r['assets']! as List)[0] as Map)['browser_download_url'] = u;
        expect(yayinCoz(r, depo), isNull, reason: u);
      }
      final r = release();
      ((r['assets']! as List)[0] as Map)['browser_download_url'] = 'https://objects.githubusercontent.com/x/Habit-Tracker-0.4.0.apk';
      expect(yayinCoz(r, depo), isNotNull);
    });

    test('aynı adlı ikinci varlık yok sayılır (ilk eşleşme)', () {
      final r = release();
      (r['assets']! as List).add({'name': 'Habit-Tracker-0.4.0.apk', 'size': 5, 'browser_download_url': 'https://evil.example/x'});
      expect(yayinCoz(r, depo)!.apkBoyut, 58000000);
    });
  });

  group('SHA256SUMS.txt', () {
    test('özet okunur', () {
      expect(ozetCoz('$h  Habit-Tracker-0.4.0.apk\n', 'Habit-Tracker-0.4.0.apk'), h);
      expect(ozetCoz('${h.toUpperCase()} *Habit-Tracker-0.4.0.apk', 'Habit-Tracker-0.4.0.apk'), h);
      expect(ozetCoz('${'b' * 64}  baska.txt\n$h  Habit-Tracker-0.4.0.apk\n', 'Habit-Tracker-0.4.0.apk'), h);
    });

    test('belirsiz özet null', () {
      for (final m in ['', 'bozuk', '$h  baska.apk', '${'a' * 63}  Habit-Tracker-0.4.0.apk', '${'z' * 64}  Habit-Tracker-0.4.0.apk', '$h  Habit-Tracker-0.4.0.apk\n${'b' * 64}  Habit-Tracker-0.4.0.apk']) {
        expect(ozetCoz(m, 'Habit-Tracker-0.4.0.apk'), isNull, reason: m);
      }
    });
  });

  group('SHA-256 akışlı', () {
    test('akışlı sonuç tek seferliyle aynı (blok sınırları dahil, parça boyutundan bağımsız)', () {
      for (final n in [0, 1, 55, 56, 57, 63, 64, 65, 119, 120, 128, 1000, 100000]) {
        final veri = List<int>.generate(n, (i) => (i * 7 + n) % 256);
        final beklenen = onaltilik(sha256(veri));
        for (final parca in [1, 3, 63, 64, 65, 4096]) {
          final a = Sha256Akis();
          for (var i = 0; i < veri.length; i += parca) {
            a.ekle(veri.sublist(i, i + parca > veri.length ? veri.length : i + parca));
          }
          expect(onaltilik(a.bitir()), beklenen, reason: 'n=$n parça=$parca');
        }
      }
    });

    test('bilinen vektör ve ikinci bitir hatası', () {
      expect(onaltilik(sha256(utf8.encode('abc'))), 'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad');
      final a = Sha256Akis()..bitir();
      expect(a.bitir, throwsStateError);
      expect(() => a.ekle([1]), throwsStateError);
    });
  });

  group('sahte GitHub', () {
    late HttpServer sunucu;
    late List<(String, Map<String, String>)> istekler;
    var durum = 200;
    Uint8List? apkGovde;
    var apkKes = false;
    var sonsuz = false;
    var gonderilen = 0;
    String? ozetMetni;
    String? yonlendir;
    var etag = '"v1"';
    String? govdeOzel;

    String adres([String yol = '']) => 'http://127.0.0.1:${sunucu.port}$yol';

    String json({String surum = '0.4.0', int? boyut}) => jsonEncode({
          'tag_name': 'v$surum',
          'draft': false,
          'prerelease': false,
          'html_url': adres('/sayfa'),
          'assets': [
            {'name': 'Habit-Tracker-$surum.apk', 'size': boyut ?? (apkGovde ?? yeniApk).length, 'browser_download_url': adres('/dl/Habit-Tracker-$surum.apk')},
            {'name': 'SHA256SUMS.txt', 'size': 90, 'browser_download_url': adres('/dl/SHA256SUMS.txt')},
          ],
        });

    setUp(() async {
      istekler = [];
      durum = 200;
      apkGovde = null;
      apkKes = false;
      sonsuz = false;
      gonderilen = 0;
      ozetMetni = null;
      yonlendir = null;
      etag = '"v1"';
      govdeOzel = null;
      sunucu = await HttpServer.bind('127.0.0.1', 0);
      sunucu.listen((r) async {
        final basliklar = <String, String>{};
        r.headers.forEach((ad, d) => basliklar[ad] = d.join(','));
        istekler.add((r.uri.path, basliklar));
        final y = r.response;
        final yol = r.uri.path;
        if (yol.endsWith('/releases/latest')) {
          if (durum != 200) {
            y.statusCode = durum;
          } else if (basliklar['if-none-match'] == etag) {
            y.statusCode = 304;
          } else {
            y.headers.set('etag', etag);
            y.write(govdeOzel ?? json());
          }
        } else if (yol == '/dl/Habit-Tracker-0.4.0.apk') {
          if (yonlendir != null) {
            y.statusCode = 302;
            y.headers.set('location', yonlendir!);
          } else if (sonsuz) {
            // Bildirdiğinden çok fazlasını yollayan sunucu: istemci keserse döngü hata ile biter.
            final parca = Uint8List(64 * 1024);
            try {
              // Yavaş akış (parça başına 10 ms): kesilmezse istemci tamamını okur ve sayaç tavana varır.
              while (gonderilen < 20 * 1024 * 1024) {
                y.add(parca);
                gonderilen += parca.length;
                await y.flush();
                await Future<void>.delayed(const Duration(milliseconds: 10));
              }
              await y.close();
            } on Object {
              // istemci bağlantıyı kapattı: beklenen
            }
            return;
          } else {
            final g = apkGovde ?? yeniApk;
            y.headers.contentLength = g.length;
            y.add(apkKes ? g.sublist(0, g.length ~/ 2) : g);
            if (apkKes) {
              // bildirilen uzunluğun altında kapatmak bağlantıyı koparır: istemci kesik akış görür
              try {
                await y.close();
              } on Object {
                // beklenen: "Content size below specified contentLength"
              }
              return;
            }
          }
        } else if (yol == '/dl/SHA256SUMS.txt') {
          y.write(ozetMetni ?? '${onaltilik(sha256(apkGovde ?? yeniApk))}  Habit-Tracker-0.4.0.apk\n');
        } else {
          y.statusCode = 404;
        }
        await y.close();
      });
    });

    tearDown(() async => sunucu.close(force: true));

    Ag ag() => Ag(depo: depo, surum: '0.3.0', apiTaban: adres(), ekSunucular: {'127.0.0.1'}, zamanAsimi: const Duration(seconds: 5));

    Future<Directory> gecici() async {
      final d = await Directory.systemTemp.createTemp('habit_gunc');
      addTearDown(() async {
        try {
          await d.delete(recursive: true);
        } on FileSystemException {
          // Windows tutamağı
        }
      });
      return d;
    }

    Future<Guncelleyici> hizmet({DateTime Function()? saat, String surum = '0.3.0'}) async {
      final d = await gecici();
      final ayarlar = await ayarAc(File('${d.path}/ayarlar'));
      return Guncelleyici(ayarlar: ayarlar, klasor: Directory('${d.path}/g'), surum: surum, ag: ag(), saat: saat);
    }

    test('son yayın okunur; başlıklar doğru, veri sızmıyor', () async {
      final (s, y, e) = await ag().sonYayin();
      expect((s, y?.surum, e), ('yeni', '0.4.0', '"v1"'));
      final (yol, b) = istekler.first;
      expect(yol, '/repos/$depo/releases/latest');
      expect(b['user-agent'], 'HabitTracker/0.3.0');
      expect(b.keys.toSet().intersection({'cookie', 'authorization'}), isEmpty);
    });

    test('ETag ile 304: değişmedi', () async {
      final a = ag();
      final (_, _, e) = await a.sonYayin();
      final (s, y, e2) = await a.sonYayin(e);
      expect((s, y, e2), ('degismedi', null, e));
    });

    test('404 teklif yok; 403/429 limit; 500 ağ hatası; bozuk JSON; dev gövde', () async {
      durum = 404;
      expect((await ag().sonYayin()).$1, 'yok');
      for (final k in [403, 429]) {
        durum = k;
        await expectLater(ag().sonYayin(), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'limit')));
      }
      durum = 500;
      await expectLater(ag().sonYayin(), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'ag_hatasi')));
      durum = 200;
      govdeOzel = '{bozuk';
      await expectLater(ag().sonYayin(), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'bozuk_yanit')));
      govdeOzel = 'x' * (1024 * 1024 + 10);
      await expectLater(ag().sonYayin(), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'bozuk_yanit')));
    });

    test('sunucu kapalıyken ağ hatası; izinsiz sunucuya istek hiç gitmez', () async {
      final kapali = Ag(depo: depo, apiTaban: 'http://127.0.0.1:1', ekSunucular: {'127.0.0.1'}, zamanAsimi: const Duration(seconds: 2));
      await expectLater(kapali.sonYayin(), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'ag_hatasi')));
      final uretim = Ag(depo: depo); // ek sunucu yok
      await expectLater(uretim.metinIndir(adres('/dl/SHA256SUMS.txt')), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'adres_izinsiz')));
      expect(istekler, isEmpty);
    });

    test('izinsiz yönlendirme reddedilir', () async {
      yonlendir = 'http://evil.example/Habit.apk';
      final d = await gecici();
      await expectLater(ag().indir(adres('/dl/Habit-Tracker-0.4.0.apk'), File('${d.path}/x.apk'), yeniApk.length), throwsA(isA<GuncellemeHatasi>()));
      expect(d.listSync(), isEmpty);
    });

    test('doğru dosya indirilir ve doğrulanır', () async {
      final g = await hizmet();
      await g.denetle();
      final f = await g.hazirla(g.teklif!);
      expect(f.path, endsWith('Habit-Tracker-0.4.0.apk'));
      expect(await f.readAsBytes(), yeniApk);
      expect(g.klasor.listSync().whereType<File>().map((x) => x.path).where((p) => p.endsWith('.part')), isEmpty);
    });

    test('özet uyuşmazlığı dosyayı siler', () async {
      final g = await hizmet();
      await g.denetle();
      ozetMetni = '${'0' * 64}  Habit-Tracker-0.4.0.apk\n';
      await expectLater(g.hazirla(g.teklif!), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'ozet_uyusmuyor')));
      expect(g.klasor.listSync(), isEmpty);
    });

    test('özet satırı yoksa APK hiç indirilmez', () async {
      final g = await hizmet();
      await g.denetle();
      ozetMetni = '$h  baska.apk\n';
      await expectLater(g.hazirla(g.teklif!), throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'ozet_bulunamadi')));
      expect(istekler.where((i) => i.$1 == '/dl/Habit-Tracker-0.4.0.apk'), isEmpty);
    });

    test('kesik indirme kısmi dosya bırakmaz', () async {
      final g = await hizmet();
      await g.denetle();
      apkKes = true;
      await expectLater(g.hazirla(g.teklif!), throwsA(isA<GuncellemeHatasi>()));
      expect(g.klasor.listSync(), isEmpty);
    });

    test('bildirilenden büyük ya da küçük akış iptal edilir', () async {
      final d = await gecici();
      for (final boyut in [100, yeniApk.length + 50]) {
        await expectLater(
          ag().indir(adres('/dl/Habit-Tracker-0.4.0.apk'), File('${d.path}/x.apk'), boyut),
          throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'boyut_uyusmuyor')),
        );
        expect(d.listSync(), isEmpty);
      }
    });

    test('sonsuz akış bildirilen boyutta kesilir (disk doldurma yok)', () async {
      sonsuz = true;
      final d = await gecici();
      await expectLater(
        ag().indir(adres('/dl/Habit-Tracker-0.4.0.apk'), File('${d.path}/x.apk'), 100),
        throwsA(isA<GuncellemeHatasi>().having((e) => e.kod, 'kod', 'boyut_uyusmuyor')),
      );
      expect(d.listSync(), isEmpty);
      await Future<void>.delayed(const Duration(milliseconds: 500));
      expect(gonderilen, lessThan(8 * 1024 * 1024), reason: 'istemci kesmeden okumaya devam etti');
    });

    test('eski indirmeler temizlenir', () async {
      final g = await hizmet();
      await g.denetle();
      await g.klasor.create(recursive: true);
      await File('${g.klasor.path}/Habit-Tracker-0.1.0.apk').writeAsString('x');
      await File('${g.klasor.path}/Habit-Tracker-0.1.1.apk.part').writeAsString('x');
      await g.hazirla(g.teklif!);
      expect(g.klasor.listSync().map((e) => e.uri.pathSegments.last), ['Habit-Tracker-0.4.0.apk']);
    });

    // --- durum ve kurallar
    test('denetim teklifi saklar, yeniden açılışta ağsız hatırlar, ikinci denetim ETag kullanır', () async {
      final d = await gecici();
      final dosya = File('${d.path}/ayarlar');
      Future<Guncelleyici> yeni() async => Guncelleyici(ayarlar: await ayarAc(dosya), klasor: Directory('${d.path}/g'), surum: '0.3.0', ag: ag());
      final g = await yeni();
      await g.denetle();
      expect(g.teklif!.surum, '0.4.0');
      expect(g.hataKodu, isNull);
      expect((await yeni()).teklif!.surum, '0.4.0');
      await (await yeni()).denetle();
      expect(istekler.last.$2['if-none-match'], '"v1"');
    });

    test('eski ya da aynı sürüm teklif edilmez; güncelleme sonrası saklı teklif düşer', () async {
      final g = await hizmet(surum: '0.4.0');
      await g.denetle();
      expect(g.teklif, isNull);
      final d = await gecici();
      final dosya = File('${d.path}/ayarlar');
      final a = Guncelleyici(ayarlar: await ayarAc(dosya), klasor: Directory('${d.path}/g'), surum: '0.3.0', ag: ag());
      await a.denetle();
      expect(a.teklif, isNotNull);
      final b = Guncelleyici(ayarlar: await ayarAc(dosya), klasor: Directory('${d.path}/g'), surum: '0.4.0', ag: ag());
      expect(b.teklif, isNull);
    });

    test('ağ hatası kodlanır ve teklifi silmez; yayın kalkarsa teklif kalkar', () async {
      final g = await hizmet();
      await g.denetle();
      durum = 403;
      await g.denetle();
      expect(g.hataKodu, 'limit');
      expect(g.teklif, isNotNull);
      expect(g.sonDenetim, isNotNull); // kötü ağda her açılışta yeniden denenmez
      durum = 404;
      await g.denetle();
      expect(g.teklif, isNull);
      expect(g.hataKodu, isNull);
    });

    test('günde en çok bir otomatik denetim', () async {
      var an = DateTime.utc(2026, 11, 7, 12);
      final g = await hizmet(saat: () => an);
      await g.denetimYaz(true);
      expect(await g.otomatikAdim(), isTrue);
      expect(await g.otomatikAdim(), isFalse);
      an = an.add(const Duration(hours: 23, minutes: 59));
      expect(await g.otomatikAdim(), isFalse);
      an = an.add(const Duration(minutes: 2));
      expect(await g.otomatikAdim(), isTrue);
      an = DateTime.utc(2026, 11, 6); // saat geri alındı
      expect(g.denetimZamaniGeldi, isTrue);
      expect(istekler.where((i) => i.$1.endsWith('/releases/latest')).length, 2);
    });

    test('denetim kapalıyken ya da hiç sorulmamışken SIFIR ağ isteği', () async {
      final g = await hizmet();
      expect(g.denetim, isNull);
      expect(await g.otomatikAdim(), isFalse); // sorulmadı
      await g.denetimYaz(false);
      expect(await g.otomatikAdim(), isFalse); // hayır
      expect(istekler, isEmpty);
    });

    test('elle yazılmış "evet" seçim sayılmaz; bozuk saklı adres teklif olmaz', () async {
      final d = await gecici();
      final dosya = File('${d.path}/ayarlar');
      await ayarYaz(dosya, guncellemeDenetimiAnahtari, 'evet');
      expect((await ayarAc(dosya)).guncellemeDenetimi, isNull);
      await ayarYaz(dosya, guncellemeDenetimiAnahtari, '1');
      expect((await ayarAc(dosya)).guncellemeDenetimi, isTrue);

      final g = Guncelleyici(ayarlar: await ayarAc(dosya), klasor: Directory('${d.path}/g'), surum: '0.3.0', ag: ag());
      await g.denetle();
      final j = jsonDecode((await ayarOku(dosya, guncellemeKaydiAnahtari))!) as Map<String, Object?>;
      (j['yayin']! as Map)['apk_url'] = 'https://evil.example/Habit-Tracker-0.4.0.apk';
      await ayarYaz(dosya, guncellemeKaydiAnahtari, jsonEncode(j));
      final g2 = Guncelleyici(ayarlar: await ayarAc(dosya), klasor: Directory('${d.path}/g'), surum: '0.3.0', ag: ag());
      expect(g2.teklif, isNull);
    });
  });

  group('güvenlik incelemesi düzeltmeleri', () {
    test('adres denetimi ayrıştırıcı farklarını kapatır', () {
      const kotuler = [
        'https://github.com/tungarix/habit-tracker-mobil/releases/../../evil/x/releases/a',
        'https://github.com/tungarix/habit-tracker-mobil/releases/%2e%2e/%2e%2e/evil',
        'https://github.com/tungarix/habit-tracker-mobil/releases/a%2Fb',
        'https://github.com:8443/tungarix/habit-tracker-mobil/releases/download/v1/Habit-Tracker-0.4.0.apk',
        'https://api.github.com/x y',
        'https://api.github.com/x\r\nX: y',
        ' https://api.github.com/x',
        r'https://api.github.com/x\y',
        'https://api.github.com/ı',
      ];
      for (final u in kotuler) {
        expect(adresUygun(u, depo, const {}), isFalse, reason: u);
      }
    });

    test('meşru adresler kabul edilir', () {
      for (final u in [
        'https://api.github.com/repos/tungarix/habit-tracker-mobil/releases/latest',
        'https://github.com/tungarix/habit-tracker-mobil/releases/download/v0.4.0/Habit-Tracker-0.4.0.apk',
        'https://github.com:443/tungarix/habit-tracker-mobil/releases/download/v0.4.0/Habit-Tracker-0.4.0.apk',
        'https://objects.githubusercontent.com/github-production-release-asset/1/2?X-Amz=abc&response-content-disposition=attachment',
      ]) {
        expect(adresUygun(u, depo, const {}), isTrue, reason: u);
      }
    });
  });
}
