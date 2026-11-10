import 'package:aktenak_habit_tracker/core/date_utils.dart';
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/features/monthly/monthly_screen.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'b_test_yardimci.dart';

Widget _ekran() => const Scaffold(body: MonthlyScreen());

Finder _hucre(int id, DateTime d) =>
    find.byKey(ValueKey('grid-cell-$id-${formatYmd(d)}'));

void main() {
  testWidgets('habit names stay fixed while the day columns scroll sideways', (
    tester,
  ) async {
    telefon(tester);
    final db = await bellekDb();
    final id = await habitEkle(db, 'Kitap');
    await ac(tester, db, _ekran());

    final t = today();
    final first = DateTime(t.year, t.month, 1);
    final labelBefore = tester.getTopLeft(find.text('Kitap'));
    final cellBefore = tester.getTopLeft(_hucre(id, first));
    expect(tester.getSize(_hucre(id, first)), const Size(48, 48));

    await tester.drag(_hucre(id, first), const Offset(-300, 0));
    await tester.pumpAndSettle();

    expect(tester.getTopLeft(find.text('Kitap')), labelBefore);
    expect(
      tester.getTopLeft(_hucre(id, first)).dx,
      lessThan(cellBefore.dx - 100),
      reason: 'the day columns must have slid left',
    );

    await temizle(tester);
  });

  testWidgets('month arrows move the month, Bugüne dön returns', (
    tester,
  ) async {
    telefon(tester);
    final db = await bellekDb();
    await habitEkle(db, 'Kitap');
    await ac(tester, db, _ekran());

    final t = today();
    final bu = '${Metin.aylar[t.month - 1]} ${t.year}';
    expect(find.text(bu), findsOneWidget);
    expect(find.text(Metin.bugunDon), findsNothing);

    await tester.tap(find.byTooltip(Metin.oncekiAy));
    await tester.pumpAndSettle();
    expect(find.text(bu), findsNothing);
    expect(find.text(Metin.bugunDon), findsOneWidget);

    await tester.tap(find.text(Metin.bugunDon));
    await tester.pumpAndSettle();
    expect(find.text(bu), findsOneWidget);

    await temizle(tester);
  });

  testWidgets('cells carry a spoken label that follows the status', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    telefon(tester);
    final db = await bellekDb();
    final id = await habitEkle(db, 'Kitap');
    await ac(tester, db, _ekran());

    final t = today();
    final gun = '${t.day} ${Metin.aylar[t.month - 1]}';
    expect(find.bySemanticsLabel('Kitap, $gun: işaretlenmedi'), findsOneWidget);

    await tester.ensureVisible(_hucre(id, t));
    await tester.tap(_hucre(id, t));
    await tester.pumpAndSettle();

    expect(find.bySemanticsLabel('Kitap, $gun: yapıldı'), findsOneWidget);
    expect((await db.getEntry(id, formatYmd(t)))!.status, EntryStatus.done);

    await temizle(tester);
    sem.dispose();
  });

  testWidgets('mood chart appears only when the month has moods', (
    tester,
  ) async {
    telefon(tester);
    final db = await bellekDb();
    await habitEkle(db, 'Kitap');
    await ac(tester, db, _ekran());
    expect(find.text(Metin.buAyMoodYok), findsOneWidget);

    await db.setMood(formatYmd(today()), 4);
    await tester.pumpAndSettle();
    expect(find.text(Metin.buAyMoodYok), findsNothing);
    expect(find.bySemanticsLabel(RegExp('Mood grafiği')), findsOneWidget);

    await temizle(tester);
  });

  // The cell's start day is the tracking day the habit was created on: a habit
  // added at 01:30 started on the day still running and must accept a mark.
  testWidgets('a habit created after midnight can be marked on its first day', (
    tester,
  ) async {
    telefon(tester);
    final db = await bellekDb();
    final t = today();
    final created = DateTime(t.year, t.month, t.day + 1, 1, 30);
    final id = await db.insertHabit(
      HabitsCompanion.insert(
        name: 'Gece eklenen',
        colorValue: 0xFF4CAF50,
        iconCodePoint: 0xe000,
        createdAt: Value(created),
      ),
    );
    await ac(tester, db, _ekran());

    if (t.day > 1) {
      final before = previousDay(t);
      await tester.ensureVisible(_hucre(id, before));
      await tester.tap(_hucre(id, before));
      await tester.pumpAndSettle();
      expect(
        await db.getEntry(id, formatYmd(before)),
        isNull,
        reason: 'a day before the habit existed must not be markable',
      );
    }

    await tester.ensureVisible(_hucre(id, t));
    await tester.tap(_hucre(id, t));
    await tester.pumpAndSettle();
    final entry = await db.getEntry(id, formatYmd(t));
    expect(
      entry,
      isNotNull,
      reason: 'creation tracking day should be markable',
    );
    expect(entry!.status, EntryStatus.done);

    await temizle(tester);
  });
}
