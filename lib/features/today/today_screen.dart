import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/models/habit_today_view.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../ui_metin.dart';
import '../tasks/widgets/week_tasks_card.dart';
import 'widgets/focus_card.dart';
import 'widgets/habit_row.dart';
import 'widgets/mood_card.dart';

enum _Menu { aliskanliklar, ayarlar }

/// The screen the app opens to: today's habits, mood, focus timer and the
/// week's tasks, in one scrolling column.
///
/// Habits and Settings are pushed routes, owned by the shell; this screen only
/// raises the callbacks so it does not depend on those screens.
class TodayScreen extends ConsumerWidget {
  final VoidCallback onAliskanliklar;
  final VoidCallback onAyarlar;
  final VoidCallback onGorevler;

  const TodayScreen({
    super.key,
    required this.onAliskanliklar,
    required this.onAyarlar,
    required this.onGorevler,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final habits = ref.watch(activeHabitsProvider);
    final day = ref.watch(todayProvider);

    return Scaffold(
      appBar: AppBar(
        title: Text(Metin.gunBasligi(day)),
        actions: [
          PopupMenuButton<_Menu>(
            tooltip: Metin.menu,
            onSelected: (m) => switch (m) {
              _Menu.aliskanliklar => onAliskanliklar(),
              _Menu.ayarlar => onAyarlar(),
            },
            itemBuilder: (_) => const [
              PopupMenuItem(
                value: _Menu.aliskanliklar,
                child: Text(Metin.menuAliskanliklar),
              ),
              PopupMenuItem(
                value: _Menu.ayarlar,
                child: Text(Metin.menuAyarlar),
              ),
            ],
          ),
        ],
      ),
      body: habits.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (list) => ListView(
          padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
          children: [
            const _Summary(),
            const SizedBox(height: 12),
            _HabitsCard(empty: list.isEmpty, onAliskanliklar: onAliskanliklar),
            const SizedBox(height: 12),
            const MoodCard(),
            const SizedBox(height: 12),
            const FocusCard(),
            const SizedBox(height: 12),
            WeekTasksCard(onShowAll: onGorevler),
          ],
        ),
      ),
    );
  }
}

/// X/Y done today, 7-day completion, open tasks, and a progress bar.
class _Summary extends ConsumerWidget {
  const _Summary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final progress = ref.watch(todayProgressProvider);
    final week = ref.watch(weekCompletionProvider);
    final tasks = ref.watch(taskSummaryProvider);

    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 18,
            runSpacing: 6,
            children: [
              _Stat(
                value: '${progress.done}/${progress.total}',
                label: Metin.ozetAliskanlik,
                color: progress.total > 0 && progress.done == progress.total
                    ? colors.done
                    : colors.text,
              ),
              _Stat(
                value: '%${(week * 100).round()}',
                label: Metin.ozet7Gun,
                color: colors.text,
              ),
              if (tasks.open > 0)
                _Stat(
                  value: '${tasks.open}',
                  label: Metin.ozetGorev(tasks.overdue),
                  color: tasks.overdue > 0 ? colors.missed : colors.text,
                ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: progress.ratio,
              minHeight: 6,
              color: colors.done,
              backgroundColor: colors.idle,
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;
  const _Stat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      label: '$value $label',
      excludeSemantics: true,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            value,
            style: kTabularNums.copyWith(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          const SizedBox(width: 5),
          Text(label, style: TextStyle(fontSize: 12, color: colors.textDim)),
        ],
      ),
    );
  }
}

/// Today's habits: the one thing that must be doable without hunting.
class _HabitsCard extends ConsumerWidget {
  final bool empty;
  final VoidCallback onAliskanliklar;
  const _HabitsCard({required this.empty, required this.onAliskanliklar});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final views =
        ref.watch(todayViewsProvider).value ?? const <HabitTodayView>[];
    final scheduled = views.where((v) => v.scheduledToday).toList();
    final rest = views.where((v) => !v.scheduledToday).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 12, 4, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 0, 0, 6),
              child: Row(
                children: [
                  Icon(Icons.today_outlined, size: 18, color: colors.textDim),
                  const SizedBox(width: 8),
                  Text(
                    Metin.bugunKart,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textDim,
                    ),
                  ),
                ],
              ),
            ),
            if (empty)
              Padding(
                padding: const EdgeInsets.fromLTRB(6, 6, 10, 10),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      Metin.aliskanlikYok,
                      style: TextStyle(fontSize: 14, color: colors.textDim),
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonalIcon(
                      onPressed: onAliskanliklar,
                      icon: const Icon(Icons.add, size: 18),
                      label: const Text(Metin.aliskanliklaraGit),
                    ),
                  ],
                ),
              )
            else ...[
              for (final v in scheduled)
                HabitRow(key: ValueKey(v.habit.id), view: v),
              if (rest.isNotEmpty) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(6, 10, 0, 4),
                  child: Text(
                    Metin.planliDegil,
                    style: TextStyle(fontSize: 12, color: colors.textDim),
                  ),
                ),
                for (final v in rest)
                  HabitRow(key: ValueKey(v.habit.id), view: v, dimmed: true),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
