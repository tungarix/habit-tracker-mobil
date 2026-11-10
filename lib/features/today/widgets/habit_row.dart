import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/stats.dart';
import '../../../data/database/database.dart';
import '../../../data/models/habit_today_view.dart';
import '../../../data/providers.dart';
import '../../../shared/habit_actions.dart';
import '../../../shared/theme.dart';
import '../../../shared/widgets/status_mark.dart';
import '../../../ui_metin.dart';
import 'heat_strip.dart';

/// One habit on the Bugün list: tap cycles the mark, long press enters an
/// amount (count habits), the chevron opens the card's 30-day heat strip.
class HabitRow extends ConsumerStatefulWidget {
  final HabitTodayView view;
  final bool dimmed;
  const HabitRow({super.key, required this.view, this.dimmed = false});

  @override
  ConsumerState<HabitRow> createState() => _HabitRowState();
}

class _HabitRowState extends ConsumerState<HabitRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final view = widget.view;
    final habit = view.habit;
    final day = ref.watch(todayProvider);
    final count = isCountHabit(habit);
    final value =
        ref.watch(valuesByHabitProvider)[habit.id]?[formatYmd(day)] ?? 0;

    final state = Metin.durum(view.status);
    final label = count
        ? '${Metin.hucre(habit.name, day, state)}, $value / ${habit.target}'
        : Metin.hucre(habit.name, day, state);

    void tap() => cycleHabit(context, ref, habit, day);
    void longPress() =>
        enterHabitAmount(context, ref, habit, day, currentValue: value);

    return Opacity(
      opacity: widget.dimmed ? 0.7 : 1,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: Semantics(
      container: true,
                  button: true,
                  label: label,
                  hint: count ? Metin.ipucuSayilabilir : Metin.ipucuDokun,
                  excludeSemantics: true,
                  onTap: tap,
                  onLongPress: count ? longPress : null,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: tap,
                    onLongPress: count ? longPress : null,
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(minHeight: 56),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 6,
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 4,
                              height: 32,
                              decoration: BoxDecoration(
                                color: Color(habit.colorValue),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    habit.name,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  if (count)
                                    Text(
                                      '$value / ${habit.target}',
                                      style: kTabularNums.copyWith(
                                        fontSize: 12,
                                        color: colors.textDim,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                            if (view.streak.current > 0) ...[
                              Text(
                                '${view.streak.current}',
                                style: kTabularNums.copyWith(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: colors.done,
                                ),
                              ),
                              const SizedBox(width: 2),
                              Icon(
                                Icons.local_fire_department_outlined,
                                size: 16,
                                color: colors.gold,
                              ),
                              const SizedBox(width: 10),
                            ],
                            StatusMark(status: view.status, size: 40),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: _open ? Metin.isiSeridiKapat : Metin.isiSeridiAc,
                icon: Icon(
                  _open ? Icons.expand_less : Icons.expand_more,
                  color: colors.textDim,
                ),
                onPressed: () => setState(() => _open = !_open),
              ),
            ],
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: Alignment.topCenter,
            child: _open
                ? _Strip(habit: habit)
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _Strip extends ConsumerWidget {
  final Habit habit;
  const _Strip({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayProvider);
    final statuses = ref.watch(habitStatusesProvider(habit.id));
    final values = ref.watch(valuesByHabitProvider)[habit.id] ?? const {};
    final points = habitHeatPoints(
      habit,
      statuses,
      values,
      day,
      30,
      dayStartHour: ref.watch(dayStartHourProvider),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 2, 14, 10),
      child: HeatStrip(
        habitName: habit.name,
        points: points,
        endDay: day,
        color: Color(habit.colorValue),
      ),
    );
  }
}
