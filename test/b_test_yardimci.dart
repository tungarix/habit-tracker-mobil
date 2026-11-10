import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:drift/drift.dart' show Value, driftRuntimeOptions;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';

/// Plumbing shared by the monthly / settings / habits widget tests.

Future<AppDatabase> bellekDb() async {
  await initializeDateFormatting('tr');
  // Some tests build a second database to produce a backup file.
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  addTearDown(db.close);
  return db;
}

Future<int> habitEkle(
  AppDatabase db,
  String ad, {
  DateTime? createdAt,
  int sortOrder = 0,
}) => db.insertHabit(
  HabitsCompanion.insert(
    name: ad,
    colorValue: 0xFF4CAF50,
    iconCodePoint: 0xe000,
    sortOrder: Value(sortOrder),
    createdAt: createdAt == null ? const Value.absent() : Value(createdAt),
  ),
);

/// Phone-sized window; [height] is tall for list screens so nothing is lazily skipped.
void telefon(WidgetTester tester, {double height = 800}) {
  tester.view.physicalSize = Size(360, height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Mounts [home] under a Scaffold-less MaterialApp with the in-memory [db].
Future<void> ac(
  WidgetTester tester,
  AppDatabase db,
  Widget home, {
  List overrides = const [],
}) async {
  await tester.pumpWidget(
    ProviderScope(
      // ignore: argument_type_not_assignable
      overrides: [databaseProvider.overrideWithValue(db), ...overrides],
      child: MaterialApp(home: home),
    ),
  );
  await tester.pumpAndSettle();
}

/// Unmounts the tree so drift's stream-cleanup timers finish before teardown.
Future<void> temizle(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox.shrink());
  await tester.pump(const Duration(seconds: 1));
}
