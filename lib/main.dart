import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/database/database.dart';
import 'data/providers.dart';
import 'features/settings/auto_backup_lifecycle.dart';
import 'features/settings/reminder_settings.dart';
import 'features/today/focus_controller.dart';
import 'platform/bildirimler.dart';
import 'platform/db_baglanti.dart';
import 'platform/hatirlatici_ayari.dart';
import 'platform/kopru.dart';
import 'platform/odak_denetleyici.dart';
import 'platform/widget_servisi.dart';
import 'platform/yan_etki_izleyici.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load locale data so Turkish date formatting works out of the box.
  await initializeDateFormatting('tr');

  // One database server isolate shared with the home-screen widget callback.
  final db = AppDatabase.forTesting(dbBaglantisi());
  final bildirim = YerelBildirimler();
  try {
    await bildirim.baslat();
  } catch (_) {
    // Notifications are optional; the app must still open.
  }
  try {
    // The callback handle can change with every build, so register on every start.
    await widgetKaydet();
  } catch (_) {
    // No widget host available: nothing to register.
  }

  final odak = AndroidFocusController(db: db, bildirim: bildirim);
  try {
    await odak.yukle();
  } catch (_) {
    // A damaged focus_running value must not block startup.
  }

  final container = ProviderContainer(
    overrides: [
      databaseProvider.overrideWithValue(db),
      kopruProvider.overrideWithValue(AndroidKopru()),
      focusControllerProvider.overrideWithValue(odak),
      reminderSettingsProvider.overrideWithValue(
        AndroidReminderSettings(db, bildirim),
      ),
    ],
  );
  AutoBackupLifecycle(container).start();
  YanEtkiIzleyici(db, bildirim).start();

  runApp(
    UncontrolledProviderScope(container: container, child: const HabitApp()),
  );
}
