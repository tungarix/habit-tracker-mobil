import 'dart:convert';
import 'dart:typed_data';

import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/providers.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_export.dart';
import 'package:aktenak_habit_tracker/features/settings/senkron_dosya_servisi.dart';
import 'package:aktenak_habit_tracker/features/settings/settings_screen.dart';
import 'package:aktenak_habit_tracker/platform/kopru.dart';
import 'package:aktenak_habit_tracker/ui_metin.dart';
import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

class SahteSenkronServisi implements SenkronDosyaServisi {
  Uint8List? secilecek;
  String? paylasilan;
  String? paylasilanAd;

  @override
  Future<Uint8List?> sec() async => secilecek;

  @override
  Future<void> paylas(String text, String ad) async {
    paylasilan = text;
    paylasilanAd = ad;
  }
}

/// Stands in for MainActivity: hands over a pending file at start-up and can push another later.
class SahteKopru implements Kopru {
  SahteKopru(this.bekleyen);
  GelenDosya? bekleyen;
  void Function(GelenDosya)? dinleyici;

  @override
  Future<GelenDosya?> bekleyenDosya() async {
    final b = bekleyen;
    bekleyen = null;
    return b;
  }

  @override
  void dosyaDinle(void Function(GelenDosya) f) => dinleyici = f;

  @override
  dynamic noSuchMethod(Invocation i) =>
      throw UnimplementedError('${i.memberName}');
}

Future<Uint8List> ornekDosya(String ad) async {
  final kaynak = await bellekDb();
  await aliskanlikEkle(kaynak, ad);
  return Uint8List.fromList(utf8.encode(await exportSync(kaynak)));
}

void main() {
  test('onay metni silinecek kayıt sayısını söyler', () {
    expect(Metin.senkronOnayIcerik(1, 2, 3, 4, 7), contains('7 kayıt var'));
    expect(Metin.senkronOnayIcerik(1, 2, 3, 4, 0), contains('işaretli kayıt yok'));
  });

  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;
  Future<void> ayarlariAc(
    WidgetTester tester,
    AppDatabase db,
    SahteSenkronServisi servis,
  ) async {
    telefonBoyutu(tester, yukseklik: 1800);
    await tester.pumpWidget(
      ProviderScope(
        // ignore: argument_type_not_assignable
        overrides: [
          databaseProvider.overrideWithValue(db),
          senkronDosyaServisiProvider.overrideWithValue(servis),
        ],
        child: const MaterialApp(home: SettingsScreen()),
      ),
    );
    await bekle(tester);
  }

  testWidgets('dışa aktarma .habitsync dosyasını paylaşır', (tester) async {
    final db = await bellekDb();
    await aliskanlikEkle(db, 'Kitap');
    final servis = SahteSenkronServisi();
    await ayarlariAc(tester, db, servis);

    expect(find.text(Metin.senkronBaslik), findsOneWidget);
    await tester.tap(find.text(Metin.senkronDisaAktar));
    await bekle(tester);

    expect(servis.paylasilanAd, endsWith('.habitsync'));
    final doc = jsonDecode(servis.paylasilan!) as Map<String, dynamic>;
    expect(doc['format'], 'habit-sync');
    expect((doc['habits'] as List).single['name'], 'Kitap');
    await temizle(tester);
  });

  testWidgets('içe aktarma önce onay ister; iptal hiçbir şey değiştirmez', (
    tester,
  ) async {
    final db = await bellekDb();
    final servis = SahteSenkronServisi()..secilecek = await ornekDosya('Gelen');
    await ayarlariAc(tester, db, servis);

    await tester.tap(find.text(Metin.senkronIceAktar));
    await bekle(tester);
    expect(find.text(Metin.senkronOnayBaslik), findsOneWidget);
    expect(find.textContaining('1 alışkanlık'), findsOneWidget);
    expect(find.textContaining('silinmiş olarak işaretli kayıt yok'), findsOneWidget);

    await tester.tap(find.text(Metin.iptal));
    await bekle(tester);
    expect(await db.getAllHabits(), isEmpty);

    await tester.tap(find.text(Metin.senkronIceAktar));
    await bekle(tester);
    await tester.tap(
      find.widgetWithText(FilledButton, Metin.senkronIceAktarDugme),
    );
    await bekle(tester);
    expect((await db.getAllHabits()).single.name, 'Gelen');
    await temizle(tester);
  });

  testWidgets('bozuk dosya onay ekranı açmadan reddedilir', (tester) async {
    final db = await bellekDb();
    final servis = SahteSenkronServisi()
      ..secilecek = Uint8List.fromList(utf8.encode('{"format":"baska"}'));
    await ayarlariAc(tester, db, servis);

    await tester.tap(find.text(Metin.senkronIceAktar));
    await bekle(tester);
    expect(find.text(Metin.senkronOnayBaslik), findsNothing);
    expect(find.textContaining('Hiçbir şey değişmedi'), findsOneWidget);
    expect(await db.getAllHabits(), isEmpty);
    await temizle(tester);
  });

  testWidgets(
    'dışarıdan açılan dosya (soğuk başlangıç ve çalışırken) onay ekranına gider',
    (tester) async {
      final db = await bellekDb();
      final kopru = SahteKopru(GelenDosya.bayt(await ornekDosya('Soğuk')));
      await uygulamaAc(
        tester,
        db,
        overrides: [kopruProvider.overrideWithValue(kopru)],
      );

      expect(find.text(Metin.senkronOnayBaslik), findsOneWidget);
      await tester.tap(
        find.widgetWithText(FilledButton, Metin.senkronIceAktarDugme),
      );
      await bekle(tester);
      expect((await db.getAllHabits()).map((h) => h.name), ['Soğuk']);

      // While running: an unreadable file shows the error, nothing is asked.
      kopru.dinleyici!(const GelenDosya.hata('dosya çok büyük (en çok 16 MB)'));
      await bekle(tester);
      expect(find.text(Metin.senkronOnayBaslik), findsNothing);
      expect(find.textContaining('dosya çok büyük'), findsOneWidget);

      kopru.dinleyici!(GelenDosya.bayt(await ornekDosya('Sıcak')));
      await bekle(tester);
      expect(find.text(Metin.senkronOnayBaslik), findsOneWidget);
      await tester.tap(find.text(Metin.iptal));
      await bekle(tester);
      expect(await db.getAllHabits(), hasLength(1));
      await temizle(tester);
    },
  );
}
