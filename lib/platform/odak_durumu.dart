// Running focus timer state, kept in the Settings table under `focus_running`.
//
// Only the running state lives there; a session row is written with `insertSession` once the
// run ends, exactly like the desktop (no dangling row, schema and stats unchanged).
import 'dart:convert';

import '../core/date_utils.dart';
import '../core/enums.dart';
import '../data/database/database.dart';

const odakCalisiyorAnahtari = 'focus_running';

/// Runs shorter than this are noise, not data (same rule as the desktop focus card).
const odakEnKisaKayitSn = 60;

class OdakCalisiyor {
  const OdakCalisiyor({required this.baslangic, required this.tur, required this.planSn, this.taskId});

  final DateTime baslangic;
  final SessionKind tur;
  final int planSn;
  final int? taskId;

  DateTime get bitis => baslangic.add(Duration(seconds: planSn));

  /// Whole seconds left at [simdi], never below 0.
  int kalanSn(DateTime simdi) {
    final k = bitis.difference(simdi).inSeconds;
    return k < 0 ? 0 : k;
  }

  String toJson() => jsonEncode({
    'baslangic': baslangic.toUtc().toIso8601String(),
    'tur': tur.storageName,
    'plan_sn': planSn,
    'task_id': taskId,
  });

  /// Null on anything malformed: a broken value means "no timer running", never a crash.
  static OdakCalisiyor? fromJson(String? metin) {
    if (metin == null || metin.isEmpty) return null;
    try {
      final m = jsonDecode(metin);
      if (m is! Map) return null;
      final b = m['baslangic'], t = m['tur'], p = m['plan_sn'], k = m['task_id'];
      if (b is! String || t is! String || p is! int || p <= 0) return null;
      if (k != null && k is! int) return null;
      final an = DateTime.tryParse(b);
      if (an == null) return null;
      return OdakCalisiyor(baslangic: an.toLocal(), tur: SessionKind.fromStorage(t), planSn: p, taskId: k as int?);
    } on FormatException {
      return null;
    }
  }
}

/// Reads/writes the running timer and closes it into a session row.
class OdakDeposu {
  OdakDeposu(this.db);
  final AppDatabase db;

  Future<OdakCalisiyor?> oku() async => OdakCalisiyor.fromJson(await db.getSetting(odakCalisiyorAnahtari));

  Future<void> baslat(OdakCalisiyor s) => db.setSetting(odakCalisiyorAnahtari, s.toJson());

  /// Clears the running state without recording anything (abandoned run).
  Future<void> temizle() => db.setSetting(odakCalisiyorAnahtari, '');

  /// Ends the run at [simdi]: records a session when it lasted at least [odakEnKisaKayitSn] seconds
  /// and clears the state. [tamamlandi] true caps the length at the plan (the alarm may fire late).
  /// Returns the recorded seconds, or null when nothing was recorded.
  Future<int?> bitir(DateTime simdi, {required int dayStartHour, bool tamamlandi = false}) async {
    final s = await oku();
    if (s == null) return null;
    await temizle();
    final bitis = tamamlandi ? s.bitis : simdi;
    var sure = bitis.difference(s.baslangic).inSeconds;
    if (sure > s.planSn) sure = s.planSn;
    if (sure < odakEnKisaKayitSn) return null;
    // The task may have been deleted while the timer ran.
    final gorevVar = s.taskId != null &&
        await (db.select(db.tasks)..where((t) => t.id.equals(s.taskId!))).getSingleOrNull() != null;
    await db.insertSession(
      kind: s.tur.storageName,
      startedAt: s.baslangic,
      endedAt: bitis,
      durationS: sure,
      day: formatYmd(dayOf(bitis, dayStartHour: dayStartHour)),
      taskId: gorevVar ? s.taskId : null,
    );
    return sure;
  }
}
