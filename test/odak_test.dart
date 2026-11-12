// Focus timer: focus_running serialisation, session recording rules, and the real controller
// driven by a fake clock and a fake notification layer.
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/features/today/focus_controller.dart';
import 'package:aktenak_habit_tracker/platform/bildirimler.dart';
import 'package:aktenak_habit_tracker/platform/hatirlatici_plani.dart';
import 'package:aktenak_habit_tracker/platform/odak_denetleyici.dart';
import 'package:aktenak_habit_tracker/platform/odak_durumu.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class SahteBildirim implements BildirimKapisi {
  final kurulan = <DateTime>[];
  var iptal = 0;

  @override
  Future<void> hatirlaticilariKur(List<PlanliHatirlatici> plan) async {}

  @override
  Future<void> odakBitisiKur({required DateTime bitis, required String baslik, required String govde}) async =>
      kurulan.add(bitis);

  @override
  Future<void> odakBitisiIptal() async => iptal++;

  @override
  Future<void> izinIste() async {}

  @override
  Future<bool> bildirimIzniVar() async => true;
}

void main() {
  group('focus_running serialisation', () {
    test('round trip keeps start, kind, plan and task', () {
      final s = OdakCalisiyor(
        baslangic: DateTime(2026, 11, 10, 22, 30, 5),
        tur: SessionKind.rest,
        planSn: 300,
        taskId: 7,
      );
      final geri = OdakCalisiyor.fromJson(s.toJson())!;
      expect(geri.baslangic, s.baslangic);
      expect(geri.tur, SessionKind.rest);
      expect(geri.planSn, 300);
      expect(geri.taskId, 7);
      expect(geri.bitis, DateTime(2026, 11, 10, 22, 35, 5));
    });

    test('null task id survives', () {
      final s = OdakCalisiyor(baslangic: DateTime(2026, 1, 1), tur: SessionKind.focus, planSn: 1500);
      expect(OdakCalisiyor.fromJson(s.toJson())!.taskId, isNull);
    });

    test('malformed values read as "no timer", never throw', () {
      for (final bozuk in [
        null,
        '',
        'abc',
        '[]',
        '{}',
        '{"baslangic":"x","tur":"focus","plan_sn":60}',
        '{"baslangic":"2026-01-01T00:00:00Z","tur":"focus","plan_sn":0}',
        '{"baslangic":"2026-01-01T00:00:00Z","tur":"focus","plan_sn":"60"}',
        '{"baslangic":"2026-01-01T00:00:00Z","tur":"focus","plan_sn":60,"task_id":"1"}',
      ]) {
        expect(OdakCalisiyor.fromJson(bozuk), isNull, reason: '$bozuk');
      }
    });

    test('remaining seconds never go below zero', () {
      final s = OdakCalisiyor(baslangic: DateTime(2026, 1, 1, 10), tur: SessionKind.focus, planSn: 60);
      expect(s.kalanSn(DateTime(2026, 1, 1, 10, 0, 20)), 40);
      expect(s.kalanSn(DateTime(2026, 1, 1, 12)), 0);
    });
  });

  group('OdakDeposu', () {
    late AppDatabase db;
    late OdakDeposu depo;
    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      depo = OdakDeposu(db);
    });
    tearDown(() => db.close());

    test('a finished run writes one session with the tracking day and clears the state', () async {
      final b = DateTime(2026, 11, 10, 22, 0);
      await depo.baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 1500));
      expect(await depo.oku(), isNotNull);
      final sn = await depo.bitir(b.add(const Duration(minutes: 25)), dayStartHour: 4, tamamlandi: true);
      expect(sn, 1500);
      final satirlar = await db.getAllSessions();
      expect(satirlar.length, 1);
      expect(satirlar.single.durationS, 1500);
      expect(satirlar.single.kind, 'focus');
      expect(satirlar.single.day, '2026-11-10');
      expect(await depo.oku(), isNull);
    });

    test('a run that ends after midnight but before the day start belongs to the previous day', () async {
      final b = DateTime(2026, 11, 11, 0, 50);
      await depo.baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 1500));
      await depo.bitir(b.add(const Duration(minutes: 25)), dayStartHour: 4, tamamlandi: true);
      expect((await db.getAllSessions()).single.day, '2026-11-10');
    });

    test('under a minute is dropped, but the state is still cleared', () async {
      final b = DateTime(2026, 11, 10, 22, 0);
      await depo.baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 1500));
      expect(await depo.bitir(b.add(const Duration(seconds: 59)), dayStartHour: 4), isNull);
      expect(await db.getAllSessions(), isEmpty);
      expect(await depo.oku(), isNull);
    });

    test('stopped early records the elapsed time; late "rang" is capped at the plan', () async {
      final b = DateTime(2026, 11, 10, 22, 0);
      await depo.baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 1500));
      expect(await depo.bitir(b.add(const Duration(minutes: 10)), dayStartHour: 4), 600);
      await depo.baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 1500));
      // App found the run 3 hours later: only the planned length counts.
      expect(await depo.bitir(b.add(const Duration(hours: 3)), dayStartHour: 4, tamamlandi: true), 1500);
    });

    test('nothing running: no row', () async {
      expect(await depo.bitir(DateTime(2026, 11, 10), dayStartHour: 4), isNull);
      expect(await db.getAllSessions(), isEmpty);
    });

    test('a task deleted meanwhile does not break the insert', () async {
      final b = DateTime(2026, 11, 10, 22, 0);
      await depo.baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 600, taskId: 999));
      await depo.bitir(b.add(const Duration(minutes: 10)), dayStartHour: 4);
      expect((await db.getAllSessions()).single.taskId, isNull);
    });
  });

  group('AndroidFocusController', () {
    late AppDatabase db;
    late SahteBildirim bildirim;
    var an = DateTime(2026, 11, 10, 22, 0);
    late AndroidFocusController c;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      bildirim = SahteBildirim();
      an = DateTime(2026, 11, 10, 22, 0);
      c = AndroidFocusController(db: db, bildirim: bildirim, saat: () => an);
    });
    tearDown(() async {
      c.dispose();
      await db.close();
    });

    test('start persists the state and schedules the end alarm at start + plan', () async {
      c.start(kind: SessionKind.focus, plannedMinutes: 25);
      expect(c.state.value.running, isTrue);
      expect(c.state.value.remainingSeconds, 1500);
      await c.stop(); // flushes the queue; 0 s elapsed -> not saved
      expect(bildirim.kurulan, [DateTime(2026, 11, 10, 22, 25)]);
      expect(bildirim.iptal, 1);
    });

    test('stop after 10 minutes saves a session and emits a not-completed result', () async {
      final sonuclar = <FocusResult>[];
      c.results.listen(sonuclar.add);
      c.start(kind: SessionKind.focus, plannedMinutes: 25, taskId: null);
      an = an.add(const Duration(minutes: 10));
      await c.stop();
      await Future<void>.delayed(Duration.zero);
      expect(c.state.value.running, isFalse);
      expect((await db.getAllSessions()).single.durationS, 600);
      expect(sonuclar.single.saved, isTrue);
      expect(sonuclar.single.completed, isFalse);
      expect(sonuclar.single.durationS, 600);
    });

    test('a run found finished after a restart is recorded once and keeps its notification', () async {
      final b = an;
      await OdakDeposu(db).baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 1500));
      an = b.add(const Duration(minutes: 40)); // process was dead, alarm already rang
      final sonuclar = <FocusResult>[];
      c.results.listen(sonuclar.add);
      await c.yukle();
      await Future<void>.delayed(Duration.zero);
      expect((await db.getAllSessions()).single.durationS, 1500);
      expect(sonuclar.single.completed, isTrue);
      expect(bildirim.iptal, 0);
      expect(await OdakDeposu(db).oku(), isNull);
      await c.yukle(); // second launch: nothing left to record
      expect((await db.getAllSessions()).length, 1);
    });

    test('a run still going after a restart resumes with the right remaining time', () async {
      final b = an;
      await OdakDeposu(db).baslat(OdakCalisiyor(baslangic: b, tur: SessionKind.focus, planSn: 1500));
      an = b.add(const Duration(minutes: 10));
      await c.yukle();
      expect(c.state.value.running, isTrue);
      expect(c.state.value.remainingSeconds, 900);
      await c.stop();
    });

    test('start while running is ignored', () async {
      c.start(kind: SessionKind.focus, plannedMinutes: 25);
      c.start(kind: SessionKind.rest, plannedMinutes: 5);
      expect(c.state.value.kind, SessionKind.focus);
      await c.stop();
      expect(bildirim.kurulan.length, 1);
    });
  });
}
