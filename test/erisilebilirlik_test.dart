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

  // Aylık, İstatistik, Alışkanlıklar and Ayarlar, both themes. Aylık is exempt from the 48 dp
  // rule only: PLAN Faz 1 asks for 44 px cells there (a deliberate conflict with the 48 dp
  // rule, reported to Arda); labels and contrast still apply to it.
  for (final koyu in [false, true]) {
    testWidgets(
      'erişilebilirlik: Aylık, İstatistik, Alışkanlıklar, Ayarlar (${koyu ? "koyu" : "açık"})',
      (tester) async {
        telefonBoyutu(tester, yukseklik: 900);
        tester.platformDispatcher.platformBrightnessTestValue =
            koyu ? Brightness.dark : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        final handle = tester.ensureSemantics();
        final db = await bellekDb();
        await aliskanlikEkle(db, 'Kitap');
        await aliskanlikEkle(db, 'Su', kind: 'count', target: 8);
        await uygulamaAc(tester, db);

        Future<void> denetle({bool dokunma = true}) async {
          if (dokunma) {
            await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          }
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }

        Future<void> sekme(String ad) async {
          await tester.tap(find.descendant(
            of: find.byType(NavigationBar),
            matching: find.text(ad),
          ));
          await bekle(tester);
        }

        await sekme(Metin.sekmeAylik);
        await denetle(dokunma: false);
        await sekme(Metin.sekmeIstatistik);
        await denetle();
        await sekme(Metin.sekmeBugun);

        for (final ad in [Metin.menuAliskanliklar, Metin.menuAyarlar]) {
          await tester.tap(find.byTooltip(Metin.menu));
          await bekle(tester);
          await tester.tap(find.text(ad));
          await bekle(tester);
          await denetle();
          Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
          await bekle(tester);
        }

        handle.dispose();
        await temizle(tester);
      },
    );
  }

  testWidgets('Tüm ekranlarda 12 px altı yazı yok', (tester) async {
    telefonBoyutu(tester, yukseklik: 900);
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

    Future<void> sekme(String ad) async {
      await tester.tap(find.descendant(
        of: find.byType(NavigationBar),
        matching: find.text(ad),
      ));
      await bekle(tester);
      tara();
    }

    tara();
    await sekme(Metin.sekmeGorevler);
    await sekme(Metin.sekmeAylik);
    await sekme(Metin.sekmeIstatistik);
    await sekme(Metin.sekmeBugun);
    for (final ad in [Metin.menuAliskanliklar, Metin.menuAyarlar]) {
      await tester.tap(find.byTooltip(Metin.menu));
      await bekle(tester);
      await tester.tap(find.text(ad));
      await bekle(tester);
      tara();
      Navigator.of(tester.element(find.byType(Scaffold).last)).pop();
      await bekle(tester);
    }
    await temizle(tester);
  });
}
