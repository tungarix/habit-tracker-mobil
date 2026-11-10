import 'package:aktenak_habit_tracker/app.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Shared widget-test plumbing for the shell / Bugün / Görevler tests.

Future<AppDatabase> bellekDb() async {
  await initializeDateFormatting('tr');
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<int> aliskanlikEkle(
  AppDatabase db,
  String ad, {
  String kind = 'bool',
  int target = 1,
}) => db.insertHabit(
  HabitsCompanion.insert(
    name: ad,
    colorValue: 0xFF4CAF50,
    iconCodePoint: 0xe000,
    kind: Value(kind),
    target: Value(target),
  ),
);

/// Phone-sized window (360 px wide). A taller [yukseklik] lets a lazy ListView
/// build every card, for tests that act on cards far down the page.
void telefonBoyutu(WidgetTester tester, {double yukseklik = 640}) {
  tester.view.physicalSize = Size(360, yukseklik);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> uygulamaAc(
  WidgetTester tester,
  AppDatabase db, {
  List overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: [databaseProvider.overrideWithValue(db), ...overrides],
      child: const HabitApp(),
    ),
  );
  await bekle(tester);
}

/// Lets real async work (drift queries) and animations progress: a few frames,
/// each preceded by a short real-time wait. pumpAndSettle would spin forever
/// on the loading indicator while the first query is still in flight.
Future<void> bekle(WidgetTester tester, [int kare = 8]) async {
  for (var i = 0; i < kare; i++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Unmounts the tree so drift's stream-cleanup timers finish before teardown.
Future<void> temizle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await bekle(tester, 2);
}
