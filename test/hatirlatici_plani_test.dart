// Evening-reminder planning: 7 one-off notifications, today's dropped when everything is done.
import 'package:aktenak_habit_tracker/core/constants.dart';
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/platform/hatirlatici_plani.dart';
import 'package:aktenak_habit_tracker/platform/yenileme.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

List<PlanliHatirlatici> plan(
  DateTime simdi, {
  int saat = 20,
  int bekleyen = 3,
  int dayStart = 4,
  int Function(DateTime)? planli,
}) => hatirlaticiPlani(
  simdi: simdi,
  saat: saat,
  dayStartHour: dayStart,
  bugunBekleyen: bekleyen,
  gunPlanli: planli ?? (_) => 2,
);

void main() {
  test('7 days of one-off reminders, ids 100..106, today first when still ahead', () {
    final p = plan(DateTime(2026, 11, 10, 9, 0));
    expect(p.length, 7);
    expect([for (final b in p) b.id], [100, 101, 102, 103, 104, 105, 106]);
    expect(p.first.tetik, DateTime(2026, 11, 10, 20));
    expect(p.last.tetik, DateTime(2026, 11, 16, 20));
    expect(p.first.bekleyen, 3); // today knows its open count
    expect(p[1].bekleyen, isNull); // later days do not
  });

  test('all of today done: today is skipped, the other 6 stay', () {
    final p = plan(DateTime(2026, 11, 10, 9, 0), bekleyen: 0);
    expect(p.length, 6);
    expect(p.first.tetik, DateTime(2026, 11, 11, 20));
    expect(p.first.id, 101);
  });

  test('after the reminder hour today is past: starts tomorrow, ids keep the day offset', () {
    final p = plan(DateTime(2026, 11, 10, 21, 0));
    expect(p.length, 6);
    expect(p.first.id, 101);
    expect(p.first.tetik, DateTime(2026, 11, 11, 20));
  });

  test('past midnight but before day start: the 02:00 reminder belongs to the previous day', () {
    // 01:00 on the 11th is still tracking day the 10th (day start 04:00). A 02:00 reminder fires
    // today-clock but belongs to the 10th: with everything done it is dropped.
    final simdi = DateTime(2026, 11, 11, 1, 0);
    final tamam = plan(simdi, saat: 2, bekleyen: 0);
    expect(tamam.any((b) => b.tetik == DateTime(2026, 11, 11, 2)), isFalse);
    final acik = plan(simdi, saat: 2, bekleyen: 2);
    expect(acik.first.tetik, DateTime(2026, 11, 11, 2));
    expect(acik.first.bekleyen, 2);
  });

  test('a day with no habits scheduled gets no reminder', () {
    // Only Mondays and Tuesdays have habits (DateTime weekday 1, 2).
    final p = plan(DateTime(2026, 11, 10, 9, 0), planli: (g) => g.weekday <= 2 ? 1 : 0);
    // 10 Nov 2026 is a Tuesday: Tue (today, via bekleyen) and Mon the 16th qualify; Wed..Sun do not.
    expect([for (final b in p) b.tetik.weekday], [2, 1]);
  });

  test('DST-free local arithmetic: month rollover', () {
    final p = plan(DateTime(2026, 12, 29, 9, 0));
    expect(p.last.tetik, DateTime(2027, 1, 4, 20));
  });

  group('plan from the database', () {
    late AppDatabase db;
    setUp(() => db = AppDatabase.forTesting(NativeDatabase.memory()));
    tearDown(() => db.close());

    Future<int> alisanlik(String ad, {String hafta = ''}) => db.insertHabit(
      HabitsCompanion.insert(
        name: ad,
        colorValue: 0xFF4CAF50,
        iconCodePoint: 0xe000,
        scheduledWeekdays: Value(hafta),
      ),
    );

    test('reminder off (no setting) -> empty plan', () async {
      await alisanlik('Kitap');
      expect(await hatirlaticiPlaniniHesapla(db, DateTime(2026, 11, 10, 9)), isEmpty);
    });

    test('open habit today keeps today; marking it done drops today', () async {
      final id = await alisanlik('Kitap');
      await db.setSetting(AppConstants.reminderHourKey, '20');
      final simdi = DateTime(2026, 11, 10, 9);
      var p = await hatirlaticiPlaniniHesapla(db, simdi);
      expect(p.length, 7);
      expect(p.first.bekleyen, 1);

      await db.setEntryStatus(id, '2026-11-10', EntryStatus.done);
      p = await hatirlaticiPlaniniHesapla(db, simdi);
      expect(p.length, 6);
      expect(p.first.tetik, DateTime(2026, 11, 11, 20));
    });

    test('empty hour setting means off', () async {
      await alisanlik('Kitap');
      await db.setSetting(AppConstants.reminderHourKey, '');
      expect(await hatirlaticiSaati(db), isNull);
    });
  });
}
