import 'package:aktenak_habit_tracker/features/habits/habits_screen.dart';
import 'package:aktenak_habit_tracker/features/settings/settings_screen.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  testWidgets('kabuk: 4 sekme, dar ekranda alt menü, Bugün ile açılır', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    await uygulamaAc(tester, db);

    // Mobile default is "follow the system" (PLAN).
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    final bar = find.byType(NavigationBar);
    expect(bar, findsOneWidget);
    expect(find.byType(NavigationRail), findsNothing);
    expect(
      find.descendant(of: bar, matching: find.byType(NavigationDestination)),
      findsNWidgets(4),
    );
    for (final etiket in [
      Metin.sekmeBugun,
      Metin.sekmeGorevler,
      Metin.sekmeAylik,
      Metin.sekmeIstatistik,
    ]) {
      expect(
        find.descendant(of: bar, matching: find.text(etiket)),
        findsOneWidget,
        reason: etiket,
      );
    }
    // Bugün is the opening tab: its day title is visible, Görevler' is not.
    final bugun = tester
        .widget<NavigationBar>(bar)
        .selectedIndex;
    expect(bugun, 0);
    final appBarBaslik = find.descendant(
      of: find.byType(AppBar),
      matching: find.text(Metin.gorevlerBaslik),
    );
    expect(appBarBaslik, findsNothing);

    await tester.tap(
      find.descendant(of: bar, matching: find.text(Metin.sekmeGorevler)),
    );
    await bekle(tester);
    expect(tester.widget<NavigationBar>(bar).selectedIndex, 1);
    expect(appBarBaslik, findsOneWidget);
    expect(find.text(Metin.gorevYok), findsOneWidget);

    await temizle(tester);
  });

  testWidgets('Bugün menüsü Alışkanlıklar ve Ayarlar ekranlarını üstüne açar', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    await uygulamaAc(tester, db);

    await tester.tap(find.byTooltip(Metin.menu));
    await bekle(tester);
    await tester.tap(find.text(Metin.menuAyarlar));
    await bekle(tester);
    // A pushed route on top of the shell, not a fifth tab.
    expect(find.byType(SettingsScreen), findsOneWidget);
    expect(Navigator.of(tester.element(find.byType(SettingsScreen))).canPop(),
        isTrue);

    Navigator.of(tester.element(find.byType(SettingsScreen))).pop();
    await bekle(tester);
    expect(find.byType(SettingsScreen), findsNothing);

    await tester.tap(find.byTooltip(Metin.menu));
    await bekle(tester);
    await tester.tap(find.text(Metin.menuAliskanliklar));
    await bekle(tester);
    expect(find.byType(HabitsScreen), findsOneWidget);

    await temizle(tester);
  });
}
