import 'dart:convert';
import 'dart:typed_data';

import 'package:aktenak_habit_tracker/data/sync/sync_export.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_import.dart';
import 'package:aktenak_habit_tracker/platform/wifi/onizle.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_yardimci.dart';

void main() {
  test(
    'önizleme veriyi değiştirmez ve gerçek birleştirmeyle aynı rapor çıkar',
    () async {
      final kaynak = await bellekDb();
      await aliskanlikEkle(kaynak, 'Kitap');
      await aliskanlikEkle(kaynak, 'Su');
      final bayt = Uint8List.fromList(utf8.encode(await exportSync(kaynak)));

      final hedef = await bellekDb();
      await aliskanlikEkle(hedef, 'Spor');
      final once = await hedef.getAllHabits();

      final onizleme = await senkronOnizle(hedef, bayt);
      expect(onizleme.habit.added, 2);
      expect(await hedef.getAllHabits(), hasLength(once.length));

      // İkinci kez de aynı sayılar (hiçbir şey kalıcı değil).
      expect((await senkronOnizle(hedef, bayt)).added, onizleme.added);

      final gercek = await importSyncBytes(hedef, bayt);
      expect(
        (gercek.added, gercek.updated, gercek.deleted),
        (onizleme.added, onizleme.updated, onizleme.deleted),
      );
      expect(await hedef.getAllHabits(), hasLength(once.length + 2));

      // Artık her şey güncel: önizleme değişiklik göstermez.
      expect((await senkronOnizle(hedef, bayt)).changed, isFalse);
    },
  );
}
