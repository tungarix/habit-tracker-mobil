import 'package:aktenak_habit_tracker/core/date_utils.dart';
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:aktenak_habit_tracker/features/stats/stats_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'b_test_yardimci.dart';

void main() {
  testWidgets('streaks, completion and the 30-day strip are shown', (
    tester,
  ) async {
    final sem = tester.ensureSemantics();
    telefon(tester, height: 1600);
    final db = await bellekDb();
    final t = today();
    final id = await habitEkle(db, 'Kitap', createdAt: DateTime(2026, 1, 1));
    for (var i = 0; i < 3; i++) {
      await db.setEntryStatus(
        id,
        formatYmd(DateTime(t.year, t.month, t.day - i)),
        EntryStatus.done,
      );
    }
    await ac(tester, db, const Scaffold(body: StatsScreen()));

    expect(find.text(Metin.istatistik), findsOneWidget);
    expect(find.text('Kitap'), findsOneWidget);
    expect(find.text('3 ${Metin.gun}'), findsWidgets); // current streak
    expect(
      find.bySemanticsLabel(RegExp('^Kitap, son 30 gün: 3 gün yapıldı')),
      findsOneWidget,
    );
    expect(find.textContaining('Yeterli veri yok'), findsOneWidget);

    await temizle(tester);
    sem.dispose();
  });
}
