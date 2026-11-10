// Updater settings in the Settings table, and the Wi-Fi-only download rule.
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/platform/guncelleme/ayarlar.dart';
import 'package:aktenak_habit_tracker/platform/guncelleme/kur.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;
  setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
  tearDown(() => db.close());

  test('fresh install: never asked, Wi-Fi only, empty record', () async {
    final a = await GuncellemeAyarlari.yukle(db);
    expect(a.guncellemeDenetimi, isNull);
    expect(a.yalnizWifi, isTrue);
    expect(a.guncellemeKaydi, isEmpty);
  });

  test('choices persist across a reload', () async {
    final a = await GuncellemeAyarlari.yukle(db);
    await a.guncellemeDenetimiYaz(true);
    await a.yalnizWifiYaz(false);
    await a.guncellemeKaydiYaz({'son_denetim': '2026-11-10T00:00:00.000Z'});
    final b = await GuncellemeAyarlari.yukle(db);
    expect(b.guncellemeDenetimi, isTrue);
    expect(b.yalnizWifi, isFalse);
    expect(b.guncellemeKaydi['son_denetim'], '2026-11-10T00:00:00.000Z');
    await b.guncellemeDenetimiYaz(false);
    expect((await GuncellemeAyarlari.yukle(db)).guncellemeDenetimi, isFalse);
  });

  test('garbage in Settings reads as "never asked" / empty record', () async {
    await db.setSetting(guncellemeDenetimiAnahtari, 'evet');
    await db.setSetting(guncellemeKaydiAnahtari, '{bozuk');
    final a = await GuncellemeAyarlari.yukle(db);
    expect(a.guncellemeDenetimi, isNull);
    expect(a.guncellemeKaydi, isEmpty);
  });

  test('download rule: Wi-Fi yes, mobile data only with consent or when Wi-Fi-only is off, offline never', () {
    expect(indirmeIzinli('wifi', yalnizWifi: true), isTrue);
    expect(indirmeIzinli('mobil', yalnizWifi: true), isFalse);
    expect(indirmeIzinli('mobil', yalnizWifi: true, mobilOnayi: true), isTrue);
    expect(indirmeIzinli('mobil', yalnizWifi: false), isTrue);
    expect(indirmeIzinli('yok', yalnizWifi: false, mobilOnayi: true), isFalse);
  });
}
