import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_format.dart';
import 'package:aktenak_habit_tracker/features/habits/habit_edit_dialog.dart';
import 'package:aktenak_habit_tracker/features/tasks/task_edit_dialog.dart';
import 'package:aktenak_habit_tracker/shared/widgets/count_entry_dialog.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers.dart';
import 'ui_yardimci.dart';

/// Arayüz girişi senkron ayrıştırıcısının sınırlarını aşamaz: aşarsa kayıt sessizce düşer ya da
/// telefonun kendi .habitsync dosyası reddedilir (desktop test/girdi_siniri_test.dart'ın karşılığı).
void main() {
  testWidgets('alışkanlık adı, açıklama ve hedef sınırlarda kısılır', (tester) async {
    telefonBoyutu(tester, yukseklik: 1400);
    final db = await bellekDb();
    await tester.pumpWidget(
      ProviderScope(
        // ignore: argument_type_not_assignable
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => HabitEditDialog.show(c),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await bekle(tester);

    Finder alan(String etiket) => find.descendant(
      of: find.byType(AlertDialog),
      matching: find.widgetWithText(TextField, etiket),
    );
    await tester.enterText(alan(Metin.ad), 'a' * (syncMaxHabitName + 50));
    await tester.enterText(alan(Metin.aciklama), 'b' * (syncMaxTextLength + 50));
    await tester.tap(find.text(HabitKind.count.label));
    await bekle(tester, 2);
    await tester.enterText(alan(Metin.gunlukHedefAlan), '9999999999');
    await tester.tap(find.text(Metin.kaydet));
    await bekle(tester);

    final h = (await db.getAllHabits()).single;
    expect(h.name.length, syncMaxHabitName);
    expect(h.description!.length, syncMaxTextLength);
    expect(h.target, lessThanOrEqualTo(syncMaxCount));
    await temizle(tester);
  });

  testWidgets('görev başlığı (diyalog) sınırda kısılır', (tester) async {
    telefonBoyutu(tester, yukseklik: 1400);
    final db = await bellekDb();
    await tester.pumpWidget(
      ProviderScope(
        // ignore: argument_type_not_assignable
        overrides: [databaseProvider.overrideWithValue(db)],
        child: MaterialApp(
          home: Builder(
            builder: (c) => TextButton(
              onPressed: () => TaskEditDialog.show(c),
              child: const Text('ac'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await bekle(tester);
    await tester.enterText(
      find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)),
      'c' * (syncMaxTaskTitle + 50),
    );
    await tester.tap(find.text(Metin.kaydet));
    await bekle(tester);
    expect((await db.getAllTasks()).single.title.length, syncMaxTaskTitle);
    await temizle(tester);
  });

  testWidgets('hızlı eklenen görev başlığı sınırda kısılır', (tester) async {
    telefonBoyutu(tester, yukseklik: 1400);
    final db = await bellekDb();
    await uygulamaAc(tester, db);
    await tester.enterText(
      find.widgetWithText(TextField, Metin.hizliEkleIpucu),
      'd' * (syncMaxTaskTitle + 50),
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await bekle(tester);
    expect((await db.getAllTasks()).single.title.length, syncMaxTaskTitle);
    await temizle(tester);
  });

  testWidgets('sayaç miktarı senkron sınırını aşamaz', (tester) async {
    int? sonuc;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (c) => TextButton(
            onPressed: () async => sonuc = await CountEntryDialog.show(
              c,
              habit: testHabit(kind: 'count', target: 10000),
              current: 0,
            ),
            child: const Text('ac'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('ac'));
    await bekle(tester, 3);
    await tester.enterText(find.byType(TextField), '99999999999');
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await bekle(tester, 3);
    expect(sonuc, syncMaxCount);
  });
}
