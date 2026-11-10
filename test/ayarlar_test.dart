import 'dart:io';

import 'package:aktenak_habit_tracker/core/constants.dart';
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/data/repositories/backup_repository.dart';
import 'package:aktenak_habit_tracker/features/settings/backup_file_service.dart';
import 'package:aktenak_habit_tracker/features/settings/reminder_settings.dart';
import 'package:aktenak_habit_tracker/features/settings/settings_screen.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'b_test_yardimci.dart';

/// Stands in for file_picker and the share sheet.
class SahteDosyaServisi implements BackupFileService {
  String? secilecek;
  String? paylasilanJson;
  String? paylasilanAd;
  int secimSayisi = 0;

  @override
  Future<String?> pickBackup() async {
    secimSayisi++;
    return secilecek;
  }

  @override
  Future<void> shareBackup(String json, String fileName) async {
    paylasilanJson = json;
    paylasilanAd = fileName;
  }
}

/// Lets async work finish and animations (dialog, snackbar) play out in two
/// frames; pumpAndSettle runs hundreds of frames and crashes this machine's test engine.
Future<void> kisaBekle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  late Directory dataDir;
  late SahteDosyaServisi dosya;
  late InMemoryReminderSettings hatirlatici;

  setUp(() {
    dataDir = Directory.systemTemp.createTempSync('aktenak_ayarlar');
    dosya = SahteDosyaServisi();
    hatirlatici = InMemoryReminderSettings();
  });
  tearDown(() => dataDir.deleteSync(recursive: true));

  Future<void> ekraniAc(WidgetTester tester, AppDatabase db) async {
    telefon(tester, height: 1600);
    await ac(
      tester,
      db,
      const SettingsScreen(),
      overrides: [
        dataDirectoryProvider.overrideWith((ref) async => dataDir),
        backupFileServiceProvider.overrideWithValue(dosya),
        reminderSettingsProvider.overrideWithValue(hatirlatici),
      ],
    );
  }

  /// A backup JSON holding one habit with one tick, made by a separate database.
  Future<String> ornekYedek() async {
    final kaynak = await bellekDb();
    final id = await habitEkle(kaynak, 'Yedekten gelen');
    await kaynak.setEntryStatus(id, '2026-10-01', EntryStatus.done);
    return BackupRepository(kaynak).exportJson();
  }

  testWidgets('theme is saved; backups warning and empty status are shown', (
    tester,
  ) async {
    final db = await bellekDb();
    await ekraniAc(tester, db);

    expect(find.textContaining('telefon dışına çıkmaz'), findsOneWidget);
    expect(find.textContaining('Henüz yedek yok'), findsOneWidget);
    // Desktop-only controls must not exist on the phone.
    expect(find.text('Klasörü aç'), findsNothing);
    expect(find.textContaining('Windows'), findsNothing);

    Finder segment(String label) => find.descendant(
      of: find.byType(SegmentedButton<ThemeMode>),
      matching: find.text(label),
    );
    // The phone defaults to Sistem, so pick Koyu first to see a real change.
    await tester.tap(segment(Metin.temaKoyu));
    await kisaBekle(tester);
    expect(await db.getSetting(AppConstants.themeModeKey), 'dark');
    await tester.tap(segment(Metin.temaSistem));
    await kisaBekle(tester);
    expect(await db.getSetting(AppConstants.themeModeKey), 'system');
    await tester.tap(segment(Metin.temaAcik));
    await kisaBekle(tester);
    expect(await db.getSetting(AppConstants.themeModeKey), 'light');

    await temizle(tester);
  });

  testWidgets('export hands the JSON to the share sheet', (tester) async {
    final db = await bellekDb();
    await habitEkle(db, 'Kitap');
    await ekraniAc(tester, db);

    await tester.tap(find.text(Metin.disaAktar));
    await kisaBekle(tester);

    expect(dosya.paylasilanAd, startsWith('aktenak-backup-'));
    expect(dosya.paylasilanAd, endsWith('.json'));
    expect(dosya.paylasilanJson, contains('Kitap'));

    await temizle(tester);
  });

  testWidgets('import with Birleştir keeps existing data and adds the backup', (
    tester,
  ) async {
    final db = await bellekDb();
    // Another creation time: merge treats "same id, same second" as a rename.
    await habitEkle(db, 'Mevcut', createdAt: DateTime(2026, 1, 1));
    dosya.secilecek = await ornekYedek();
    await ekraniAc(tester, db);

    await tester.tap(find.text(Metin.iceAktar));
    await kisaBekle(tester);
    expect(find.text(Metin.iceAktarModuBaslik), findsOneWidget);
    await tester.tap(find.text(Metin.birlestir));
    await kisaBekle(tester);

    final adlar = (await db.getAllHabits()).map((h) => h.name).toSet();
    expect(adlar, {'Mevcut', 'Yedekten gelen'});
    expect(find.textContaining('İçe aktarıldı'), findsOneWidget);

    await temizle(tester);
  });

  testWidgets('import with Tamamen değiştir wipes existing data', (
    tester,
  ) async {
    final db = await bellekDb();
    await habitEkle(db, 'Mevcut');
    dosya.secilecek = await ornekYedek();
    await ekraniAc(tester, db);

    await tester.tap(find.text(Metin.iceAktar));
    await kisaBekle(tester);
    await tester.tap(find.text(Metin.tamamenDegistir));
    await kisaBekle(tester);

    final adlar = (await db.getAllHabits()).map((h) => h.name).toList();
    expect(adlar, ['Yedekten gelen']);

    await temizle(tester);
  });

  testWidgets('cancelling the picker or the mode dialog changes nothing', (
    tester,
  ) async {
    final db = await bellekDb();
    await habitEkle(db, 'Mevcut');
    await ekraniAc(tester, db);

    // Picker cancelled: no dialog at all.
    await tester.tap(find.text(Metin.iceAktar));
    await kisaBekle(tester);
    expect(dosya.secimSayisi, 1);
    expect(find.text(Metin.iceAktarModuBaslik), findsNothing);

    // File picked, mode dialog dismissed with İptal.
    dosya.secilecek = await ornekYedek();
    await tester.tap(find.text(Metin.iceAktar));
    await kisaBekle(tester);
    await tester.tap(find.text(Metin.iptal));
    await kisaBekle(tester);
    expect((await db.getAllHabits()).map((h) => h.name), ['Mevcut']);

    await temizle(tester);
  });

  testWidgets('a broken backup file reports an error and keeps the data', (
    tester,
  ) async {
    final db = await bellekDb();
    await habitEkle(db, 'Mevcut');
    dosya.secilecek = 'bu bir yedek değil';
    await ekraniAc(tester, db);

    await tester.tap(find.text(Metin.iceAktar));
    await kisaBekle(tester);
    await tester.tap(find.text(Metin.tamamenDegistir));
    await kisaBekle(tester);

    expect(find.textContaining('İçe aktarım başarısız'), findsOneWidget);
    expect((await db.getAllHabits()).map((h) => h.name), ['Mevcut']);

    await temizle(tester);
  });

  testWidgets('day start defaults to 04:00 and the slider persists changes', (
    tester,
  ) async {
    final db = await bellekDb();
    await ekraniAc(tester, db);

    expect(find.text('04:00'), findsWidgets);
    await tester.drag(
      find.byKey(const ValueKey('gun-baslangic-slider')),
      const Offset(-600, 0),
    );
    await kisaBekle(tester);
    expect(await db.getSetting(AppConstants.dayStartHourKey), '0');

    await temizle(tester);
  });

  testWidgets('reminder switch writes through the ReminderSettings seam', (
    tester,
  ) async {
    final db = await bellekDb();
    await ekraniAc(tester, db);
    expect(await hatirlatici.readHour(), isNull);

    await tester.tap(find.byType(SwitchListTile));
    await kisaBekle(tester);
    expect(await hatirlatici.readHour(), AppConstants.defaultReminderHour);
    expect(find.byKey(const ValueKey('hatirlatici-slider')), findsOneWidget);

    await tester.tap(find.byType(SwitchListTile));
    await kisaBekle(tester);
    expect(await hatirlatici.readHour(), isNull);

    await temizle(tester);
  });

  testWidgets('with an auto-backup taken the status shows its time', (
    tester,
  ) async {
    final db = await bellekDb();
    telefon(tester, height: 1600);
    await ac(
      tester,
      db,
      const SettingsScreen(),
      overrides: [
        dataDirectoryProvider.overrideWith((ref) async => dataDir),
        // The real provider lists files, and file I/O does not advance under
        // the test clock; the listing itself is covered by auto_backup_test.
        latestAutoBackupProvider.overrideWith(
          (ref) async => DateTime(2026, 11, 10, 9, 30),
        ),
      ],
    );
    await kisaBekle(tester);

    expect(
      find.textContaining('Son yedek: 10 Kasım 2026, 09:30'),
      findsOneWidget,
    );
    expect(find.textContaining('Henüz yedek yok'), findsNothing);

    await temizle(tester);
  });
}
