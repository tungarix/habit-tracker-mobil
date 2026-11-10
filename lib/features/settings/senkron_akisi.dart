import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/providers.dart';
import '../../data/sync/sync_format.dart';
import '../../data/sync/sync_import.dart';
import '../../data/sync/sync_parse.dart';
import '../../ui_metin.dart';

/// Validates [bytes] (a `.habitsync` file), asks the user, then merges.
/// Used by the settings button and by files opened from outside the app.
/// An invalid file is rejected before anything is asked or changed.
Future<void> senkronDosyasiniIceAktar(
  BuildContext context,
  WidgetRef ref,
  Uint8List bytes,
) async {
  final db = ref.read(databaseProvider);
  void toast(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  final SyncFile dosya;
  try {
    dosya = parseSync(bytes);
  } on SyncException catch (e) {
    toast(Metin.senkronGecersiz(e.message));
    return;
  }
  if (!context.mounted) return;
  final onay = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text(Metin.senkronOnayBaslik),
      content: SingleChildScrollView(
        child: Text(
          Metin.senkronOnayIcerik(
            dosya.habits.length,
            dosya.entries.length,
            dosya.tasks.length,
            dosya.sessions.length,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(Metin.iptal),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(Metin.senkronIceAktarDugme),
        ),
      ],
    ),
  );
  if (onay != true) return;
  try {
    final rapor = await importSyncBytes(db, bytes);
    // The day-start hour may have come with the file.
    ref.invalidate(dayStartHourProvider);
    toast(rapor.summary());
  } on SyncException catch (e) {
    toast(Metin.senkronGecersiz(e.message));
  } catch (e) {
    toast(Metin.iceAktarmaHata('$e'));
  }
}
