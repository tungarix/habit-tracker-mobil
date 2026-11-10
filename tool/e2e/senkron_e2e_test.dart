// Masaüstü <-> mobil .habitsync uçtan uca denetimi.
//
// Çalıştır: `powershell -File tool/e2e/calistir.ps1` (ya da `flutter test tool/e2e/senkron_e2e_test.dart`).
//
// Masaüstünün senkron kodu ve mobilin senkron kodu AYNI dosyalardır (tool/esitle.ps1 kopyalar,
// test/uyum_test.dart özetle denetler); bu yüzden "iki cihaz" aynı kodu çalıştıran iki GEÇİCİ
// SQLite dosyasıdır. Birim testlerinden (test/sync_test.dart, bellek içi) farkı: gerçek dosya
// veritabanları, gerçek .habitsync dosyası (diske yazılır, bayt olarak geri okunur), gerçek v4 -> v5
// yükseltmesi (cihaz dosyası kapatılıp yeniden açılır) ve v4 JSON yedeği.
// Gerçek kullanıcı verisine dokunulmaz.
import 'dart:convert';
import 'dart:io';

import 'package:aktenak_habit_tracker/core/constants.dart';
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/repositories/backup_repository.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_export.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_format.dart';
import 'package:aktenak_habit_tracker/data/sync/sync_import.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

const t0 = 1780000000; // fixed point in 2026
int at(int n) => t0 + n;
DateTime when(int n) => DateTime.fromMillisecondsSinceEpoch(at(n) * 1000);

late Directory tmp;

/// One device = one temporary SQLite file.
class Cihaz {
  Cihaz(this.ad, this.dosya)
    : db = AppDatabase.forTesting(NativeDatabase(dosya));
  final String ad;
  final File dosya;
  AppDatabase db;

  static Cihaz yeni(String ad) => Cihaz(ad, File('${tmp.path}/$ad.sqlite'));

  /// Closes and reopens the file (runs any pending migration).
  Future<void> yenidenAc() async {
    await db.close();
    db = AppDatabase.forTesting(NativeDatabase(dosya));
  }

  Future<void> sql(String s, [List<Object?> a = const []]) =>
      db.customStatement(s, a);

  Future<int> habit(
    String ad, {
    int stamp = 0,
    int created = 0,
    String kind = 'bool',
    int target = 1,
  }) => db.insertHabit(
    HabitsCompanion.insert(
      name: ad,
      colorValue: 0xFF4CAF50,
      iconCodePoint: 0xe000,
      kind: Value(kind),
      target: Value(target),
      createdAt: Value(when(created)),
      updatedAt: Value(at(stamp)),
    ),
  );

  Future<int> idOf(String ad) async =>
      (await db.getAllHabits()).firstWhere((h) => h.name == ad).id;
  Future<String> uidOf(String ad) async =>
      (await db.getAllHabits()).firstWhere((h) => h.name == ad).uid!;

  Future<void> rename(String ad, int stamp, String yeni) => sql(
    'UPDATE habits SET name = ?, updated_at = ? WHERE name = ?',
    [yeni, at(stamp), ad],
  );

  Future<void> cell(
    String ad,
    String date,
    EntryStatus s,
    int stamp, {
    int? amount,
  }) async {
    final id = await idOf(ad);
    await db.setEntryStatus(id, date, s, amount: amount);
    await sql(
      'UPDATE habit_entries SET updated_at = ? WHERE habit_id = ? AND date = ?',
      [at(stamp), id, date],
    );
  }

  Future<void> clearCell(String ad, String date, int stamp) async {
    final uid = await uidOf(ad);
    await db.setEntryStatus(await idOf(ad), date, null);
    await sql(
      "UPDATE silinenler SET deleted_at = ? WHERE kind = 'entry' AND anahtar = ?",
      [at(stamp), '$uid|$date'],
    );
  }

  Future<void> mood(String date, int v, int stamp) async {
    await db.setMood(date, v);
    await sql('UPDATE mood_entries SET updated_at = ? WHERE date = ?', [
      at(stamp),
      date,
    ]);
  }

  Future<int> task(String baslik, {int stamp = 0, int created = 0}) =>
      db.insertTask(
        TasksCompanion.insert(
          title: baslik,
          createdAt: Value(when(created)),
          updatedAt: Value(at(stamp)),
        ),
      );

  Future<void> editTask(String baslik, int stamp, {required String status}) =>
      sql('UPDATE tasks SET status = ?, updated_at = ? WHERE title = ?', [
        status,
        at(stamp),
        baslik,
      ]);

  Future<void> deleteTask(String baslik, int stamp) async {
    final t = (await db.getAllTasks()).firstWhere((t) => t.title == baslik);
    await db.deleteTask(t.id);
    await sql(
      "UPDATE silinenler SET deleted_at = ? WHERE kind = 'task' AND anahtar = ?",
      [at(stamp), t.uid],
    );
  }

  Future<int> session(
    int after,
    int secs, {
    String? taskTitle,
    int stamp = 0,
    String kind = 'focus',
  }) async {
    int? taskId;
    if (taskTitle != null) {
      taskId = (await db.getAllTasks())
          .firstWhere((t) => t.title == taskTitle)
          .id;
    }
    return db
        .into(db.focusSessions)
        .insert(
          FocusSessionsCompanion.insert(
            kind: Value(kind),
            startedAt: when(after),
            endedAt: Value(when(after + secs)),
            durationS: Value(secs),
            day: '2026-05-01',
            taskId: Value(taskId),
            updatedAt: Value(at(stamp)),
          ),
        );
  }

  Future<void> setDayStart(int hour, int stamp) async {
    await db.setSetting(AppConstants.dayStartHourKey, '$hour');
    await db.setSetting(AppConstants.dayStartHourStampKey, '${at(stamp)}');
  }

  Future<int?> dayStart() async =>
      int.tryParse(await db.getSetting(AppConstants.dayStartHourKey) ?? '');

  Future<int> count(String table) async =>
      (await db.customSelect('SELECT COUNT(*) AS n FROM $table').getSingle())
          .read<int>('n');

  /// Everything that syncs, normalised so two devices can be compared.
  Future<String> durum() async {
    final doc = jsonDecode(await exportSync(db)) as Map<String, dynamic>
      ..remove('created_at')
      ..remove('device');
    String key(Map m) =>
        jsonEncode([m['uid'], m['habit_uid'], m['date'], m['kind'], m['key']]);
    // A restore (replace) re-creates cells with created_at = now; ties keep the older local row, so this
    // metadata may differ by a second or more between devices. It is not part of a cell's identity or value.
    for (final k in ['entries', 'moods']) {
      for (final r in doc[k] as List) {
        (r as Map).remove('created_at');
      }
    }
    for (final k in [
      'habits',
      'entries',
      'moods',
      'tasks',
      'sessions',
      'deleted',
    ]) {
      (doc[k] as List).sort((a, b) => key(a as Map).compareTo(key(b as Map)));
    }
    return jsonEncode(doc);
  }

  Future<void> kapat() => db.close();
}

int _n = 0;

/// [from]'s state goes to [to] through a real .habitsync file on disk, like a user would.
Future<SyncReport> sync(Cihaz from, Cihaz to) async {
  final f = File('${tmp.path}/${from.ad}-${to.ad}-${_n++}.$syncExtension');
  await f.writeAsBytes(
    utf8.encode(await exportSync(from.db, deviceName: from.ad)),
    flush: true,
  );
  return importSyncBytes(to.db, await f.readAsBytes());
}

Future<void> settle(Cihaz a, Cihaz b) async {
  for (var i = 0; i < 4; i++) {
    final r1 = await sync(a, b);
    final r2 = await sync(b, a);
    if (!r1.changed && !r2.changed) return;
  }
  throw StateError('sync did not settle in 4 rounds');
}

Future<void> seed(Cihaz c) async {
  await c.habit('Kitap', stamp: 10, created: 1);
  await c.habit('Adım', stamp: 10, created: 2, kind: 'count', target: 10000);
  await c.cell('Kitap', '2026-05-01', EntryStatus.done, 20);
  await c.cell('Kitap', '2026-05-02', EntryStatus.missed, 20);
  await c.cell('Adım', '2026-05-01', EntryStatus.done, 20, amount: 12000);
  await c.mood('2026-05-01', 4, 20);
  await c.task('Rapor', stamp: 10, created: 3);
  await c.session(100, 1500, taskTitle: 'Rapor', stamp: 30);
  await c.session(3000, 300, kind: 'break', stamp: 30);
}

/// Rewinds [c]'s file to the v4 shape (everything v5 added is dropped), as an installed v1.3.x / v0.0.x
/// database looks. The caller reopens it to run the real upgrade.
Future<void> v4eDondur(Cihaz c) async {
  await c.db.close();
  final w = AppDatabase.forTesting(NativeDatabase(c.dosya));
  final trig = await w
      .customSelect("SELECT name FROM sqlite_master WHERE type='trigger'")
      .get();
  for (final r in trig) {
    await w.customStatement('DROP TRIGGER ${r.read<String>('name')}');
  }
  for (final t in ['habits', 'tasks', 'focus_sessions']) {
    await w.customStatement('DROP INDEX ${t}_uid_idx');
    await w.customStatement('ALTER TABLE $t DROP COLUMN uid');
  }
  for (final t in [
    'habits',
    'habit_entries',
    'mood_entries',
    'tasks',
    'focus_sessions',
  ]) {
    await w.customStatement('ALTER TABLE $t DROP COLUMN updated_at');
  }
  await w.customStatement('DROP TABLE silinenler');
  await w.customStatement(
    "DELETE FROM settings WHERE key = '${AppConstants.dayStartHourStampKey}'",
  );
  await w.customStatement('PRAGMA user_version = 4');
  await w.close();
  c.db = AppDatabase.forTesting(NativeDatabase(c.dosya));
}

const _tablolar = [
  'habits',
  'habit_entries',
  'mood_entries',
  'tasks',
  'focus_sessions',
];

void main() {
  driftRuntimeOptions.dontWarnAboutMultipleDatabases = true;

  late Cihaz d; // desktop
  late Cihaz m; // mobile
  setUp(() {
    tmp = Directory.systemTemp.createTempSync('habit_e2e');
    d = Cihaz.yeni('masaustu');
    m = Cihaz.yeni('telefon');
  });
  tearDown(() async {
    await d.kapat();
    await m.kapat();
    tmp.deleteSync(recursive: true);
  });

  Future<void> esit() async => expect(await m.durum(), await d.durum());

  group('ilk eşleştirme: v4 veri iki tarafta ayrı ayrı v5\'e çıktı', () {
    /// A v4-style JSON backup (no uids, no stamps) of [src], as the old desktop app wrote it.
    Future<String> v4Yedek(Cihaz src) async {
      final json = jsonDecode(
        await BackupRepository(src.db).exportJson(),
      ) as Map<String, dynamic>;
      json['version'] = 4;
      json.remove('deleted');
      for (final k in ['habits', 'entries', 'moods', 'tasks', 'sessions']) {
        for (final r in json[k] as List) {
          for (final f in ['uid', 'updatedAt', 'habitUid', 'taskUid']) {
            (r as Map).remove(f);
          }
        }
      }
      return jsonEncode(json);
    }

    Future<Map<String, int>> sayilar(Cihaz c) async => {
      for (final t in _tablolar) t: await c.count(t),
    };

    test('iki gerçek v4 dosyası ayrı ayrı yükselir; ilk senkron hiçbir kaydı ikilemez', () async {
      for (final c in [d, m]) {
        await seed(c);
        await v4eDondur(c);
        await c.yenidenAc();
      }
      expect(
        await d.uidOf('Kitap'),
        isNot(await m.uidOf('Kitap')),
        reason: 'uids are random per device',
      );
      final once = await sayilar(d);
      expect(await sayilar(m), once);

      final r = await sync(d, m);
      expect(r.added, 0);
      expect(r.adopted, 5); // 2 habits + 1 task + 2 sessions
      await settle(d, m);
      await esit();
      expect(await sayilar(d), once);
      expect(await sayilar(m), once);
      expect(
        (await m.db.getAllSessions()).where((s) => s.taskId != null),
        hasLength(1),
      );
    });

    test(
      'masaüstü v4 dosyası; telefon masaüstünün v4 JSON yedeğini içe aktarmış',
      () async {
        await seed(d);
        await v4eDondur(d);
        await d.yenidenAc(); // desktop upgrades on its own
        final yedek = await v4Yedek(d);
        await BackupRepository(m.db)
            .importJson(yedek, replace: true); // phone: own random uids
        expect(await d.uidOf('Kitap'), isNot(await m.uidOf('Kitap')));
        final once = await sayilar(d);

        await settle(d, m);
        await esit();
        expect(await sayilar(d), once);
        expect(await sayilar(m), once);

        // After pairing the real edits flow normally.
        await m.cell('Kitap', '2026-05-03', EntryStatus.done, 300);
        await sync(m, d);
        expect(await d.count('habit_entries'), once['habit_entries']! + 1);
        await esit();
      },
    );
  });

  test('a: iki yönlü, telefonda düzenle/sil/ekle, geri getir', () async {
    await seed(d);
    await sync(d, m);
    await esit();
    await m.rename('Kitap', 200, 'Kitap okuma');
    await m.cell('Kitap okuma', '2026-05-02', EntryStatus.done, 210);
    await m.clearCell('Adım', '2026-05-01', 220);
    await m.deleteTask('Rapor', 230);
    await m.habit('Yürüyüş', stamp: 240, created: 240);
    await m.session(9000, 600, stamp: 260);
    final r = await sync(m, d);
    expect(r.habit.added, 1);
    expect(r.habit.updated, 1);
    expect(r.task.deleted, 1);
    await esit();
    expect(await d.count('tasks'), 0);
    expect(await d.count('focus_sessions'), 3);
  });

  for (final telefonSonra in [true, false]) {
    test(
      'b: düzenle/düzenle, ${telefonSonra ? 'telefon' : 'masaüstü'} sonra: son yazan kazanır',
      () async {
        await seed(d);
        await sync(d, m);
        await d.rename('Kitap', telefonSonra ? 100 : 200, 'Kitap D');
        await m.rename('Kitap', telefonSonra ? 200 : 100, 'Kitap M');
        await settle(d, m);
        await esit();
        expect(
          (await d.db.getAllHabits()).map((h) => h.name),
          contains(telefonSonra ? 'Kitap M' : 'Kitap D'),
        );
        expect(await d.count('habits'), 2);
      },
    );
  }

  for (final silmeYeni in [true, false]) {
    test('c: sil/düzenle, silme ${silmeYeni ? 'yeni' : 'eski'}', () async {
      await seed(d);
      await sync(d, m);
      await m.deleteTask('Rapor', silmeYeni ? 300 : 100);
      await d.editTask('Rapor', silmeYeni ? 100 : 300, status: 'done');
      await settle(d, m);
      await esit();
      expect(await d.count('tasks'), silmeYeni ? 0 : 1);
    });
  }

  test('c: eşit damgada kayıt silinmez', () async {
    await seed(d);
    await sync(d, m);
    await d.deleteTask('Rapor', 500);
    await m.editTask('Rapor', 500, status: 'doing');
    await settle(d, m);
    await esit();
    expect(await d.count('tasks'), 1);
  });

  test('d: idempotans, ping-pong, silme yankısı', () async {
    await seed(d);
    await sync(d, m);
    expect(
      (await sync(d, m)).changed,
      isFalse,
      reason: 'same file twice changes nothing',
    );
    expect((await sync(m, d)).changed, isFalse);
    await m.deleteTask('Rapor', 300);
    await settle(d, m);
    // The delete trace must not bounce forever: a further round changes nothing.
    expect((await sync(d, m)).changed, isFalse);
    expect((await sync(m, d)).changed, isFalse);
    await esit();
  });

  test('e: unicode ve uzun metin dosyadan sağ çıkar', () async {
    final ad = 'Kitap 📚 ışık çğüöşİ ${'x' * 60}';
    await d.habit(ad, stamp: 10, created: 1);
    await d.task('Görev ${'ö' * 150}', stamp: 10, created: 2);
    await sync(d, m);
    expect((await m.db.getAllHabits()).single.name, ad);
    await esit();
  });

  test('f: üçüncü cihaz', () async {
    final y = Cihaz.yeni('yedek-pc');
    addTearDown(y.kapat);
    await seed(d);
    await sync(d, m);
    await sync(m, y);
    await y.cell('Kitap', '2026-05-09', EntryStatus.done, 400);
    await sync(y, d);
    await settle(d, m);
    await settle(d, y);
    await settle(d, m);
    expect(await y.durum(), await d.durum());
    await esit();
  });

  test('ek 2: boşa çekilen ✓ öbür tarafta geri gelmez', () async {
    await seed(d);
    await sync(d, m);
    await m.clearCell('Kitap', '2026-05-01', 300);
    await sync(d, m); // an older file arrives after the clear
    await settle(d, m);
    await esit();
    expect(
      (await d.db.getAllEntries()).where((e) => e.date == '2026-05-01'),
      hasLength(1),
    ); // only Adım's
  });

  test('ek 3: yedekten geri dönüşten sonra senkron', () async {
    await seed(d);
    await sync(d, m);
    final yedek = await BackupRepository(d.db).exportJson();
    await d.cell('Kitap', '2026-05-04', EntryStatus.done, 400);
    await sync(d, m);
    await BackupRepository(d.db)
        .importJson(yedek, replace: true); // back to the earlier state
    await settle(d, m);
    await esit();
    expect(await d.count('habits'), 2);
  });

  test('ek 4: farklı gün başlangıcı, son değiştiren kazanır', () async {
    await seed(d);
    await d.setDayStart(4, 10);
    await m.setDayStart(2, 20);
    await settle(d, m);
    expect(await d.dayStart(), 2);
    expect(await m.dayStart(), 2);
    await d.setDayStart(6, 30);
    await settle(d, m);
    expect(await m.dayStart(), 6);
    await esit();
  });

  test('ölçek: 20 alışkanlık x 3 yıl, 2000 görev, 5000 seans', () async {
    const habits = 20, days = 1095, tasks = 2000, sessions = 5000;
    final ids = [
      for (var i = 0; i < habits; i++)
        await d.habit('Alışkanlık $i', stamp: 10, created: i),
    ];
    await d.db.batch((b) {
      for (final id in ids) {
        for (var k = 0; k < days; k++) {
          final x = DateTime.utc(2024, 1, 1).add(Duration(days: k));
          b.insert(
            d.db.habitEntries,
            HabitEntriesCompanion.insert(
              habitId: id,
              date:
                  '${x.year}-${x.month.toString().padLeft(2, '0')}-${x.day.toString().padLeft(2, '0')}',
              status: EntryStatus.values[k % 3],
              updatedAt: Value(at(20 + k)),
            ),
          );
        }
      }
      for (var i = 0; i < tasks; i++) {
        b.insert(
          d.db.tasks,
          TasksCompanion.insert(
            title: 'Görev $i',
            updatedAt: Value(at(30)),
            createdAt: Value(when(i)),
          ),
        );
      }
      for (var i = 0; i < sessions; i++) {
        b.insert(
          d.db.focusSessions,
          FocusSessionsCompanion.insert(
            startedAt: when(i * 4000),
            durationS: const Value(1500),
            day: '2026-05-01',
            updatedAt: Value(at(40)),
          ),
        );
      }
    });
    final sw = Stopwatch()..start();
    final dosya = File('${tmp.path}/olcek.habitsync');
    await dosya.writeAsString(await exportSync(d.db));
    final exportMs = sw.elapsedMilliseconds;
    sw
      ..reset()
      ..start();
    final r = await importSyncBytes(m.db, await dosya.readAsBytes());
    final importMs = sw.elapsedMilliseconds;
    sw
      ..reset()
      ..start();
    final r2 = await importSyncBytes(m.db, await dosya.readAsBytes());
    final tekrarMs = sw.elapsedMilliseconds;
    // ignore: avoid_print
    print(
      'olcek: dosya ${(dosya.lengthSync() / 1024 / 1024).toStringAsFixed(1)} MB; '
      'disa aktarma ${exportMs}ms, ice aktarma (bos cihaz) ${importMs}ms, ikinci ice aktarma ${tekrarMs}ms',
    );
    expect(r.entry.added, habits * days);
    expect(r.task.added, tasks);
    expect(r.session.added, sessions);
    expect(r2.changed, isFalse);
    expect(importMs, lessThan(60000));
    await esit();
  }, timeout: const Timeout(Duration(minutes: 5)));
}
