// Kuru çalıştırma: gerçek birleştirmeyi (importSyncBytes) bir transaction içinde çalıştırıp raporu alır,
// sonra özel bir istisnayla transaction'ı GERİ SARAR. Sayılar bu yüzden gerçek birleştirmeyle aynı koddan
// çıkar; veri ve `silinenler` izleri değişmez. (Tasarımdaki `previewSyncBytes`'ın mobil karşılığı: paylaşılan
// sync_import.dart kopya olduğu için dokunulmaz.)
import 'dart:typed_data';

import '../../data/database/database.dart';
import '../../data/sync/sync_format.dart';
import '../../data/sync/sync_import.dart';

class _GeriSar implements Exception {
  _GeriSar(this.rapor);
  final SyncReport rapor;
}

Future<SyncReport> senkronOnizle(AppDatabase db, Uint8List bayt) async {
  try {
    await db.transaction(() async {
      throw _GeriSar(await importSyncBytes(db, bayt));
    });
  } on _GeriSar catch (g) {
    return g.rapor;
  }
}
