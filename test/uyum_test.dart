import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards against silent drift from the desktop repo: every copied file must match
/// the SHA-256 recorded by tool/esitle.ps1 (line endings normalised to LF), unless it
/// is listed under "bilincli_sapmalar" with a reason.
void main() {
  final ozet =
      jsonDecode(File('tool/kaynak_ozet.json').readAsStringSync())
          as Map<String, dynamic>;
  final dosyalar = (ozet['dosyalar'] as Map).cast<String, String>();
  final sapmalar = {
    for (final s in (ozet['bilincli_sapmalar'] as List)) s['dosya'] as String,
  };

  String sha(File f) => sha256
      .convert(utf8.encode(f.readAsStringSync().replaceAll('\r\n', '\n')))
      .toString();

  test('her sapma bir gerekçe taşır', () {
    for (final s in (ozet['bilincli_sapmalar'] as List)) {
      expect((s['gerekce'] as String).trim(), isNotEmpty, reason: '${s['dosya']}');
      expect(dosyalar, contains(s['dosya']));
    }
  });

  test('kopyalar kaynak özetiyle tutuyor', () {
    final bozuk = <String>[];
    for (final e in dosyalar.entries) {
      if (sapmalar.contains(e.key)) continue;
      final f = File(e.key);
      if (!f.existsSync() || sha(f) != e.value) bozuk.add(e.key);
    }
    expect(bozuk, isEmpty,
        reason: 'Elle değişmiş ya da eksik kopya; tool/esitle.ps1 çalıştır '
            'ya da bilinçli sapma olarak yaz.');
  });

  test('masaüstü testleri ayrı dosyalar olarak duruyor', () {
    final testler = dosyalar.keys.where((k) => k.startsWith('test/') && k.endsWith('_test.dart'));
    expect(testler, isNotEmpty);
    for (final t in testler) {
      expect(File(t).existsSync(), isTrue, reason: t);
    }
  });
}
