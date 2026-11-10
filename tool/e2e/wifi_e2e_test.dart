// ignore_for_file: avoid_print
// QR + Wi-Fi senkron uçtan uca denetimi: MOBİL istemci ağ kodu (lib/platform/wifi/istemci.dart) +
// mobil senkron kodu, MASAÜSTÜNÜN GERÇEK EslestirmeSunucusu'na karşı (127.0.0.1, gerçek TLS).
//
// Önce masaüstü tarafı çalışıyor olmalı (habit-tracker-v5-calisma/tool/e2e/wifi_kontrol_sunucu_test.dart);
// ikisini birlikte `pwsh -File tool/e2e/wifi_calistir.ps1` başlatır. Kontrol arayüzü: E2E_KONTROL_PORT.
//
// Bu test GERÇEK Android'i / LAN'ı / güvenlik duvarını kanıtlamaz: Dart VM (BoringSSL değil, Dart'ın kendi
// TLS yığını ama aynı BoringSSL tabanlı dart:io) ile Windows loopback'idir. Android tarafı emülatörde ayrıca denenir.
import 'dart:convert';
import 'dart:io';

import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_export.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_import.dart';
import 'package:aktenak_habit_tracker/platform/wifi/istemci.dart';
import 'package:aktenak_habit_tracker/platform/wifi/sozlesme.dart';
import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const t0 = 1780000000;
int at(int n) => t0 + n;

final kontrolPort = int.parse(Platform.environment['E2E_KONTROL_PORT'] ?? '48731');
late Directory tmp;
late AppDatabase tel;

Future<Map<String, dynamic>> kontrol(String yol, [Map<String, Object?> govde = const {}]) async {
  final c = HttpClient();
  try {
    final r = await c.postUrl(Uri.parse('http://127.0.0.1:$kontrolPort$yol'));
    final b = utf8.encode(jsonEncode(govde));
    r.contentLength = b.length;
    r.add(b);
    final y = await r.close();
    final m = await utf8.decodeStream(y);
    if (y.statusCode != 200) fail('kontrol $yol -> ${y.statusCode} $m');
    return jsonDecode(m) as Map<String, dynamic>;
  } finally {
    c.close(force: true);
  }
}

Set<String> adlar(Map<String, dynamic> d) => {for (final h in d['habits'] as List) (h as Map)['name'] as String};

Future<void> telefonuSifirla() async {
  try {
    await tel.close();
  } catch (_) {}
  final f = File('${tmp.path}/telefon.sqlite');
  if (f.existsSync()) f.deleteSync();
  tel = AppDatabase.forTesting(NativeDatabase(f));
}

Future<void> telHabit(String ad, int stamp) => tel.insertHabit(
  HabitsCompanion.insert(
    name: ad,
    colorValue: 0xFF4CAF50,
    iconCodePoint: 0xe000,
    createdAt: Value(DateTime.fromMillisecondsSinceEpoch(at(0) * 1000)),
    updatedAt: Value(at(stamp)),
  ),
);

Future<Habit> telBul(String ad) async => (await tel.getAllHabits()).firstWhere((h) => h.name == ad);

Future<void> telYeniAd(String ad, String yeni, int stamp) async => tel.customStatement(
  'UPDATE habits SET name = ?, updated_at = ? WHERE id = ?',
  [yeni, at(stamp), (await telBul(ad)).id],
);

Future<void> telSil(String ad, int stamp) async {
  final h = await telBul(ad);
  await tel.deleteHabit(h.id);
  await tel.customStatement(
    "UPDATE silinenler SET deleted_at = ? WHERE kind = 'habit' AND anahtar = ?",
    [at(stamp), h.uid],
  );
}

Future<Set<String>> telAdlar() async => {for (final h in await tel.getAllHabits()) h.name};

EslestirmeBaglantisi baglanti(Map<String, dynamic> c, {String? parmak, String? jeton}) => EslestirmeBaglantisi(
  adresler: (c['adresler'] as List).cast<String>(),
  port: c['port'] as int,
  parmakIzi: parmak ?? c['parmakIzi'] as String,
  jeton: jeton ?? c['jeton'] as String,
  bitis: DateTime.fromMillisecondsSinceEpoch((c['bitis'] as int) * 1000),
  ad: c['ad'] as String,
);

// Yalnız testte loopback; üretim ozelIpv4 kullanır.
WifiIstemci istemci(EslestirmeBaglantisi b) => WifiIstemci(
  b,
  cihazAdi: 'E2E telefon',
  uygulamaSurumu: 'e2e',
  baglanmaSuresi: const Duration(seconds: 3),
  adresDenetimi: (a) => a == '127.0.0.1',
);

Future<String> kodAl(Future<Object?> Function() f) async {
  try {
    await f();
  } on WifiHatasi catch (e) {
    return e.kod;
  }
  return 'HATA_YOK';
}

/// Telefonun ekrandaki akışının aynısı: oturum, masaüstü durumu, yerel birleştirme, tam durumu gönder.
Future<MasaustuRaporu> esitle(Map<String, dynamic> c) async {
  final i = istemci(baglanti(c));
  try {
    await i.oturumAc();
    final bayt = await i.durumAl();
    await importSyncBytes(tel, bayt);
    final tam = Uint8List.fromList(utf8.encode(await exportSync(tel, deviceName: 'E2E telefon')));
    final rapor = await i.durumGonder(tam);
    await i.bitir('tamam');
    return rapor;
  } finally {
    i.kapat();
  }
}

void main() {
  setUpAll(() async {
    tmp = Directory.systemTemp.createTempSync('habit_e2e_telefon_');
    tel = AppDatabase.forTesting(NativeDatabase(File('${tmp.path}/telefon.sqlite')));
    await kontrol('/sifirla');
  });
  tearDownAll(() async {
    await tel.close();
    tmp.deleteSync(recursive: true);
  });

  test('QR bağlantısı: masaüstü kodlar, mobil ayrıştırır (sözleşme uyumu)', () async {
    final c = await kontrol('/baslat');
    // Masaüstü yalnız özel aralıkta çalışır; 127.0.0.1 mobilde de reddedilir.
    final link = c['link'] as String;
    expect(link, contains('a=127.0.0.1'));
    expect(() => qrCoz(link), throwsA(isA<WifiHatasi>()));
    final emu = qrCoz(link.replaceFirst('a=127.0.0.1', 'a=10.0.2.2'));
    expect(emu.adresler, ['10.0.2.2']);
    expect(emu.port, c['port']);
    expect(emu.parmakIzi, c['parmakIzi']);
    expect(emu.jeton, c['jeton']);
    expect(emu.ad, 'E2E-PC');
    expect(emu.suresiDolmusOlabilir(DateTime.now()), isFalse);
    await kontrol('/sifirla');
  });

  test('iki yönlü eşitleme + düzenleme (son yazan kazanır) + silme', () async {
    await kontrol('/sifirla');
    await telefonuSifirla();
    await kontrol('/habit', {'ad': 'Su ic', 'damga': 10});
    await kontrol('/habit', {'ad': 'Ortak', 'damga': 10});
    await telHabit('Kitap', 20);

    // 1) İlk eşitleme: iki yönlü birleşim.
    var c = await kontrol('/baslat');
    var rapor = await esitle(c);
    var d = await kontrol('/bekle', {'sn': 10});
    expect(d['sunucu'], 'tamam');
    expect(d['yedek'], 1, reason: 'masaüstü birleştirmeden önce yedek almalı');
    expect(adlar(d), {'Su ic', 'Ortak', 'Kitap'});
    expect(await telAdlar(), {'Su ic', 'Ortak', 'Kitap'});
    print('E2E 1. eşitleme: masaüstü raporu eklenen=${rapor.eklenen} güncellenen=${rapor.guncellenen} silinen=${rapor.silinen}; '
        'masaüstü: ${d['sonuc']}');
    expect(rapor.eklenen, greaterThan(0));

    // 2) Düzenleme: telefon yeniden adlandırır, masaüstü yeni alışkanlık ekler.
    await telYeniAd('Ortak', 'Ortak (telefon)', 100);
    await kontrol('/habit', {'ad': 'Yuruyus', 'damga': 90});
    c = await kontrol('/baslat');
    await esitle(c);
    d = await kontrol('/bekle', {'sn': 10});
    expect(d['sunucu'], 'tamam');
    final beklenen = {'Su ic', 'Ortak (telefon)', 'Kitap', 'Yuruyus'};
    expect(adlar(d), beklenen);
    expect(await telAdlar(), beklenen);

    // 3) Silme: telefon "Kitap"ı, masaüstü "Su ic"i siler; ikisi de iki tarafta silinmiş olmalı.
    await telSil('Kitap', 200);
    await kontrol('/sil', {'ad': 'Su ic', 'damga': 210});
    c = await kontrol('/baslat');
    await esitle(c);
    d = await kontrol('/bekle', {'sn': 10});
    expect(d['sunucu'], 'tamam');
    final kalan = {'Ortak (telefon)', 'Yuruyus'};
    expect(adlar(d), kalan);
    expect(await telAdlar(), kalan);
    expect((d['silinen'] as List).where((s) => (s as String).startsWith('habit:')).length, 2);

    // 4) Bir daha eşitleme değişiklik üretmemeli (idempotent).
    c = await kontrol('/baslat');
    final r4 = await esitle(c);
    expect([r4.eklenen, r4.guncellenen, r4.silinen], [0, 0, 0]);
    d = await kontrol('/bekle', {'sn': 10});
    expect(adlar(d), kalan);
  });

  test('yanlış parmak izi reddedilir; jeton yanmaz, sunucu oturum görmez', () async {
    await kontrol('/sifirla');
    await telefonuSifirla();
    final c = await kontrol('/baslat');
    final dogru = c['parmakIzi'] as String;
    final yanlis = (dogru[0] == 'A' ? 'B' : 'A') + dogru.substring(1);
    final kod = await kodAl(() => istemci(baglanti(c, parmak: yanlis)).oturumAc());
    print('E2E yanlış parmak izi -> $kod');
    expect(kod, 'parmak_izi_uyusmadi');
    var d = await kontrol('/durum');
    expect(d['sunucu'], 'bekliyor', reason: 'TLS aşamasında düşmeli, HTTP isteği görmemeli');
    expect(d['istemci'], isNull);
    // Doğru parmak izi hâlâ çalışır: jeton yanmadı.
    await esitle(c);
    d = await kontrol('/bekle', {'sn': 10});
    expect(d['sunucu'], 'tamam');
  });

  test('süresi dolmuş jeton reddedilir', () async {
    await kontrol('/sifirla');
    final c = await kontrol('/baslat', {'qrOmruSn': 2});
    await Future<void>.delayed(const Duration(seconds: 4));
    final kod = await kodAl(() => istemci(baglanti(c)).oturumAc());
    print('E2E süresi dolmuş jeton -> $kod');
    expect(kod, isNot('HATA_YOK'));
    final d = await kontrol('/durum');
    expect(d['sunucu'], 'sureDoldu');
    expect(d['istemci'], isNull);
  });

  test('ikinci kez kullanılan jeton reddedilir (oturum açıkken ve bittikten sonra)', () async {
    await kontrol('/sifirla');
    await telefonuSifirla();
    await telHabit('Kitap', 5);
    final c = await kontrol('/baslat');
    final a = istemci(baglanti(c));
    await a.oturumAc(); // jeton burada yanar
    final ikinci = await kodAl(() => istemci(baglanti(c)).oturumAc());
    print('E2E jeton 2. kullanım (oturum açıkken) -> $ikinci');
    expect(ikinci, isNot('HATA_YOK'));
    // İlk oturum etkilenmeden bitirilebilir.
    final bayt = await a.durumAl();
    await importSyncBytes(tel, bayt);
    await a.durumGonder(Uint8List.fromList(utf8.encode(await exportSync(tel, deviceName: 'E2E telefon'))));
    await a.bitir('tamam');
    a.kapat();
    var d = await kontrol('/bekle', {'sn': 10});
    expect(d['sunucu'], 'tamam');
    expect(adlar(d), {'Kitap'});
    final ucuncu = await kodAl(() => istemci(baglanti(c)).oturumAc());
    print('E2E jeton 3. kullanım (oturum bittikten sonra) -> $ucuncu');
    expect(ucuncu, isNot('HATA_YOK'));
  });

  test('masaüstü "bu telefon değil" derse oturum açılmaz', () async {
    await kontrol('/sifirla');
    final c = await kontrol('/baslat', {'onay2': 'hayir'});
    final kod = await kodAl(() => istemci(baglanti(c)).oturumAc());
    print('E2E masaüstü Onay 2 hayır -> $kod');
    expect(kod, 'reddedildi');
    final d = await kontrol('/bekle', {'sn': 5});
    expect(d['sunucu'], 'reddedildi');
  });

  tearDownAll(() async {
    try {
      await kontrol('/cik');
    } catch (_) {}
  });
}
