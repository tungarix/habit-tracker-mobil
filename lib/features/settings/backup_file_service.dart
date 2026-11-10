import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

/// Largest backup file the app will read into memory (16 MB; a real backup is
/// a few hundred KB).
const maxBackupBytes = 16 * 1024 * 1024;

/// Thin seam over the file picker and the system share sheet so widget tests
/// can swap in a fake.
abstract class BackupFileService {
  /// Lets the user pick a backup; null if they cancelled, else the file text.
  Future<String?> pickBackup();

  /// Writes [json] to a temp file called [fileName] and opens the share sheet.
  Future<void> shareBackup(String json, String fileName);
}

class SystemBackupFileService implements BackupFileService {
  @override
  Future<String?> pickBackup() async {
    final file = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: const ['json'],
    );
    if (file == null) return null;
    // readAsBytes also works for content:// URIs, where File(path) would not.
    final size = await file.length();
    if (size != null && size > maxBackupBytes) {
      throw const FormatException('Dosya çok büyük.');
    }
    final bytes = await file.readAsBytes();
    if (bytes.length > maxBackupBytes) {
      throw const FormatException('Dosya çok büyük.');
    }
    return utf8.decode(bytes);
  }

  @override
  Future<void> shareBackup(String json, String fileName) async {
    final dir = await getTemporaryDirectory();
    // Earlier shares leave a full copy of the data behind; clear them first.
    await for (final e in dir.list()) {
      if (e is File &&
          p.basename(e.path).startsWith('aktenak-') &&
          e.path.endsWith('.json')) {
        try {
          await e.delete();
        } on FileSystemException {
          // Still in use by the receiving app; next share retries.
        }
      }
    }
    final file = File(p.join(dir.path, fileName));
    await file.writeAsString(json, flush: true);
    await SharePlus.instance.share(
      ShareParams(files: [XFile(file.path, mimeType: 'application/json')]),
    );
  }
}

final backupFileServiceProvider = Provider<BackupFileService>(
  (ref) => SystemBackupFileService(),
);
