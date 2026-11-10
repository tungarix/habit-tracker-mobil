import 'package:aktenak_habit_tracker/core/date_utils.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

/// WCAG-style checks on the rendered screens (PLAN: AA, 48 dp, labelled
/// targets), in both themes, with a full Bugün screen and a task list.
void main() {
  for (final koyu in [false, true]) {
    testWidgets('erişilebilirlik kuralları: ${koyu ? "koyu" : "açık"} tema', (
      tester,
    ) async {
      telefonBoyutu(tester);
      tester.platformDispatcher.platformBrightnessTestValue =
          koyu ? Brightness.dark : Brightness.light;
      addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
      final handle = tester.ensureSemantics();

      final db = await bellekDb();
      await aliskanlikEkle(db, 'Kitap');
      await aliskanlikEkle(db, 'Su', kind: 'count', target: 8);
      final yarin = DateTime.now().add(const Duration(days: 1));
      await db.insertTask(
        TasksCompanion.insert(
          title: 'Fatura',
          dueDay: Value(formatYmd(DateTime(yarin.year, yarin.month, yarin.day))),
        ),
      );
      await uygulamaAc(tester, db);

      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(Metin.sekmeGorevler),
      ));
      await bekle(tester);
      await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
      await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
      await expectLater(tester, meetsGuideline(textContrastGuideline));

      handle.dispose();
      await temizle(tester);
    });
  }

  testWidgets('Bugün ve Görevler ekranlarında 12 px altı yazı yok', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    await aliskanlikEkle(db, 'Su', kind: 'count', target: 8);
    await uygulamaAc(tester, db);

    void tara() {
      for (final rt in tester.widgetList<RichText>(find.byType(RichText))) {
        final boyut = rt.text.style?.fontSize;
        if (boyut != null) {
          expect(boyut, greaterThanOrEqualTo(12), reason: rt.text.toPlainText());
        }
      }
    }

    tara();
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(Metin.sekmeGorevler),
    ));
    await bekle(tester);
    tara();
    await temizle(tester);
  });
}
