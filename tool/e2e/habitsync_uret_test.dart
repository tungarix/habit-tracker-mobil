// Writes a small invented .habitsync (desktop-style device) to $HABITSYNC_CIKTI for the emulator
// trial of the "open with" flow. Fake data only. Run: HABITSYNC_CIKTI=<path> flutter test tool/e2e/habitsync_uret_test.dart
import 'dart:io';

import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_export.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('writes the fake .habitsync', () async {
    final yol = Platform.environment['HABITSYNC_CIKTI'];
    if (yol == null) return;
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final id = await db.insertHabit(
      HabitsCompanion.insert(name: 'Dis fircala', colorValue: 0xFF9C27B0, iconCodePoint: 0xe000),
    );
    for (final d in ['2026-11-07', '2026-11-08', '2026-11-09']) {
      await db.setEntryStatus(id, d, EntryStatus.done);
    }
    await File(yol).writeAsString(await exportSync(db, deviceName: 'Test bilgisayari'));
    await db.close();
  });
}
