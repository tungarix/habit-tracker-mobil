import 'dart:convert';

import 'package:aktenak_habit_tracker/core/constants.dart';
import 'package:aktenak_habit_tracker/core/enums.dart';
import 'package:aktenak_habit_tracker/data/database/database.dart';
import 'package:aktenak_habit_tracker/data/repositories/backup_repository.dart';
import 'package:aktenak_habit_tracker/platform/yedek_denetimi.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A bad day string would be stored and then crash the statistics / task screens on every open; a
/// far-future stamp would win every later last-writer-wins comparison.

Map<String, dynamic> _temiz() => {
  'format': AppConstants.backupFormat,
  'version': AppConstants.backupVersion,
  'habits': [
    {
      'id': 1,
      'name': 'Spor',
      'colorValue': 0xFF4CAF50,
      'iconCodePoint': 0xe000,
      'category': 'beden',
      'kind': 'bool',
      'target': 1,
      'sortOrder': 0,
      'scheduledWeekdays': '',
      'updatedAt': '2026-03-01T10:00:00.000Z',
    },
  ],
  'entries': [
    {'habitId': 1, 'date': '2026-03-01', 'status': 'done', 'value': 1},
  ],
  'moods': [
    {'date': '2026-03-01', 'mood': 3, 'note': null},
  ],
  'tasks': [
    {'id': 1, 'title': 'Görev', 'status': 'todo', 'priority': 1, 'dueDay': '2026-03-05'},
  ],
  'sessions': [
    {'kind': 'focus', 'day': '2026-03-01', 'durationS': 1500},
  ],
  'deleted': [
    {'kind': 'habit', 'key': 'u1', 'deletedAt': '2026-03-01T10:00:00Z'},
  ],
};

final _simdi = DateTime.utc(2026, 3, 2, 12);

void main() {
  void kabul(Map<String, dynamic> k) => yedekAlanlariniDenetle(jsonEncode(k), now: _simdi);

  void red(void Function(Map<String, dynamic> k) degistir, String parca) {
    final k = _temiz();
    degistir(k);
    expect(
      () => kabul(k),
      throwsA(isA<FormatException>().having((e) => e.message, 'message', contains(parca))),
    );
  }

  Map m(Map<String, dynamic> k, String ad) => (k[ad] as List).first as Map;

  test('temiz yedek ve eksik alanlı eski biçim geçer', () {
    kabul(_temiz());
    kabul({'format': AppConstants.backupFormat, 'version': 1, 'habits': [{'id': 1, 'name': 'x'}]});
  });

  test('yapısal olarak bozuk dosya içe aktarıcıya bırakılır (burada atmaz)', () {
    yedekAlanlariniDenetle('{', now: _simdi);
    yedekAlanlariniDenetle('[1,2]', now: _simdi);
    yedekAlanlariniDenetle('[' * 5000, now: _simdi);
  });

  test('geçersiz gün metni reddedilir', () {
    red((k) => m(k, 'entries')['date'] = 'bozuk', '"date"');
    red((k) => m(k, 'entries')['date'] = '2026-02-31', '"date"');
    red((k) => m(k, 'moods')['date'] = 'x' * 50, '"date"');
    red((k) => m(k, 'tasks')['dueDay'] = '12.11', '"dueDay"');
    red((k) => m(k, 'sessions')['day'] = 'dün', '"day"');
  });

  test('sınır dışı değer ve küme dışı metin reddedilir', () {
    red((k) => m(k, 'habits')['target'] = 0, '"target"');
    red((k) => m(k, 'habits')['colorValue'] = -1, '"colorValue"');
    red((k) => m(k, 'habits')['kind'] = 'x', '"kind"');
    red((k) => m(k, 'habits')['scheduledWeekdays'] = '8', '"scheduledWeekdays"');
    red((k) => m(k, 'habits')['category'] = 'k' * 41, '"category"');
    red((k) => m(k, 'entries')['value'] = -1, '"value"');
    red((k) => m(k, 'entries')['status'] = 'x', '"status"');
    red((k) => m(k, 'tasks')['status'] = 'x', '"status"');
    red((k) => m(k, 'tasks')['priority'] = 9, '"priority"');
    red((k) => m(k, 'sessions')['durationS'] = 8 * 86400, '"durationS"');
    red((k) => m(k, 'deleted')['key'] = 'k' * 201, 'silinen kayıt izi');
    red((k) => m(k, 'deleted')['kind'] = 'x', 'silinen kayıt izi');
  });

  test('gelecek damgası reddedilir, yarın kabul edilir', () {
    red((k) => m(k, 'habits')['updatedAt'] = '9999-12-31T00:00:00Z', 'gelecekte');
    red((k) => m(k, 'deleted')['deletedAt'] = '9999-12-31T00:00:00Z', 'gelecekte');
    red((k) => m(k, 'habits')['updatedAt'] = 'dün', '"updatedAt"');
    final k = _temiz();
    m(k, 'habits')['updatedAt'] = '2026-03-03T11:00:00Z';
    kabul(k);
  });

  test('uygulamanın kendi dışa aktardığı yedek geçer', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final id = await db.insertHabit(
      HabitsCompanion.insert(name: 'Spor', colorValue: 0xFF4CAF50, iconCodePoint: 0xe000),
    );
    await db.setEntryStatus(id, '2026-03-01', EntryStatus.done);
    await db.setMood('2026-03-01', 4, note: 'iyi');
    yedekAlanlariniDenetle(await BackupRepository(db).exportJson());
  });
}
