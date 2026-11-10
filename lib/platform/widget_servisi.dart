// Home-screen widget glue (home_widget). The Kotlin side is HabitWidgetProvider.
//
// Flow: the widget row tap sends `habitwidget://isaretle?id=<habitId>` to [widgetArkaPlan] (a Dart
// background callback), which writes the check through the shared database connection
// (db_baglanti.dart), then refreshes the widget and the reminder plan. Writing goes through the
// same single database server isolate as the UI, so a UI that is open sees it right away.
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:home_widget/home_widget.dart';

import '../core/date_utils.dart';
import '../core/enums.dart';
import '../data/database/database.dart';
import 'bildirimler.dart';
import 'bugun_ozeti.dart';
import 'db_baglanti.dart';
import 'yenileme.dart';

const widgetSaglayici = 'com.aktenak.habit_tracker.HabitWidgetProvider';
const widgetUriSemasi = 'habitwidget';
const widgetUriIsaretle = 'isaretle';

/// JSON the Kotlin provider reads (`widget_items`).
String widgetOgeleriJson(List<BugunSatiri> satirlar) => jsonEncode([
  for (final s in satirlar) {'id': s.id, 'ad': s.ad, 'yapildi': s.yapildi},
]);

/// Epoch ms after which the provider treats the list as stale (`widget_bitis`).
int widgetBitisMs(BugunOzeti ozet) => ozet.gunBitisi.millisecondsSinceEpoch;

/// The habit id in a widget tap URI, or null for anything that is not exactly our URI.
/// The background receiver is not exported, but the value is still validated: it is input.
int? widgetUriCoz(Uri? uri) {
  if (uri == null || uri.scheme != widgetUriSemasi || uri.host != widgetUriIsaretle) return null;
  final id = int.tryParse(uri.queryParameters['id'] ?? '');
  return (id != null && id > 0) ? id : null;
}

/// Writes ✓ for [habitId] on today's tracking day. Returns whether anything was written: unknown,
/// archived or not-scheduled-today habits and already-✓ cells are left alone (a tap never undoes).
Future<bool> widgetIsaretle(AppDatabase db, int habitId, DateTime simdi) async {
  final ozet = await bugunOzeti(db, simdi);
  final satir = ozet.satirlar.where((s) => s.id == habitId).firstOrNull;
  if (satir == null || satir.yapildi) return false;
  // A count habit records its full target, so the cell reads ✓ in the app as well.
  await db.setEntryStatus(habitId, formatYmd(ozet.gun), EntryStatus.done, amount: satir.hedef);
  return true;
}

/// Pushes today's list to the widget storage and asks Android to redraw it.
Future<void> widgetiYenile(BugunOzeti ozet) async {
  await HomeWidget.saveWidgetData<String>('widget_items', widgetOgeleriJson(ozet.satirlar));
  await HomeWidget.saveWidgetData<int>('widget_bitis', widgetBitisMs(ozet));
  await HomeWidget.updateWidget(qualifiedAndroidName: widgetSaglayici);
}

/// Registers the tap callback. The callback handle can change with every build, so call this on
/// every app start, not once.
Future<void> widgetKaydet() => HomeWidget.registerInteractivityCallback(widgetArkaPlan);

/// Runs in the home_widget background engine (possibly with the UI closed).
@pragma('vm:entry-point')
Future<void> widgetArkaPlan(Uri? uri) async {
  WidgetsFlutterBinding.ensureInitialized();
  final id = widgetUriCoz(uri);
  if (id == null) return;
  final db = AppDatabase.forTesting(dbBaglantisi());
  try {
    await widgetIsaretle(db, id, DateTime.now());
    final bildirim = YerelBildirimler();
    await bildirim.baslat();
    await yanEtkileriYenile(db, bildirim);
  } finally {
    await db.close();
  }
}
