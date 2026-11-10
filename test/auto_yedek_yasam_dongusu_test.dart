import 'dart:io';

import 'package:aktenak_habit_tracker/data/auto_backup.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/data/repositories/backup_repository.dart';
import 'package:aktenak_habit_tracker/features/settings/auto_backup_lifecycle.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory dir;
  late AppDatabase db;
  late ProviderContainer container;
  late DateTime now;

  List<String> dosyalar() => dir
      .listSync()
      .map((e) => e.path.split(Platform.pathSeparator).last)
      .toList();

  setUp(() {
    dir = Directory.systemTemp.createTempSync('aktenak_yasam');
    db = AppDatabase.forTesting(NativeDatabase.memory());
    now = DateTime(2026, 11, 10, 9);
    container = ProviderContainer(
      overrides: [
        autoBackupProvider.overrideWith(
          (ref) async => AutoBackup(repo: BackupRepository(db), dir: dir),
        ),
      ],
    );
  });
  tearDown(() async {
    container.dispose();
    await db.close();
    dir.deleteSync(recursive: true);
  });

  test('runNow takes the daily backup once, a new day takes another', () async {
    final yasam = AutoBackupLifecycle(container, clock: () => now);

    await yasam.runNow();
    expect(dosyalar(), ['aktenak-auto-20261110.json']);

    await yasam.runNow(); // same day: nothing new
    expect(dosyalar(), hasLength(1));

    now = DateTime(2026, 11, 11, 9);
    await yasam.runNow();
    expect(dosyalar(), hasLength(2));
  });

  test('coming back to the foreground triggers the backup', () async {
    final yasam = AutoBackupLifecycle(container, clock: () => now);

    yasam.didChangeAppLifecycleState(AppLifecycleState.paused);
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(dosyalar(), isEmpty);

    yasam.didChangeAppLifecycleState(AppLifecycleState.resumed);
    for (var i = 0; i < 50 && dosyalar().isEmpty; i++) {
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    expect(dosyalar(), ['aktenak-auto-20261110.json']);
  });

  test('a failing backup never throws out of runNow', () async {
    final bozuk = ProviderContainer(
      overrides: [
        autoBackupProvider.overrideWith((ref) async => throw StateError('x')),
      ],
    );
    addTearDown(bozuk.dispose);
    await AutoBackupLifecycle(bozuk).runNow(); // must complete normally
  });
}
