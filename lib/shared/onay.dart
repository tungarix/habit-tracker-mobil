import 'package:flutter/material.dart';

import '../ui_metin.dart';

/// Geri alınamaz silme için onay penceresi; yalnız "Sil"e basılırsa true döner.
Future<bool> onayIste(BuildContext context, String baslik, String govde) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(baslik),
      content: Text(govde),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text(Metin.iptal),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(ctx).colorScheme.error,
          ),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text(Metin.sil),
        ),
      ],
    ),
  );
  return ok == true;
}
