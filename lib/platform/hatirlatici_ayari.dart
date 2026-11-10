// Real [ReminderSettings]: hour stored in the Settings table, plan rescheduled on every change.
import '../core/constants.dart';
import '../data/database/database.dart';
import '../features/settings/reminder_settings.dart';
import 'bildirimler.dart';
import 'yenileme.dart';

class AndroidReminderSettings implements ReminderSettings {
  AndroidReminderSettings(this.db, this.bildirim);

  final AppDatabase db;
  final YerelBildirimler bildirim;

  @override
  Future<int?> readHour() => hatirlaticiSaati(db);

  @override
  Future<void> writeHour(int? hour) async {
    final saat = hour?.clamp(0, 23);
    await db.setSetting(AppConstants.reminderHourKey, saat == null ? '' : '$saat');
    // Turning the reminder on is the user action that asks for the permission.
    if (saat != null) await bildirim.izinIste();
    await yanEtkileriYenile(db, bildirim);
  }
}
