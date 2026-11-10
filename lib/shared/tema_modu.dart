import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/constants.dart';
import '../data/providers.dart';

/// Theme preference for the phone: same settings key as the desktop
/// `themeModeProvider`, but defaults to "follow the system" (PLAN) instead of
/// dark. A separate provider because `data/providers.dart` is a synced copy.
///
/// shortcut: the Settings screen still writes through `themeModeProvider`
/// (dark by default); this mirrors its changes. Choosing "Koyu" while nothing
/// is stored yet is not a change for that provider, so the app switches only
/// on the next start. Fix: default `themeModeProvider` to system (declared
/// deviation in kaynak_ozet.json) and drop this file.
class TemaModuNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    ref.listen(themeModeProvider, (_, next) => state = next);
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
