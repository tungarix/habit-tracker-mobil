// Local notifications (flutter_local_notifications). What to schedule is decided in
// hatirlatici_plani.dart / odak_durumu.dart; this file only talks to Android.
//
// Missing permissions never crash the app: without the notification permission the state reads
// "off", without the exact-alarm permission scheduling falls back to inexact.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/timezone.dart' as tz;

import 'hatirlatici_plani.dart';

/// Focus-timer end notification (one at a time).
const odakBildirimId = 200;

class BildirimDurumu {
  const BildirimDurumu({this.bildirimIzni, this.tamZamanli, this.planli = 0, this.hata});
  final bool? bildirimIzni; // null: not known yet
  final bool? tamZamanli;
  final int planli;
  final String? hata;
}

/// What the rest of the app needs from the notification layer (fakeable in tests).
abstract class BildirimKapisi {
  /// Cancels the previous reminder block, then schedules [plan].
  Future<void> hatirlaticilariKur(List<PlanliHatirlatici> plan);

  /// Exact (allow-while-idle) alarm for the end of a focus run; replaces any earlier one.
  Future<void> odakBitisiKur({required DateTime bitis, required String baslik, required String govde});

  Future<void> odakBitisiIptal();

  /// Asks for the notification permissions; call it from a user action (first timer / reminder).
  Future<void> izinIste();

  /// Whether notifications are allowed right now (false: denied or switched off in system settings).
  Future<bool> bildirimIzniVar();
}

String hatirlaticiGovdesi(int? bekleyen) => bekleyen == null
    ? 'Bugünün alışkanlıklarını işaretlemeyi unutma.'
    : '$bekleyen alışkanlık bugün için hâlâ bekliyor.';

class YerelBildirimler implements BildirimKapisi {
  YerelBildirimler([FlutterLocalNotificationsPlugin? eklenti]) : _p = eklenti ?? FlutterLocalNotificationsPlugin();

  final FlutterLocalNotificationsPlugin _p;
  final ValueNotifier<BildirimDurumu> durum = ValueNotifier(const BildirimDurumu());

  AndroidFlutterLocalNotificationsPlugin? get _android =>
      _p.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();

  Future<void> baslat() async {
    await _p.initialize(
      settings: const InitializationSettings(android: AndroidInitializationSettings('@mipmap/ic_launcher')),
    );
    await _durumOku();
  }

  Future<void> _durumOku({int? planli, String? hata, bool hataTemizle = false}) async {
    final a = _android;
    final eski = durum.value;
    durum.value = BildirimDurumu(
      bildirimIzni: await a?.areNotificationsEnabled(),
      tamZamanli: await a?.canScheduleExactNotifications(),
      planli: planli ?? eski.planli,
      hata: hataTemizle ? null : (hata ?? eski.hata),
    );
  }

  /// Asks for the notification permission (Android 13+) and, on Android 12, the exact-alarm
  /// permission. Call it from a user action: first reminder turned on / first timer started.
  @override
  Future<void> izinIste() async {
    final a = _android;
    await a?.requestNotificationsPermission();
    // Android 13+ grants USE_EXACT_ALARM by itself; on 12 a settings screen opens.
    if (!(await a?.canScheduleExactNotifications() ?? true)) await a?.requestExactAlarmsPermission();
    await _durumOku();
  }

  @override
  Future<bool> bildirimIzniVar() async {
    await _durumOku();
    return durum.value.bildirimIzni != false;
  }

  static const _hatirlaticiDetay = NotificationDetails(
    android: AndroidNotificationDetails(
      'hatirlatici',
      'Akşam hatırlatıcısı',
      channelDescription: 'Bugünün alışkanlıkları tamamlanmadıysa akşam hatırlatır.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  static const _odakDetay = NotificationDetails(
    android: AndroidNotificationDetails(
      'odak',
      'Odak sayacı',
      channelDescription: 'Odak ya da mola süresi bittiğinde haber verir.',
      importance: Importance.high,
      priority: Priority.high,
    ),
  );

  // The instant is converted to UTC so no timezone database lookup is needed: the plugin only
  // stores the absolute time, and local wall-clock times were already resolved by Dart's DateTime.
  static tz.TZDateTime _an(DateTime yerel) => tz.TZDateTime.from(yerel.toUtc(), tz.UTC);

  Future<void> _kur(
    int id,
    DateTime an,
    NotificationDetails detay,
    String baslik,
    String govde, {
    required bool tam,
  }) async {
    Future<void> dene(AndroidScheduleMode mod) => _p.zonedSchedule(
      id: id,
      scheduledDate: _an(an),
      notificationDetails: detay,
      androidScheduleMode: mod,
      title: baslik,
      body: govde,
    );
    try {
      await dene(tam ? AndroidScheduleMode.exactAllowWhileIdle : AndroidScheduleMode.inexactAllowWhileIdle);
    } on PlatformException catch (e) {
      // The exact-alarm permission may have been revoked meanwhile: fall back to inexact.
      if (e.code != 'exact_alarms_not_permitted') rethrow;
      await dene(AndroidScheduleMode.inexactAllowWhileIdle);
    }
  }

  @override
  Future<void> hatirlaticilariKur(List<PlanliHatirlatici> plan) async {
    for (var i = 0; i < hatirlaticiGunSayisi; i++) {
      await _p.cancel(id: hatirlaticiIlkId + i);
    }
    var kurulan = 0;
    String? hata;
    for (final b in plan) {
      try {
        // Reminder timing is approximate on purpose: a few minutes of drift is fine.
        await _kur(b.id, b.tetik, _hatirlaticiDetay, 'Alışkanlıklar', hatirlaticiGovdesi(b.bekleyen), tam: false);
        kurulan++;
      } on PlatformException catch (e) {
        hata = e.message ?? e.code; // one failing notification must not stop the others
      }
    }
    await _durumOku(planli: kurulan, hata: hata, hataTemizle: hata == null);
  }

  @override
  Future<void> odakBitisiKur({required DateTime bitis, required String baslik, required String govde}) async {
    await _p.cancel(id: odakBildirimId);
    await _durumOku();
    await _kur(odakBildirimId, bitis, _odakDetay, baslik, govde, tam: durum.value.tamZamanli ?? false);
  }

  @override
  Future<void> odakBitisiIptal() => _p.cancel(id: odakBildirimId);
}
