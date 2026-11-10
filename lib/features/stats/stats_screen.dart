import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/stats.dart';
import '../../core/streak.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/habit_avatar.dart';
import '../../ui_metin.dart';

/// Statistics: overview cards, per-habit cards (streak, completion, 30-day
/// trend) and a simple mood ↔ completion correlation view.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final habits = ref.watch(activeHabitsProvider).value ?? const <Habit>[];
    final statusesByHabit =
        ref.watch(statusesByHabitProvider).value ??
        const <int, Map<String, EntryStatus>>{};
    final moodByDate = ref.watch(moodByDateProvider);
    final overview = ref.watch(overviewProvider);
    final t = ref.watch(todayProvider);
    final dayStartHour = ref.watch(dayStartHourProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Semantics(
          header: true,
          child: Text(
            Metin.istatistik,
            style: Theme.of(context).textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 2),
        Text(Metin.istatistikAlt, style: TextStyle(color: colors.textDim)),
        const SizedBox(height: 16),

        _OverviewCards(overview: overview),
        const SizedBox(height: 20),

        if (habits.isNotEmpty) ...[
          const _SectionTitle(Metin.alisanliklar),
          const SizedBox(height: 8),
          for (final h in habits)
            _HabitStatsCard(
              habit: h,
              statuses: statusesByHabit[h.id] ?? const <String, EntryStatus>{},
              todayDate: t,
              dayStartHour: dayStartHour,
            ),
          const SizedBox(height: 12),
        ],

        const _SectionTitle(Metin.moodTamamlama),
        const SizedBox(height: 8),
        _MoodCorrelationCard(
          habits: habits,
          statusesByHabit: statusesByHabit,
          moodByDate: moodByDate,
          todayDate: t,
          dayStartHour: dayStartHour,
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Semantics(
      header: true,
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _OverviewCards extends StatelessWidget {
  final OverviewStats overview;
  const _OverviewCards({required this.overview});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final cards = [
      _StatCard(
        label: Metin.toplamIsaret,
        value: '${overview.totalMarks}',
        color: colors.text,
      ),
      _StatCard(
        label: Metin.mevcutSeri,
        value: '${overview.bestCurrent}',
        suffix: Metin.gun,
        color: colors.done,
      ),
      _StatCard(
        label: Metin.enUzunSeri,
        value: '${overview.bestLongest}',
        suffix: Metin.gun,
        color: colors.gold,
      ),
      _StatCard(
        label: Metin.buAy,
        value: '${overview.thisMonth}',
        color: colors.text,
      ),
    ];
    // Phone width: always two by two.
    return Column(
      children: [
        Row(
          children: [
            Expanded(child: cards[0]),
            const SizedBox(width: 12),
            Expanded(child: cards[1]),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(child: cards[2]),
            const SizedBox(width: 12),
            Expanded(child: cards[3]),
          ],
        ),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;
  final String? suffix;
  final Color color;
  const _StatCard({
    required this.label,
    required this.value,
    this.suffix,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Semantics(
          label: '$label: $value${suffix == null ? '' : ' $suffix'}',
          container: true,
          excludeSemantics: true,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: TextStyle(color: colors.textDim, fontSize: 13),
              ),
              const SizedBox(height: 12),
              Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Flexible(
                    child: Text(
                      value,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.bold,
                        color: color,
                      ),
                    ),
                  ),
                  if (suffix != null) ...[
                    const SizedBox(width: 5),
                    Text(
                      suffix!,
                      style: TextStyle(color: colors.textDim, fontSize: 14),
                    ),
                  ],
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One habit's card: streak numbers, completion rate and a 30-day strip.
class _HabitStatsCard extends StatelessWidget {
  final Habit habit;
  final Map<String, EntryStatus> statuses;
  final DateTime todayDate;
  final int dayStartHour;
  const _HabitStatsCard({
    required this.habit,
    required this.statuses,
    required this.todayDate,
    required this.dayStartHour,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final stats = computeStats(
      habit,
      statuses,
      todayDate,
      dayStartHour: dayStartHour,
    );
    final category = HabitCategory.tryParse(habit.category);

    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ExcludeSemantics(child: HabitAvatar(habit: habit, size: 34)),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    habit.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 15,
                    ),
                  ),
                ),
                if (category != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.surfaceAlt,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      category.label,
                      style: TextStyle(fontSize: 12, color: colors.textDim),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _miniStat(
                  colors,
                  Metin.mevcutSeri,
                  '${stats.streak.current} ${Metin.gun}',
                  colors.done,
                ),
                _miniStat(
                  colors,
                  Metin.enUzun,
                  '${stats.streak.longest} ${Metin.gun}',
                  colors.gold,
                ),
                _miniStat(
                  colors,
                  Metin.tamamlama,
                  '%${(stats.completionRate * 100).round()}',
                  colors.text,
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              Metin.son30Gun,
              style: TextStyle(fontSize: 12, color: colors.textDim),
            ),
            const SizedBox(height: 6),
            _TrendStrip(
              habit: habit,
              statuses: statuses,
              todayDate: todayDate,
              dayStartHour: dayStartHour,
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniStat(AppColors colors, String label, String value, Color color) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(fontSize: 12, color: colors.textDim)),
          const SizedBox(height: 2),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// 30 small squares, oldest to newest: ✓ green, ✗/empty-past red-tinted,
/// – grey, off-days and pre-creation faint.
class _TrendStrip extends StatelessWidget {
  final Habit habit;
  final Map<String, EntryStatus> statuses;
  final DateTime todayDate;
  final int dayStartHour;
  const _TrendStrip({
    required this.habit,
    required this.statuses,
    required this.todayDate,
    required this.dayStartHour,
  });

  static const _days = 30;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    // Which cell is which state is a logic question, answered by core/.
    final cells = habitHeatmap(
      habit,
      statuses,
      todayDate,
      _days,
      dayStartHour: dayStartHour,
    );

    int count(HeatCell c) => cells.where((x) => x == c).length;

    // The squares carry no individual meaning for TalkBack; read a summary.
    return Semantics(
      label: Metin.seritEtiketi(
        habit.name,
        done: count(HeatCell.done),
        missed: count(HeatCell.missed),
        skipped: count(HeatCell.skipped),
      ),
      container: true,
      excludeSemantics: true,
      child: LayoutBuilder(
        builder: (context, c) {
          final width = ((c.maxWidth - (_days - 1) * 2) / _days).clamp(
            4.0,
            12.0,
          );
          return Row(
            children: [
              for (var i = 0; i < _days; i++) ...[
                Container(
                  width: width,
                  height: 14,
                  decoration: BoxDecoration(
                    color: _fillFor(colors, cells[i]),
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
                if (i < _days - 1) const SizedBox(width: 2),
              ],
            ],
          );
        },
      ),
    );
  }

  static Color _fillFor(AppColors colors, HeatCell cell) => switch (cell) {
    HeatCell.done => colors.done,
    HeatCell.skipped => colors.skipped,
    // A past scheduled day left untracked reads as a miss, just softer.
    HeatCell.missed => colors.missed,
    HeatCell.inactive => colors.idle,
  };
}

/// Average daily completion rate grouped by that day's mood: one bar per mood.
class _MoodCorrelationCard extends StatelessWidget {
  final List<Habit> habits;
  final Map<int, Map<String, EntryStatus>> statusesByHabit;
  final Map<String, MoodEntry> moodByDate;
  final DateTime todayDate;
  final int dayStartHour;
  const _MoodCorrelationCard({
    required this.habits,
    required this.statusesByHabit,
    required this.moodByDate,
    required this.todayDate,
    required this.dayStartHour,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);

    // All arithmetic lives in core/stats.dart; this widget only draws it.
    final correlation = moodCompletionCorrelation(
      habits,
      statusesByHabit,
      moodByDate,
      todayDate,
      dayStartHour: dayStartHour,
    );
    final totalDays = correlation.sampleDays;

    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: totalDays < 3
            ? SizedBox(
                height: 120,
                child: Center(
                  child: Text(
                    Metin.moodYetersiz,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textDim, fontSize: 13),
                  ),
                ),
              )
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    Metin.moodAciklama(totalDays),
                    style: TextStyle(fontSize: 12, color: colors.textDim),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: 160,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        for (final mood in Mood.values) ...[
                          Expanded(
                            child: _moodBar(
                              colors,
                              mood,
                              correlation.averageByMood[mood.value],
                              correlation.daysByMood[mood.value] ?? 0,
                            ),
                          ),
                          if (mood != Mood.values.last)
                            const SizedBox(width: 10),
                        ],
                      ],
                    ),
                  ),
                  if (correlation.r != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      _correlationLabel(correlation.r!),
                      style: TextStyle(fontSize: 12, color: colors.textDim),
                    ),
                  ],
                ],
              ),
      ),
    );
  }

  Widget _moodBar(AppColors colors, Mood mood, double? avgRate, int count) {
    final has = avgRate != null;
    return Semantics(
      label: Metin.moodCubuguEtiketi(
        mood.label,
        has ? (avgRate * 100).round() : null,
        count,
      ),
      container: true,
      excludeSemantics: true,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text(
            has ? '%${(avgRate * 100).round()}' : '—',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: has ? colors.text : colors.textDim,
            ),
          ),
          const SizedBox(height: 4),
          Expanded(
            child: Align(
              alignment: Alignment.bottomCenter,
              child: FractionallySizedBox(
                heightFactor: has ? avgRate.clamp(0.03, 1.0) : 0.03,
                child: Container(
                  decoration: BoxDecoration(
                    color: has ? colors.done : colors.idle,
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(5),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 6),
          Icon(mood.icon, size: 18, color: colors.textDim),
          const SizedBox(height: 2),
          Text(
            count > 0 ? '$count ${Metin.gun}' : '',
            style: TextStyle(fontSize: 12, color: colors.textDim),
          ),
        ],
      ),
    );
  }

  static String _correlationLabel(double r) {
    final strength = r.abs() >= 0.6
        ? 'güçlü'
        : r.abs() >= 0.3
        ? 'orta'
        : 'zayıf';
    final direction = r >= 0 ? 'pozitif' : 'negatif';
    return 'Korelasyon: r = ${r.toStringAsFixed(2)} ($strength $direction ilişki)';
  }
}
