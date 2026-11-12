import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/features/today/focus_controller.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:flutter/foundation.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/features/today/widgets/focus_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

/// Records start/stop calls so the card can be tested against the interface
/// alone (the real controller lives elsewhere).
class _SahteOdak implements FocusController {
  final _durum = ValueNotifier<FocusState>(FocusState.idle);
  final baslatilan = <int>[];
  var durdurma = 0;

  @override
  ValueListenable<FocusState> get state => _durum;
  @override
  Stream<FocusResult> get results => const Stream.empty();
  @override
  void start({
    required SessionKind kind,
    required int plannedMinutes,
    int? taskId,
  }) {
    baslatilan.add(plannedMinutes);
    _durum.value = FocusState(
      running: true,
      kind: kind,
      plannedMinutes: plannedMinutes,
      remainingSeconds: 1490,
    );
  }

  @override
  Future<void> stop() async {
    durdurma++;
    _durum.value = FocusState.idle;
  }

  @override
  void dispose() {}
}

void main() {
  testWidgets('MemoryFocusController: 1 dakikadan kısa seans yazılmaz, uzun yazılır', (
    tester,
  ) async {
    final kayit = <FocusRecord>[];
    final c = MemoryFocusController(onRecord: (r) async => kayit.add(r));
    final sonuclar = <FocusResult>[];
    c.results.listen(sonuclar.add);

    c.start(kind: SessionKind.focus, plannedMinutes: 25);
    await tester.pump(const Duration(seconds: 10));
    await c.stop();
    await tester.pump();
    expect(kayit, isEmpty);
    expect(sonuclar.single.saved, isFalse);
    expect(c.state.value.running, isFalse);

    c.start(kind: SessionKind.focus, plannedMinutes: 25);
    for (var i = 0; i < 90; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(c.state.value.remainingSeconds, 25 * 60 - 90);
    await c.stop();
    await tester.pump();
    expect(kayit.single.durationS, 90);
    expect(sonuclar.last.saved, isTrue);
    expect(sonuclar.last.completed, isFalse);

    // Runs to the end: rings by itself and is recorded as completed.
    c.start(kind: SessionKind.rest, plannedMinutes: 15);
    for (var i = 0; i < 15 * 60 + 1; i++) {
      await tester.pump(const Duration(seconds: 1));
    }
    expect(kayit.last.durationS, 15 * 60);
    expect(sonuclar.last.completed, isTrue);
    expect(c.state.value.running, isFalse);
    c.dispose();
  });

  testWidgets('Odak kartı yalnız FocusController arayüzüne bağlıdır', (
    tester,
  ) async {
    telefonBoyutu(tester, yukseklik: 2400);
    final db = await bellekDb();
    final sahte = _SahteOdak();
    await uygulamaAc(
      tester,
      db,
      overrides: [focusControllerProvider.overrideWithValue(sahte)],
    );

    final baslat = find.text(Metin.baslat(SessionKind.focus.label));
    await tester.ensureVisible(baslat);
    await tester.tap(find.text(Metin.dakika(45)));
    await bekle(tester, 2);
    await tester.tap(baslat);
    await bekle(tester, 2);
    expect(sahte.baslatilan, [45]);
    expect(find.text('24:50'), findsOneWidget);

    await tester.tap(find.text(Metin.bitir));
    await bekle(tester, 2);
    expect(sahte.durdurma, 1);
    expect(find.text(Metin.bitir), findsNothing);
    await temizle(tester);
  });

  testWidgets('Odak kartı: seçilen süre kart ekran dışına kayıp dönünce korunur', (
    tester,
  ) async {
    telefonBoyutu(tester);
    final db = await bellekDb();
    final sahte = _SahteOdak();
    // Bugün ekranındaki gibi ListView(children:): kart ekran dışında ağaçtan çıkabilir.
    await tester.pumpWidget(
      ProviderScope(
        // ignore: argument_type_not_assignable
        overrides: [databaseProvider.overrideWithValue(db), focusControllerProvider.overrideWithValue(sahte)],
        child: MaterialApp(
          home: Scaffold(
            body: ListView(children: const [FocusCard(), SizedBox(height: 4000)]),
          ),
        ),
      ),
    );
    await bekle(tester);

    await tester.tap(find.text(Metin.dakika(45)));
    await bekle(tester, 2);
    // Sıçrama (ink) animasyonu bitsin: sürerken InkWell kartı canlı tutar.
    await bekle(tester, 12);
    final liste = find.byType(Scrollable).first;
    await tester.drag(liste, const Offset(0, -3000));
    await bekle(tester, 2);
    await tester.drag(liste, const Offset(0, 3000));
    await bekle(tester, 2);
    await tester.tap(find.text(Metin.baslat(SessionKind.focus.label)));
    await bekle(tester, 2);
    expect(sahte.baslatilan, [45]);
    await temizle(tester);
  });
}
