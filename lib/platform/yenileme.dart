// Side effects that must follow every change to today's marks: the widget and the reminder plan.
// Call [yanEtkileriYenile] on app open, after every mark and after every widget write.
import '../core/constants.dart';
import '../data/database/database.dart';
import 'bildirimler.dart';
import 'bugun_ozeti.dart';
import 'hatirlatici_plani.dart';
import 'widget_servisi.dart';

/// Reminder hour from Settings (0-23); null = off (absent or empty).
Future<int?> hatirlaticiSaati(AppDatabase db) async {
  final p = int.tryParse(await db.getSetting(AppConstants.reminderHourKey) ?? '');
  return (p != null && p >= 0 && p <= 23) ? p : null;
}

/// The reminder plan for [simdi]; empty when the reminder is off.
Future<List<PlanliHatirlatici>> hatirlaticiPlaniniHesapla(AppDatabase db, DateTime simdi, {BugunOzeti? ozet}) async {
  final saat = await hatirlaticiSaati(db);
  if (saat == null) return const [];
  final o = ozet ?? await bugunOzeti(db, simdi);
  return hatirlaticiPlani(
    simdi: simdi,
    saat: saat,
    dayStartHour: o.dayStartHour,
    bugunBekleyen: o.bekleyen,
    gunPlanli: o.gunPlanli,
  );
}

/// Redraws the widget and re-plans the reminders. Each part is independent: a failing widget
/// channel must not stop the reminders (and vice versa).
Future<void> yanEtkileriYenile(AppDatabase db, BildirimKapisi bildirim, {DateTime? simdi}) async {
  final an = simdi ?? DateTime.now();
  final ozet = await bugunOzeti(db, an);
  try {
    await widgetiYenile(ozet);
  } catch (_) {
    // No widget on screen / channel unavailable: nothing to refresh.
  }
  try {
    await bildirim.hatirlaticilariKur(await hatirlaticiPlaniniHesapla(db, an, ozet: ozet));
  } catch (_) {
    // Reminders are best effort; the next open or mark retries.
  }
}
