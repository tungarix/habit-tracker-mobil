import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/providers.dart';

/// Theme preference for the phone: same settings key as the desktop
/// `themeModeProvider`, but defaults to "follow the system" (PLAN) instead of
/// dark. A separate provider because `data/providers.dart` is a synced copy;
/// the app and the Settings screen both use this one, never the desktop one.
class TemaModuNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    _load();
    return ThemeMode.system;
  }

  Future<void> _load() async {
    final stored = await ref
        .read(databaseProvider)
        .getSetting(AppConstants.themeModeKey);
    for (final mode in ThemeMode.values) {
      if (mode.name == stored) state = mode;
    }
  }

  Future<void> set(ThemeMode mode) async {
    state = mode;
    await ref
        .read(databaseProvider)
        .setSetting(AppConstants.themeModeKey, mode.name);
  }
}

final temaModuProvider = NotifierProvider<TemaModuNotifier, ThemeMode>(
  TemaModuNotifier.new,
);
