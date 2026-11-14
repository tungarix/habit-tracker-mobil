import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../data/providers.dart';
import '../../shared/onay.dart';
import '../../shared/theme.dart';
import '../../ui_metin.dart';
import 'widgets/mood_card.dart';

/// Tüm ruh hali kayıtları, yeniden eskiye; not düzenleme ve gün silme.
class MoodGecmisiScreen extends ConsumerWidget {
  const MoodGecmisiScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final moods = [...?ref.watch(allMoodsProvider).value]
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      appBar: AppBar(title: const Text(Metin.moodGecmisiBaslik)),
      body: moods.isEmpty
          ? Center(
              child: Text(
                Metin.moodGecmisiYok,
                style: TextStyle(color: colors.textDim),
              ),
            )
          : ListView.builder(
              itemCount: moods.length,
              itemBuilder: (context, i) {
                final m = moods[i];
                final mood = Mood.fromValue(m.mood);
                final note = m.note ?? '';
                return ListTile(
                  leading: mood == null
                      ? null
                      : Icon(mood.icon, semanticLabel: mood.label),
                  title: Text(Metin.gunBasligi(parseYmd(m.date))),
                  subtitle: Text(
                    note.isEmpty ? Metin.notYok : note,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: note.isEmpty
                        ? TextStyle(color: colors.textDim)
                        : null,
                  ),
                  trailing: IconButton(
                    tooltip: '${Metin.sil}: ${Metin.gunBasligi(parseYmd(m.date))}',
                    icon: const Icon(Icons.delete_outline),
                    onPressed: () async {
                      final ok = await onayIste(
                        context,
                        Metin.gunSilBaslik,
                        Metin.gunSilGovde,
                      );
                      if (ok) {
                        await ref
                            .read(habitRepositoryProvider)
                            .clearMood(m.date);
                      }
                    },
                  ),
                  onTap: () => notDuzenle(
                    context,
                    ref,
                    m.date,
                    m.note,
                    baslik: Metin.gunBasligi(parseYmd(m.date)),
                  ),
                );
              },
            ),
    );
  }
}
