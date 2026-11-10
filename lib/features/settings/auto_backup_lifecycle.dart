import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';

/// Takes the daily auto-backup at launch and whenever the app returns to the
/// foreground (a phone app is rarely "running" for a whole day, so the
/// desktop's hourly timer would almost never fire).
///
/// `main()` creates one with its [ProviderContainer] and calls [start].
class AutoBackupLifecycle with WidgetsBindingObserver {
  AutoBackupLifecycle(this._container, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  final ProviderContainer _container;
  final DateTime Function() _clock;
  bool _running = false;

  void start() {
    WidgetsBinding.instance.addObserver(this);
    unawaited(runNow());
  }

  void stop() => WidgetsBinding.instance.removeObserver(this);

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(runNow());
  }

  /// Takes today's backup if it is missing. Never throws: a failed backup must
  /// not take the app down, and the next resume retries.
  Future<void> runNow() async {
    if (_running) return;
    _running = true;
    try {
      final backup = await _container.read(autoBackupProvider.future);
      final made = await backup.runIfDue(_clock());
      if (made != null) _container.invalidate(latestAutoBackupProvider);
    } catch (_) {
      // See above.
    } finally {
      _running = false;
    }
  }
}
