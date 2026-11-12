// Widget data and the tap-to-check write (the parts that run without an Android device).
import 'dart:convert';

import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/platform/bugun_ozeti.dart';
import 'package:aktenak_habit_tracker/platform/widget_servisi.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('tap URI', () {
    test('accepts exactly habitwidget://isaretle?id=N', () {
      expect(widgetUriCoz(Uri.parse('habitwidget://isaretle?id=5')), 5);
    });
    test('reads the list day, ignores a malformed one', () {
      expect(widgetUriGun(Uri.parse('habitwidget://isaretle?id=5&gun=2026-11-10')), '2026-11-10');
      expect(widgetUriGun(Uri.parse('habitwidget://isaretle?id=5')), isNull);
      expect(widgetUriGun(Uri.parse('habitwidget://isaretle?id=5&gun=dun')), isNull);
      expect(widgetUriGun(null), isNull);
    });
    test('rejects everything else', () {
      for (final u in [
        null,
        Uri.parse('habitwidget://isaretle'),
        Uri.parse('habitwidget://isaretle?id=0'),
        Uri.parse('habitwidget://isaretle?id=-3'),
        Uri.parse('habitwidget://isaretle?id=abc'),
        Uri.parse('habitwidget://baska?id=5'),
        Uri.parse('https://isaretle/?id=5'),
        Uri.parse('file:///x?id=5'),
      ]) {
        expect(widgetUriCoz(u), isNull, reason: '$u');
      }
    });
  });

  group('writing a check', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    final sabah = DateTime(2026, 11, 10, 9); // Tuesday

    Future<int> ekle(String ad, {String hafta = '', String kind = 'bool', int hedef = 1, int sira = 0}) =>
        db.insertHabit(
          HabitsCompanion.insert(
            name: ad,
            colorValue: 0xFF4CAF50,
            iconCodePoint: 0xe000,
            scheduledWeekdays: Value(hafta),
            kind: Value(kind),
            target: Value(hedef),
            sortOrder: Value(sira),
          ),
        );

    test('writes ✓ for an open habit and a second tap changes nothing', () async {
      final id = await ekle('Kitap');
      expect(await widgetIsaretle(db, id, sabah), isTrue);
      final e = (await db.getEntry(id, '2026-11-10'))!;
      expect(e.status, EntryStatus.done);
      expect(e.value, 1);
      expect(await widgetIsaretle(db, id, sabah), isFalse);
    });

    test('a count habit records its full target', () async {
      final id = await ekle('Adım', kind: 'count', hedef: 10000);
      await widgetIsaretle(db, id, sabah);
      final e = (await db.getEntry(id, '2026-11-10'))!;
      expect(e.status, EntryStatus.done);
      expect(e.value, 10000);
    });

    test('unknown, archived and not-scheduled-today habits are left alone', () async {
      final arsiv = await ekle('Eski');
      await db.archiveHabit(arsiv, sabah);
      final pazartesi = await ekle('Sadece pazartesi', hafta: '1');
      expect(await widgetIsaretle(db, 4242, sabah), isFalse);
      expect(await widgetIsaretle(db, arsiv, sabah), isFalse);
      expect(await widgetIsaretle(db, pazartesi, sabah), isFalse);
      expect(await db.getAllEntries(), isEmpty);
    });

    test('a ✗ or – already on the cell becomes ✓ (the tap means "I did it")', () async {
      final id = await ekle('Su');
      await db.setEntryStatus(id, '2026-11-10', EntryStatus.missed);
      expect(await widgetIsaretle(db, id, sabah), isTrue);
      expect((await db.getEntry(id, '2026-11-10'))!.status, EntryStatus.done);
    });

    test('a tap on a row drawn for an earlier day does not mark today', () async {
      final id = await ekle('Kitap');
      // The list still shows 2026-11-09; at 04:20 on the 10th the tracking day is already the 10th.
      final yeniGun = DateTime(2026, 11, 10, 4, 20);
      expect(await widgetIsaretle(db, id, yeniGun, gun: '2026-11-09'), isFalse);
      expect(await db.getAllEntries(), isEmpty);
      expect(await widgetIsaretle(db, id, yeniGun, gun: '2026-11-10'), isTrue);
    });

    test('before the day start hour the check goes to the previous tracking day', () async {
      final id = await ekle('Gece');
      await widgetIsaretle(db, id, DateTime(2026, 11, 11, 1, 30));
      expect(await db.getEntry(id, '2026-11-10'), isNotNull);
      expect(await db.getEntry(id, '2026-11-11'), isNull);
    });

    test('widget JSON lists today\'s habits in order with done flags and the day end', () async {
      final a = await ekle('B', sira: 2);
      await ekle('A', sira: 1);
      await ekle('Pazartesi', hafta: '1', sira: 0);
      await widgetIsaretle(db, a, sabah);
      final ozet = await bugunOzeti(db, sabah);
      final liste = jsonDecode(widgetOgeleriJson(ozet.satirlar)) as List;
      expect([for (final m in liste) m['ad']], ['A', 'B']);
      expect([for (final m in liste) m['yapildi']], [false, true]);
      expect(widgetBitisMs(ozet), DateTime(2026, 11, 11, 4).millisecondsSinceEpoch);
      expect(ozet.bekleyen, 1);
    });
  });
}
