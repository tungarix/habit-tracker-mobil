import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/platform/bildirimler.dart';
import 'package:aktenak_habit_tracker/platform/hatirlatici_ayari.dart';
import 'package:aktenak_habit_tracker/platform/hatirlatici_plani.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

class _Bildirim implements BildirimKapisi {
  var izinSorusu = 0;
  var izin = true;

  @override
  Future<void> izinIste() async => izinSorusu++;

  @override
  Future<bool> bildirimIzniVar() async => izin;

  @override
  Future<void> hatirlaticilariKur(List<PlanliHatirlatici> plan) async {}

  @override
  Future<void> odakBitisiKur({required DateTime bitis, required String baslik, required String govde}) async {}

  @override
  Future<void> odakBitisiIptal() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _Bildirim bildirim;
  late AndroidReminderSettings ayar;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    bildirim = _Bildirim();
    ayar = AndroidReminderSettings(db, bildirim);
  });
  tearDown(() => db.close());

  test('asks for the permission when the reminder is turned on, not on every hour change', () async {
    await ayar.writeHour(20);
    expect(bildirim.izinSorusu, 1);
    // Slider ticks while the reminder stays on.
    await ayar.writeHour(21);
    await ayar.writeHour(22);
    expect(bildirim.izinSorusu, 1);
    expect(await ayar.readHour(), 22);
    // Off, then on again: a fresh user action asks again.
    await ayar.writeHour(null);
    await ayar.writeHour(20);
    expect(bildirim.izinSorusu, 2);
  });

  test('izinVar reports the notification layer', () async {
    expect(await ayar.izinVar(), isTrue);
    bildirim.izin = false;
    expect(await ayar.izinVar(), isFalse);
  });
}
