import 'package:aktenak_habit_tracker/core/date_utils.dart';
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/shared/theme.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  testWidgets('Bugün: dokunuş ✓ → ✗ → – → boş döner, etiket durumu söyler', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final handle = tester.ensureSemantics();
    final db = await bellekDb();
    await aliskanlikEkle(db, 'Kitap');
    await uygulamaAc(tester, db);

    Finder satir(String durum) =>
        find.bySemanticsLabel(RegExp(r'^Kitap, \d+ \S+: ' + durum));

    expect(satir('işaretlenmedi'), findsOneWidget);
    for (final sonraki in ['yapıldı', 'yapılmadı', 'atlandı', 'işaretlenmedi']) {
      await tester.tap(find.text('Kitap'));
      await bekle(tester);
      expect(satir(sonraki), findsOneWidget, reason: sonraki);
    }

    handle.dispose();
    await temizle(tester);
  });

  testWidgets('Bugün: hedefin altındaki kısmi miktar "devam ediyor" okunur', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final handle = tester.ensureSemantics();
    final db = await bellekDb();
    await aliskanlikEkle(db, 'Su', kind: 'count', target: 8);
    await uygulamaAc(tester, db);

    await tester.longPress(find.text('Su'));
    await bekle(tester);
    await tester.enterText(find.byType(TextField), '3');
    await tester.tap(find.text(Metin.kaydet));
    await bekle(tester);

    expect(
      find.bySemanticsLabel(RegExp(r'^Su, \d+ \S+: devam ediyor, 3 / 8')),
      findsOneWidget,
    );

    handle.dispose();
    await temizle(tester);
  });

  testWidgets('Bugün: sayılabilir alışkanlıkta uzun basış miktar sorar', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    await aliskanlikEkle(db, 'Su', kind: 'count', target: 8);
    await uygulamaAc(tester, db);

    await tester.longPress(find.text('Su'));
    await bekle(tester);
    expect(find.text(Metin.bugunkuMiktar), findsOneWidget);

    await tester.enterText(find.byType(TextField), '8');
    await tester.tap(find.text(Metin.kaydet));
    await bekle(tester);

    expect(find.text('8 / 8'), findsOneWidget);
    final bugun = formatYmd(ProviderScope.containerOf(
      tester.element(find.byType(Scaffold).first),
    ).read(todayProvider));
    final giris = await tester.runAsync(
      () => db.getEntry(1, bugun),
    );
    expect(giris!.status, EntryStatus.done);
    expect(giris.value, 8);

    await temizle(tester);
  });

  testWidgets('Bugün: ısı şeridi kartın içinde açılıp kapanır', (tester) async {
    telefonBoyutu(tester);
    final handle = tester.ensureSemantics();
    final db = await bellekDb();
    await aliskanlikEkle(db, 'Kitap');
    await uygulamaAc(tester, db);

    final ac = find.byTooltip(Metin.isiSeridiAc);
    expect(ac, findsOneWidget);
    await tester.ensureVisible(ac);
    await tester.tap(ac);
    await bekle(tester);
    expect(find.byTooltip(Metin.isiSeridiKapat), findsOneWidget);
    // 30 labelled cells.
    expect(
      find.bySemanticsLabel(RegExp(r'^Kitap, \d+ \S+: ')),
      findsNWidgets(31), // 30 cells + the row itself
    );
    await tester.tap(find.byTooltip(Metin.isiSeridiKapat));
    await bekle(tester);
    expect(find.byTooltip(Metin.isiSeridiAc), findsOneWidget);
    handle.dispose();
    await temizle(tester);
  });

  testWidgets('Bugün: mood seçimi kaydedilir, tekrar dokunmak siler', (
    tester,
  ) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await uygulamaAc(tester, db);

    final mutlu = find.byIcon(Mood.mutlu.icon);
    await tester.ensureVisible(mutlu);
    await tester.tap(mutlu);
    await bekle(tester);
    expect((await tester.runAsync(() => db.watchAllMoods().first))!.single.mood, 5);

    await tester.tap(mutlu);
    await bekle(tester);
    expect(await tester.runAsync(() => db.watchAllMoods().first), isEmpty);
    await temizle(tester);
  });

  testWidgets('Bugün: notu olan ruh haline tekrar dokunmak onay ister', (tester) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await uygulamaAc(tester, db);

    final mutlu = find.byIcon(Mood.mutlu.icon);
    await tester.ensureVisible(mutlu);
    await tester.tap(mutlu);
    await bekle(tester);
    await tester.runAsync(() => db.setMoodNote(formatYmd(DateTime.now()), 'iyi gündü'));
    await bekle(tester);

    await tester.tap(mutlu);
    await bekle(tester);
    expect(find.text(Metin.moodSilBaslik), findsOneWidget);
    await tester.tap(find.text(Metin.iptal));
    await bekle(tester);
    expect((await tester.runAsync(() => db.watchAllMoods().first))!.single.note, 'iyi gündü');

    await tester.tap(mutlu);
    await bekle(tester);
    await tester.tap(find.descendant(of: find.byType(AlertDialog), matching: find.text(Metin.sil)));
    await bekle(tester);
    expect(await tester.runAsync(() => db.watchAllMoods().first), isEmpty);
    await temizle(tester);
  });

  testWidgets('Bugün: ruh hali notu kaydedilir, pencere kapanırken hata atmaz', (tester) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await uygulamaAc(tester, db);

    final mutlu = find.byIcon(Mood.mutlu.icon);
    await tester.ensureVisible(mutlu);
    await tester.tap(mutlu);
    await bekle(tester);
    await tester.tap(find.byTooltip(Metin.notTooltip));
    await bekle(tester, 3);
    await tester.enterText(find.descendant(of: find.byType(AlertDialog), matching: find.byType(TextField)), 'iyi gündü');
    await tester.tap(find.text(Metin.kaydet));
    await tester.pump(const Duration(milliseconds: 20));
    // DB yazımı bitip _editNote devam ederken kapanış animasyonu sürüyor: denetleyici hâlâ dinleniyor.
    await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
    await tester.pump(const Duration(milliseconds: 20));
    await bekle(tester);
    expect((await tester.runAsync(() => db.watchAllMoods().first))!.single.note, 'iyi gündü');
    expect(tester.takeException(), isNull);
    await temizle(tester);
  });

  testWidgets('Bugün: hızlı görev eklenir ve listede görünür', (tester) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    await uygulamaAc(tester, db);

    final alan = find.byType(TextField);
    await tester.ensureVisible(alan);
    await tester.enterText(alan, 'Fatura öde');
    await tester.tap(find.byTooltip(Metin.hizliEkleEtiket));
    await bekle(tester);
    expect(find.text('Fatura öde'), findsOneWidget);
    await temizle(tester);
  });
}
