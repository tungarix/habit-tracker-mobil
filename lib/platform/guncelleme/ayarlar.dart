// Updater state kept in the Settings table (device-local, never synced).
// Not user data: a broken value simply reads as "never checked / never asked".
import 'dart:convert';

import '../../data/database/database.dart';

/// Settings keys (device-local).
const guncellemeDenetimiAnahtari = 'update_check'; // '1' | '0'; absent = never asked
const guncellemeKaydiAnahtari = 'update_record'; // JSON map
const guncellemeYalnizWifiAnahtari = 'update_wifi_only'; // '0' = also mobile data; absent = Wi-Fi only

class GuncellemeAyarlari {
  GuncellemeAyarlari._(this._db, this._denetim, this._kayit, this._yalnizWifi);

  final AppDatabase _db;
  bool? _denetim;
  Map<String, Object?> _kayit;
  bool _yalnizWifi;

  static Future<GuncellemeAyarlari> yukle(AppDatabase db) async {
    final d = await db.getSetting(guncellemeDenetimiAnahtari);
    Map<String, Object?> kayit = {};
    try {
      final g = jsonDecode(await db.getSetting(guncellemeKaydiAnahtari) ?? '');
      if (g is Map) kayit = Map<String, Object?>.from(g);
    } on FormatException {
      // broken record = never checked
    }
    return GuncellemeAyarlari._(
      db,
      switch (d) { '1' => true, '0' => false, _ => null },
      kayit,
      await db.getSetting(guncellemeYalnizWifiAnahtari) != '0',
    );
  }

  /// null = never asked (no network request), true/false = the user's choice.
  bool? get guncellemeDenetimi => _denetim;

  /// Download only on an unmetered network (default).
  bool get yalnizWifi => _yalnizWifi;

  /// Returns a copy.
  Map<String, Object?> get guncellemeKaydi => Map<String, Object?>.from(_kayit);

  Future<void> guncellemeDenetimiYaz(bool acik) async {
    _denetim = acik;
    await _db.setSetting(guncellemeDenetimiAnahtari, acik ? '1' : '0');
  }

  Future<void> yalnizWifiYaz(bool deger) async {
    _yalnizWifi = deger;
    await _db.setSetting(guncellemeYalnizWifiAnahtari, deger ? '1' : '0');
  }

  Future<void> guncellemeKaydiYaz(Map<String, Object?> kayit) async {
    _kayit = Map<String, Object?>.from(kayit);
    await _db.setSetting(guncellemeKaydiAnahtari, jsonEncode(kayit));
  }
}
