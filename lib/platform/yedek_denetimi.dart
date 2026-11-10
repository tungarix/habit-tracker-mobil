// Field checks for a JSON backup before `BackupRepository.importJson` touches the database. Mobile-only:
// backup_repository.dart is a copy of the desktop file (uyum_test), so the same checks should be moved
// there when the desktop repo takes them. A hostile or damaged file must not leave rows that crash a screen
// on every open, nor stamps that win every last-writer-wins comparison from then on.
import 'dart:convert';

import '../data/sync/sync_format.dart';
import '../data/sync/sync_parse.dart' show jsonDepth;

/// Throws a readable [FormatException] for a bad field. Anything structurally off (not JSON, wrong
/// nesting) is left to `importJson`, which reports it in its own words.
void yedekAlanlariniDenetle(String json, {DateTime? now}) {
  if (jsonDepth(json) > syncMaxJsonDepth) return;
  final Object? kok;
  try {
    kok = jsonDecode(json);
  } on FormatException {
    return;
  }
  if (kok is! Map<String, dynamic>) return;
  final Map<String, dynamic> dosya = kok;
  List<Map<String, dynamic>> liste(String ad) {
    final v = dosya[ad];
    return v is List ? [for (final e in v) if (e is Map<String, dynamic>) e] : const [];
  }

  _checkFields(
    habits: liste('habits'),
    entries: liste('entries'),
    moods: liste('moods'),
    tasks: liste('tasks'),
    sessions: liste('sessions'),
    deleted: liste('deleted'),
    now: now ?? DateTime.now(),
  );
}

final _dayRe = RegExp(r'^\d{4}-\d{2}-\d{2}$');
final _weekdaysRe = RegExp(r'^([1-7](,[1-7])*)?$');

FormatException _bozuk(String what) =>
    FormatException('Yedek dosyası bozuk: $what. Hiçbir şey değişmedi.');

/// Field checks for what the screens parse or compare later, so a hostile or damaged file cannot leave
/// rows that crash a screen on every open (`parseYmd` on a bad day string) or whose far-future
/// `updatedAt` wins every last-writer-wins comparison from then on. Absent fields are fine (old
/// formats); present ones must be well-formed. Same limits as the `.habitsync` parser.
void _checkFields({
  required List<Map<String, dynamic>> habits,
  required List<Map<String, dynamic>> entries,
  required List<Map<String, dynamic>> moods,
  required List<Map<String, dynamic>> tasks,
  required List<Map<String, dynamic>> sessions,
  required List<Map<String, dynamic>> deleted,
  required DateTime now,
}) {
  final latest = now.millisecondsSinceEpoch ~/ 1000 + syncMaxFutureSecs;

  void int_(Map<String, dynamic> m, String k, int min, int max) {
    final v = m[k];
    if (v == null) return;
    if (v is! int || v < min || v > max) throw _bozuk('"$k" $min..$max arasında bir tamsayı olmalı');
  }

  void oneOf(Map<String, dynamic> m, String k, List<String> ok) {
    final v = m[k];
    if (v != null && (v is! String || !ok.contains(v))) throw _bozuk('"$k" beklenen değerlerden biri değil');
  }

  void day(Map<String, dynamic> m, String k, {bool required = false}) {
    final v = m[k];
    if (v == null && !required) return;
    if (v is! String || !_dayRe.hasMatch(v)) throw _bozuk('"$k" YYYY-AA-GG olmalı');
    final d = DateTime.utc(int.parse(v.substring(0, 4)), int.parse(v.substring(5, 7)), int.parse(v.substring(8, 10)));
    if (d.toIso8601String().substring(0, 10) != v) throw _bozuk('"$k" geçerli bir gün değil');
  }

  // A stamp later than now + 1 day is rejected, like in a sync file.
  void stamp(Map<String, dynamic> m, String k) {
    final v = m[k];
    if (v == null) return;
    final d = v is String ? DateTime.tryParse(v) : null;
    if (d == null) throw _bozuk('"$k" geçerli bir zaman değil');
    if (d.millisecondsSinceEpoch ~/ 1000 > latest) {
      throw _bozuk('"$k" gelecekte; cihazın saatini denetle');
    }
  }

  for (final h in habits) {
    int_(h, 'colorValue', 0, 0xFFFFFFFF);
    int_(h, 'iconCodePoint', 0, 0x10FFFF);
    int_(h, 'target', 1, 1000000000);
    int_(h, 'sortOrder', -1000000, 1000000);
    oneOf(h, 'kind', const ['bool', 'count']);
    final c = h['category'];
    if (c != null && (c is! String || c.length > 40)) throw _bozuk('"category" en çok 40 karakter olmalı');
    final w = h['scheduledWeekdays'];
    if (w != null && (w is! String || !_weekdaysRe.hasMatch(w))) throw _bozuk('"scheduledWeekdays" biçimi geçersiz');
    stamp(h, 'updatedAt');
  }
  for (final e in entries) {
    day(e, 'date', required: true);
    oneOf(e, 'status', const ['done', 'missed', 'skipped']);
    int_(e, 'value', 0, 1000000000);
    stamp(e, 'updatedAt');
  }
  for (final m in moods) {
    day(m, 'date', required: true);
    stamp(m, 'updatedAt');
  }
  for (final t in tasks) {
    day(t, 'dueDay');
    oneOf(t, 'status', const ['todo', 'doing', 'done']);
    int_(t, 'priority', 0, 2);
    stamp(t, 'updatedAt');
  }
  for (final s in sessions) {
    day(s, 'day');
    oneOf(s, 'kind', const ['focus', 'break']);
    int_(s, 'durationS', 0, 7 * 86400);
    stamp(s, 'updatedAt');
  }
  for (final d in deleted) {
    final k = d['key'];
    if (d['kind'] is! String || !syncKinds.contains(d['kind']) || k is! String || k.isEmpty || k.length > 200) {
      throw _bozuk('silinen kayıt izi geçersiz');
    }
    stamp(d, 'deletedAt');
  }
}
