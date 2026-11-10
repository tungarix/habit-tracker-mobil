// Evening-reminder planning. Pure Dart (no Flutter, no platform): the notification
// layer only schedules what this returns.
//
// One-off notifications for the next [gunSayisi] days, never a repeating one: a repeating
// notification cannot skip just today, and no Dart code runs when it fires. The plan is
// recomputed on every app open, every mark and every widget write.
import '../core/date_utils.dart';

/// First notification id of the reminder block (ids [ilkId] .. [ilkId] + 6).
const hatirlaticiIlkId = 100;
const hatirlaticiGunSayisi = 7;

class PlanliHatirlatici {
  const PlanliHatirlatici({required this.id, required this.tetik, required this.bekleyen});

  final int id;

  /// Local wall-clock instant the reminder should fire at.
  final DateTime tetik;

  /// Open habits for today's reminder; null for later days (unknown until then).
  final int? bekleyen;

  @override
  bool operator ==(Object other) =>
      other is PlanliHatirlatici && other.id == id && other.tetik == tetik && other.bekleyen == bekleyen;

  @override
  int get hashCode => Object.hash(id, tetik, bekleyen);

  @override
  String toString() => 'PlanliHatirlatici($id, $tetik, $bekleyen)';
}

/// The reminders to schedule, soonest first.
///
/// - [saat]/[dakika]: reminder time of day.
/// - [bugunBekleyen]: habits scheduled today that are not ✓ yet. 0 = all done, so the
///   reminder that belongs to today's tracking day is dropped.
/// - [gunPlanli]: number of habits scheduled on a given tracking day (a day with none is skipped).
List<PlanliHatirlatici> hatirlaticiPlani({
  required DateTime simdi,
  required int saat,
  int dakika = 0,
  required int dayStartHour,
  required int bugunBekleyen,
  required int Function(DateTime gun) gunPlanli,
  int gunSayisi = hatirlaticiGunSayisi,
}) {
  final bugun = dayOf(simdi, dayStartHour: dayStartHour);
  final sonuc = <PlanliHatirlatici>[];
  for (var i = 0; i < gunSayisi; i++) {
    final tetik = DateTime(simdi.year, simdi.month, simdi.day + i, saat, dakika);
    if (!tetik.isAfter(simdi)) continue;
    // The tracking day this trigger falls in (a 02:00 reminder belongs to the day before).
    final gun = dayOf(tetik, dayStartHour: dayStartHour);
    final bugunku = gun == bugun;
    if (bugunku ? bugunBekleyen == 0 : gunPlanli(gun) == 0) continue;
    sonuc.add(PlanliHatirlatici(id: hatirlaticiIlkId + i, tetik: tetik, bekleyen: bugunku ? bugunBekleyen : null));
  }
  return sonuc;
}
