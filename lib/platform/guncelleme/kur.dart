// Wiring helper for the in-app updater (the UI stage calls this; the screens live elsewhere).
import 'dart:io';

import 'package:flutter/foundation.dart' show kReleaseMode;
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../data/database/database.dart';
import 'ag.dart';
import 'ayarlar.dart';
import 'guncelleyici.dart';

/// DEVELOPMENT / end-to-end trial only: `--dart-define=GUNCELLEME_TABAN=http://10.0.2.2:8123` builds an
/// app whose updater talks to tool/e2e/guncelleme_sahte_github.py instead of GitHub. Never set for a release.
// Ignored in release builds, so a stray define can never open plain HTTP or another host there.
const _guncellemeTaban = kReleaseMode ? '' : String.fromEnvironment('GUNCELLEME_TABAN');

Ag guncellemeAgi(String surum) => _guncellemeTaban.isEmpty
    ? Ag(surum: surum)
    : Ag(surum: surum, apiTaban: _guncellemeTaban, ekSunucular: {Uri.parse(_guncellemeTaban).host});

/// Downloads go to the app cache dir: the Kotlin installer only accepts an APK from there.
Future<Guncelleyici> guncelleyiciKur(AppDatabase db, String surum) async {
  final cache = await getTemporaryDirectory();
  return Guncelleyici(
    ayarlar: await GuncellemeAyarlari.yukle(db),
    klasor: Directory(p.join(cache.path, 'guncelleme')),
    surum: surum,
    ag: guncellemeAgi(surum),
  );
}

/// Whether the download may start on [agTuru] ('wifi' | 'mobil' | 'yok') given the Wi-Fi-only setting.
/// Metered data needs the user's extra consent, offline never downloads.
bool indirmeIzinli(String agTuru, {required bool yalnizWifi, bool mobilOnayi = false}) => switch (agTuru) {
  'wifi' => true,
  'mobil' => !yalnizWifi || mobilOnayi,
  _ => false,
};
