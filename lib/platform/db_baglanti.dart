import 'package:drift/drift.dart';
import 'package:drift_flutter/drift_flutter.dart';

import '../core/constants.dart';
import '../data/data_location.dart';

/// Mobile database connection (deliberate deviation from the desktop
/// `_openConnection`, see `bilincli_sapmalar` in tool/kaynak_ozet.json).
///
/// The home-screen widget writes from a background isolate while the UI
/// isolate has its own streams open. With one `NativeDatabase` per isolate,
/// two writers can hit "database is locked" and `watch()` streams never see
/// the other connection's writes. `shareAcrossIsolates` hosts the database in
/// one server isolate that every connection (UI, widget callback) talks to.
///
/// Use as `AppDatabase.forTesting(dbBaglantisi())`; `database.dart` stays an
/// untouched copy. File name is `AppConstants.dbFileName` (`aktenak.sqlite`),
/// i.e. `<name>.sqlite` with name `aktenak`.
DatabaseConnection dbBaglantisi() => driftDatabase(
  name: AppConstants.dbFileName.replaceFirst(RegExp(r'\.sqlite$'), ''),
  native: DriftNativeOptions(
    shareAcrossIsolates: true,
    databaseDirectory: appDataDirectory,
  ),
);
