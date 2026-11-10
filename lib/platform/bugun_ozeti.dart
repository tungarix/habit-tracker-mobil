// Today's habit list as the widget and the reminder see it. Reads straight from the database
// (no Riverpod): the widget callback runs in a background isolate without a ProviderContainer.
import '../core/constants.dart';
import '../core/date_utils.dart';
import '../core/enums.dart';
import '../data/database/database.dart';

class BugunSatiri {
  const BugunSatiri({required this.id, required this.ad, required this.yapildi, required this.hedef});
  final int id;
  final String ad;
  final bool yapildi;

  /// Daily target (1 for yes/no habits); a widget tap on a count habit records the full target.
  final int hedef;
}

class BugunOzeti {
  const BugunOzeti({
    required this.gun,
    required this.dayStartHour,
    required this.satirlar,
    required this.aktifAlisanliklar,
  });

  /// Current tracking day.
  final DateTime gun;
  final int dayStartHour;

  /// Habits scheduled today, in list order.
  final List<BugunSatiri> satirlar;
  final List<Habit> aktifAlisanliklar;

  int get bekleyen => satirlar.where((s) => !s.yapildi).length;

  /// How many habits are scheduled on [gun] (any day).
  int gunPlanli(DateTime gun) => aktifAlisanliklar.where((h) => isScheduledOn(h.scheduledWeekdays, gun)).length;

  /// Instant the current tracking day ends.
  DateTime get gunBitisi => DateTime(gun.year, gun.month, gun.day + 1, dayStartHour);
}

Future<int> gunBaslangicSaati(AppDatabase db) async {
  final p = int.tryParse(await db.getSetting(AppConstants.dayStartHourKey) ?? '');
  return (p != null && p >= 0 && p <= 12) ? p : AppConstants.defaultDayStartHour;
}

Future<BugunOzeti> bugunOzeti(AppDatabase db, DateTime simdi) async {
  final saat = await gunBaslangicSaati(db);
  final gun = dayOf(simdi, dayStartHour: saat);
  final aktif = (await db.getAllHabits()).where((h) => h.archivedAt == null).toList()
    ..sort((a, b) => a.sortOrder.compareTo(b.sortOrder));
  final tarih = formatYmd(gun);
  final yapilanlar = {
    for (final e in await db.getAllEntries())
      if (e.date == tarih && e.status == EntryStatus.done) e.habitId,
  };
  return BugunOzeti(
    gun: gun,
    dayStartHour: saat,
    aktifAlisanliklar: aktif,
    satirlar: [
      for (final h in aktif)
        if (isScheduledOn(h.scheduledWeekdays, gun))
          BugunSatiri(id: h.id, ad: h.name, yapildi: yapilanlar.contains(h.id), hedef: h.target),
    ],
  );
}
