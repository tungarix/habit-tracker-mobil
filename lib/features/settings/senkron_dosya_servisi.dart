import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../data/sync/sync_format.dart';

/// Seam over the file picker and the share sheet for `.habitsync` files, so
/// widget tests can swap in a fake.
abstract class SenkronDosyaServisi {
  /// Lets the user pick a file; null if cancelled. The size limit is enforced
  /// here (before reading) and again by the parser.
  Future<Uint8List?> sec();

  /// Writes [text] to a temp file called [ad] and opens the share sheet.
  Future<void> paylas(String text, String ad);
}

class SistemSenkronDosyaServisi implements SenkronDosyaServisi {
  @override
  Future<Uint8List?> sec() async {
    // FileType.any: Android has no MIME type for ".habitsync", a custom filter could grey the file out.
    // The content check (format field) is what really validates the file.
    final file = await FilePicker.pickFile(type: FileType.any);
    if (file == null) return null;
    final size = await file.length();
    if (size != null && size > syncMaxFileBytes) {
      throw const SyncException('Dosya çok büyük (en çok 16 MB).');
    }
    return file.readAsBytes();
  }

  @override
  Future<void> paylas(String text, String ad) async {
    final dir = await getTemporaryDirectory();
    // Earlier shares leave a full copy of the data behind; clear them first.
    await for (final e in dir.list()) {
      if (e is File && e.path.endsWith('.$syncExtension')) {
        try {
          await e.delete();
        } on FileSystemException {
          // Still in use by the receiving app; next share retries.
        }
      }
    }
    final file = File(p.join(dir.path, ad));
    await file.writeAsBytes(utf8.encode(text), flush: true);
    await SharePlus.instance.share(
      ShareParams(
        files: [XFile(file.path, mimeType: 'application/x-habitsync')],
      ),
    );
  }
}

final senkronDosyaServisiProvider = Provider<SenkronDosyaServisi>(
  (ref) => SistemSenkronDosyaServisi(),
);
