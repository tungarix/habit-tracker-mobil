import 'package:aktenak_habit_tracker/app.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

/// todayProvider's rollover Timer does not tick while the phone sleeps, so coming back to the
/// foreground must recompute the day by itself.
void main() {
  testWidgets('uygulama öne dönünce bugün yeniden hesaplanır', (tester) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    var yenilenme = 0;
    await tester.pumpWidget(
      ProviderScope(
        // ignore: argument_type_not_assignable
        overrides: [databaseProvider.overrideWithValue(db)],
        observers: [_BugunIzleyici(() => yenilenme++)],
        child: const HabitApp(),
      ),
    );
    await bekle(tester);
    expect(yenilenme, 0);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await bekle(tester, 2);
    expect(yenilenme, 0, reason: 'arka plana gitmek günü yenilemez');

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await bekle(tester);
    expect(yenilenme, greaterThan(0), reason: 'öne dönünce todayProvider geçersiz kılınmalı');
    await temizle(tester);
  });
}

/// Counts how often todayProvider is thrown away (invalidated or disposed).
base class _BugunIzleyici extends ProviderObserver {
  _BugunIzleyici(this._say);
  final void Function() _say;

  @override
  void didDisposeProvider(ProviderObserverContext context) {
    if (context.provider == todayProvider) _say();
  }
}
