import 'package:aktenak_habit_tracker/core/date_utils.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/features/tasks/tasks_screen.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  testWidgets('Görevler: aciliyete göre gruplanır, dokununca biter', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    final bugun = DateTime.now();
    String gun(int fark) =>
        formatYmd(DateTime(bugun.year, bugun.month, bugun.day + fark));
    // Noon avoids the 04:00 day boundary: "today" below is today for sure.
    Future<void> ekle(String baslik, String? vade) => db.insertTask(
      TasksCompanion.insert(title: baslik, dueDay: Value(vade)),
    );
    await ekle('Geçmiş iş', gun(-3));
    await ekle('Yarının işi', gun(1));
    await ekle('Başıboş iş', null);
    await uygulamaAc(tester, db);

    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(Metin.sekmeGorevler),
    ));
    await bekle(tester);

    Finder tabloda(String metin) => find.descendant(
      of: find.byType(TasksScreen),
      matching: find.text(metin),
    );
    for (final baslik in [
      Metin.grupGeciken,
      Metin.grupYarin,
      Metin.grupTarihsiz,
    ]) {
      expect(tabloda(baslik), findsOneWidget, reason: baslik);
    }
    expect(tabloda(Metin.grupBugun), findsNothing);

    await tester.tap(find.text('Başıboş iş'));
    await bekle(tester);
    // Done tasks leave the open groups and are counted behind "Bitenler".
    expect(tabloda('Başıboş iş'), findsNothing);
    expect(tabloda(Metin.bitenler(1)), findsOneWidget);

    await temizle(tester);
  });

  testWidgets('Görevler: boş durumda davet gösterir', (tester) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    await uygulamaAc(tester, db);
    await tester.tap(find.descendant(
      of: find.byType(NavigationBar),
      matching: find.text(Metin.sekmeGorevler),
    ));
    await bekle(tester);
    expect(find.text(Metin.gorevYok), findsOneWidget);
    expect(find.text(Metin.gorevEkle), findsOneWidget);
    await temizle(tester);
  });
}
