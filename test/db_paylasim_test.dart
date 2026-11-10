// Widget experiment (plan Faz 2, madde 1), as far as it can run on a desktop host:
// does a connection opened with shareAcrossIsolates let a second isolate write while the first one
// has a watch() stream open, without "database is locked" and with the stream seeing the write?
//
// NOT covered here (needs a device/emulator): the real home_widget background engine.
import 'dart:io';
import 'dart:isolate';

import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:drift_flutter/drift_flutter.dart';
import 'package:flutter_test/flutter_test.dart';

DatabaseConnection _baglanti(String ad, String dizin) => driftDatabase(
  name: ad,
  native: DriftNativeOptions(
    shareAcrossIsolates: true,
    databaseDirectory: () async => Directory(dizin),
    tempDirectoryPath: () async => dizin,
  ),
);

/// Runs in a second isolate: opens the shared database and writes N habits as fast as it can.
Future<int> _yazar((String, String, int) a) async {
  final db = AppDatabase.forTesting(_baglanti(a.$1, a.$2));
  try {
    for (var i = 0; i < a.$3; i++) {
      await db.insertHabit(
        HabitsCompanion.insert(name: 'Isolate $i', colorValue: 0xFF4CAF50, iconCodePoint: 0xe000),
      );
    }
    return (await db.getAllHabits()).length;
  } finally {
    await db.close();
  }
}

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  test('a write from a second isolate shows up in the first isolate\'s watch() stream', () async {
    final dizin = await Directory.systemTemp.createTemp('habit_paylasim');
    addTearDown(() async {
      try {
        await dizin.delete(recursive: true);
      } on FileSystemException {
        // Windows handle still open
      }
    });
    const ad = 'paylasim_testi';
    final ui = AppDatabase.forTesting(_baglanti(ad, dizin.path));
    addTearDown(ui.close);

    final gorulen = <int>[];
    final abonelik = ui.watchActiveHabits().listen((l) => gorulen.add(l.length));
    addTearDown(abonelik.cancel);
    await ui.insertHabit(HabitsCompanion.insert(name: 'UI', colorValue: 0xFF4CAF50, iconCodePoint: 0xe000));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    // 25 writes from another isolate while this one keeps its stream open.
    final toplam = await Isolate.run(() => _yazar((ad, dizin.path, 25)));
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect(toplam, 26, reason: 'both isolates talk to one database');
    expect(gorulen.last, 26, reason: 'the stream saw the other isolate\'s writes');
  }, timeout: const Timeout(Duration(seconds: 60)));

  test('control: one NativeDatabase per isolate (desktop style) does NOT notify the other stream', () async {
    final dizin = await Directory.systemTemp.createTemp('habit_kontrol');
    addTearDown(() async {
      try {
        await dizin.delete(recursive: true);
      } on FileSystemException {
        // Windows handle still open
      }
    });
    final dosya = File('${dizin.path}/kontrol.sqlite');
    final ui = AppDatabase.forTesting(NativeDatabase(dosya));
    addTearDown(ui.close);
    final gorulen = <int>[];
    final abonelik = ui.watchActiveHabits().listen((l) => gorulen.add(l.length));
    addTearDown(abonelik.cancel);
    await ui.insertHabit(HabitsCompanion.insert(name: 'UI', colorValue: 0xFF4CAF50, iconCodePoint: 0xe000));
    await Future<void>.delayed(const Duration(milliseconds: 300));

    final yol = dosya.path;
    await Isolate.run(() async {
      final db = AppDatabase.forTesting(NativeDatabase(File(yol)));
      await db.insertHabit(HabitsCompanion.insert(name: 'Diger', colorValue: 0xFF4CAF50, iconCodePoint: 0xe000));
      await db.close();
    });
    await Future<void>.delayed(const Duration(milliseconds: 500));

    expect((await ui.getAllHabits()).length, 2, reason: 'the row is on disk');
    expect(gorulen.last, 1, reason: 'but the open stream never heard about it');
  });
}
