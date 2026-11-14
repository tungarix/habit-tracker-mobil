import 'package:aktenak_habit_tracker/core/date_utils.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

String _gun(int onceki) =>
    formatYmd(DateTime.now().subtract(Duration(days: onceki + 2)));

Future<void> _gecmiseGit(WidgetTester tester) async {
  final b = find.byTooltip(Metin.gecmis);
  await tester.ensureVisible(b);
  await tester.tap(b);
  await bekle(tester);
}

void main() {
  testWidgets('Geçmiş: notlar yeniden eskiye sıralı görünür', (tester) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await db.setMood(_gun(1), 2, note: 'eski not');
    await db.setMood(_gun(0), 4, note: 'yeni not');
    await uygulamaAc(tester, db);
    await _gecmiseGit(tester);

    expect(find.text(Metin.moodGecmisiBaslik), findsOneWidget);
    expect(
      tester.getTopLeft(find.text('yeni not')).dy,
      lessThan(tester.getTopLeft(find.text('eski not')).dy),
    );
    await temizle(tester);
  });

  testWidgets('Geçmiş: silme onayı iptalde korur, Sil siler', (tester) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await db.setMood(_gun(0), 4, note: 'silinecek');
    await uygulamaAc(tester, db);
    await _gecmiseGit(tester);

    await tester.tap(find.byWidgetPredicate((w) => w is IconButton && (w.tooltip ?? '').startsWith('${Metin.sil}: ')));
    await bekle(tester);
    expect(find.text(Metin.gunSilBaslik), findsOneWidget);
    await tester.tap(find.text(Metin.iptal));
    await bekle(tester);
    expect(await tester.runAsync(() => db.getAllMoods()), hasLength(1));
    expect(find.text('silinecek'), findsOneWidget);

    await tester.tap(find.byWidgetPredicate((w) => w is IconButton && (w.tooltip ?? '').startsWith('${Metin.sil}: ')));
    await bekle(tester);
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(Metin.sil),
      ),
    );
    await bekle(tester);
    expect(await tester.runAsync(() => db.getAllMoods()), isEmpty);
    expect(find.text('silinecek'), findsNothing);
    expect(find.text(Metin.moodGecmisiYok), findsOneWidget);
    await temizle(tester);
  });

  testWidgets('Geçmiş: not düzenlenir, Notu sil notu temizler ruh hali kalır', (
    tester,
  ) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    final gun = _gun(0);
    await db.setMood(gun, 4, note: 'ilk');
    await uygulamaAc(tester, db);
    await _gecmiseGit(tester);

    await tester.tap(find.text('ilk'));
    await bekle(tester);
    // Geçmiş günün penceresi "Bugüne" demez; günün kendi başlığını taşır.
    expect(find.text(Metin.notBaslik), findsNothing);
    expect(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text(Metin.gunBasligi(parseYmd(gun))),
      ),
      findsOneWidget,
    );
    await tester.enterText(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.byType(TextField),
      ),
      'güncel',
    );
    await tester.tap(find.text(Metin.kaydet));
    await bekle(tester);
    expect(find.text('güncel'), findsOneWidget);

    await tester.tap(find.text('güncel'));
    await bekle(tester);
    await tester.tap(find.text(Metin.notuSil));
    await bekle(tester);
    final kayit = (await tester.runAsync(() => db.getMood(gun)))!;
    expect(kayit.note, isNull);
    expect(kayit.mood, 4);
    expect(find.text(Metin.notYok), findsOneWidget);
    await temizle(tester);
  });

  testWidgets('Ortalama satırı: 4 ve 2 → 3,0', (tester) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await db.setMood(_gun(0), 4);
    await db.setMood(_gun(1), 2);
    await uygulamaAc(tester, db);
    expect(find.text('Son 30 gün ortalaması: 3,0 / 5 (2 kayıt)'), findsOneWidget);
    await temizle(tester);
  });

  testWidgets('Ortalama satırı kayıt yokken görünmez', (tester) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await uygulamaAc(tester, db);
    expect(find.textContaining('Son 30 gün ortalaması'), findsNothing);
    await temizle(tester);
  });
}
