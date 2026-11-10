import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/date_symbol_data_local.dart';

import 'app.dart';
import 'data/providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Load locale data so Turkish date formatting works out of the box.
  await initializeDateFormatting('tr');

  // Own container so non-widget code (backup timer) can read providers.
  final container = ProviderContainer();
  _startAutoBackup(container);

  runApp(
    UncontrolledProviderScope(container: container, child: const HabitApp()),
  );
}

/// Daily JSON backup into the app's own folder; checked hourly.
/// shortcut: timer only fires while the process lives; Faz 1 adds the on-resume check.
void _startAutoBackup(ProviderContainer container) {
  Future<void> run() async {
    try {
      final backup = await container.read(autoBackupProvider.future);
      await backup.runIfDue(DateTime.now());
    } catch (_) {
      // A failed backup must never take the app down; next hour retries.
    }
  }

  unawaited(run());
  Timer.periodic(const Duration(hours: 1), (_) => run());
}
