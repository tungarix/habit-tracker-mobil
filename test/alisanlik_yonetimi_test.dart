import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/features/habits/habits_screen.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'b_test_yardimci.dart';

Finder _diyalogAlanlari() => find.descendant(
  of: find.byType(AlertDialog),
  matching: find.byType(TextField),
);

void main() {
  testWidgets('add a habit: name, count kind with target, category', (
    tester,
  ) async {
    telefon(tester, height: 1200);
    final db = await bellekDb();
    await ac(tester, db, const HabitsScreen());

    await tester.tap(find.text(Metin.alisanlikFab));
    await tester.pumpAndSettle();
    expect(find.text(Metin.yeniAlisanlik), findsOneWidget);

    await tester.enterText(_diyalogAlanlari().first, 'Deneme alışkanlık');
    await tester.tap(find.text(HabitKind.count.label));
    await tester.pumpAndSettle();
    await tester.enterText(_diyalogAlanlari().last, '3');
    await tester.tap(find.text(HabitCategory.zihin.label));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Metin.kaydet));
    await tester.pumpAndSettle();

    expect(find.text(Metin.yeniAlisanlik), findsNothing);
    final habits = await db.getAllHabits();
    expect(habits, hasLength(1));
    expect(habits.single.name, 'Deneme alışkanlık');
    expect(habits.single.kind, 'count');
    expect(habits.single.target, 3);
    expect(habits.single.category, 'zihin');
    expect(find.text('Deneme alışkanlık'), findsOneWidget);

    await temizle(tester);
  });

  testWidgets('empty name is not saved', (tester) async {
    telefon(tester, height: 1200);
    final db = await bellekDb();
    await ac(tester, db, const HabitsScreen());

    await tester.tap(find.text(Metin.alisanlikFab));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Metin.kaydet));
    await tester.pumpAndSettle();

    expect(find.text(Metin.yeniAlisanlik), findsOneWidget);
    expect(await db.getAllHabits(), isEmpty);

    await temizle(tester);
  });

  testWidgets('color and weekday pickers: spoken labels and saved choice', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    telefon(tester, height: 1600);
    final db = await bellekDb();
    await ac(tester, db, const HabitsScreen());

    await tester.tap(find.text(Metin.alisanlikFab));
    await tester.pumpAndSettle();
    await tester.enterText(_diyalogAlanlari().first, 'Renkli');
    final kirmizi = find.bySemanticsLabel(Metin.renkAdi(4));
    await tester.ensureVisible(kirmizi);
    expect(tester.getSize(kirmizi).shortestSide, greaterThanOrEqualTo(48));
    await tester.tap(kirmizi);
    await tester.tap(find.widgetWithText(FilterChip, 'Pzt'));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Metin.kaydet));
    await tester.pumpAndSettle();

    final h = (await db.getAllHabits()).single;
    expect(h.colorValue, 0xFFF44336);
    expect(h.scheduledWeekdays, '1');

    await temizle(tester);
    sem.dispose();
  });

  testWidgets('edit through the tile menu renames the habit', (tester) async {
    telefon(tester, height: 1200);
    final db = await bellekDb();
    await habitEkle(db, 'Eski ad');
    await ac(tester, db, const HabitsScreen());

    await tester.tap(find.byType(PopupMenuButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(Metin.duzenle));
    await tester.pumpAndSettle();
    await tester.enterText(_diyalogAlanlari().first, 'Yeni ad');
    await tester.tap(find.text(Metin.kaydet));
    await tester.pumpAndSettle();

    expect((await db.getAllHabits()).single.name, 'Yeni ad');

    await temizle(tester);
  });

  group('delete and archive', () {
    late AppDatabase db;
    late int keepId;
    late int dropId;

    setUp(() async {
      db = await bellekDb();
      keepId = await habitEkle(db, 'Kitap');
      dropId = await habitEkle(db, 'Gitar', sortOrder: 1);
      await db.setEntryStatus(keepId, '2026-10-01', EntryStatus.done);
      await db.setEntryStatus(dropId, '2026-10-01', EntryStatus.done);
      await db.setEntryStatus(dropId, '2026-10-02', EntryStatus.done);
    });

    Future<void> menuAc(WidgetTester tester, String ad) async {
      telefon(tester, height: 1200);
      await ac(tester, db, const HabitsScreen());
      final tile = find.ancestor(
        of: find.text(ad),
        matching: find.byType(ListTile),
      );
      await tester.tap(
        find.descendant(
          of: tile,
          matching: find.byType(PopupMenuButton<String>),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('confirmed delete removes the habit and its marks', (
      tester,
    ) async {
      await menuAc(tester, 'Gitar');
      await tester.tap(find.text(Metin.silNokta));
      await tester.pumpAndSettle();

      expect(find.text(Metin.kaliciSilBaslik), findsOneWidget);
      expect(find.textContaining('Arşivle'), findsWidgets);

      await tester.tap(find.widgetWithText(FilledButton, Metin.sil));
      await tester.pumpAndSettle();

      expect((await db.getAllHabits()).map((h) => h.name), ['Kitap']);
      final entries = await db.getAllEntries();
      expect(entries.map((e) => e.habitId).toSet(), {keepId});
      expect(find.text('Gitar'), findsNothing);

      await temizle(tester);
    });

    testWidgets('İptal leaves the habit alone', (tester) async {
      await menuAc(tester, 'Gitar');
      await tester.tap(find.text(Metin.silNokta));
      await tester.pumpAndSettle();
      await tester.tap(find.text(Metin.iptal));
      await tester.pumpAndSettle();

      expect(await db.getAllHabits(), hasLength(2));
      expect(await db.getEntry(dropId, '2026-10-02'), isNotNull);

      await temizle(tester);
    });

    testWidgets(
      'archive moves it to the archive list, restore brings it back',
      (tester) async {
        await menuAc(tester, 'Gitar');
        await tester.tap(find.text(Metin.arsivle));
        await tester.pumpAndSettle();

        expect(find.text(Metin.arsiv), findsOneWidget);
        expect(find.byTooltip(Metin.geriYukle), findsOneWidget);

        await tester.tap(find.byTooltip(Metin.geriYukle));
        await tester.pumpAndSettle();
        expect(find.text(Metin.arsiv), findsNothing);
        expect(find.text('Gitar'), findsOneWidget);

        await temizle(tester);
      },
    );
  });
}
