// The watcher re-plans reminders on open and after a database change (mark, habit, setting).
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/platform/bildirimler.dart';
import 'package:aktenak_habit_tracker/platform/hatirlatici_plani.dart';
import 'package:aktenak_habit_tracker/platform/yan_etki_izleyici.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Sayac implements BildirimKapisi {
  var kurulum = 0;

  @override
  Future<void> hatirlaticilariKur(List<PlanliHatirlatici> plan) async => kurulum++;

  @override
  Future<void> odakBitisiKur({required DateTime bitis, required String baslik, required String govde}) async {}

  @override
  Future<void> odakBitisiIptal() async {}

  @override
  Future<void> izinIste() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('refreshes on start and again after a settings change', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final sayac = _Sayac();
    final izleyici = YanEtkiIzleyici(db, sayac, bekleme: const Duration(milliseconds: 10));
    addTearDown(izleyici.stop);

    izleyici.start();
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(sayac.kurulum, greaterThanOrEqualTo(1));

    final once = sayac.kurulum;
    await db.setSetting('reminder_hour', '20');
    await Future<void>.delayed(const Duration(milliseconds: 200));
    expect(sayac.kurulum, greaterThan(once));
  });
}
