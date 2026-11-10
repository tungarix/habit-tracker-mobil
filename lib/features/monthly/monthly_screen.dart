import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../shared/habit_actions.dart';
import '../../shared/habit_style.dart';
import '../../shared/theme.dart';
import '../../shared/widgets/status_mark.dart';
import '../habits/habit_edit_dialog.dart';
import '../../ui_metin.dart';

/// Monthly grid, laid out like a classic paper tracker: rows are habits,
/// columns are the days of the month. Tap a cell to cycle ✓ → ✗ → – → boş.
/// Below the grid, the month's mood line is drawn on the same day axis.
///
/// The habit names sit in a fixed left column outside the horizontal scroll
/// view, so they stay put while the days slide underneath.
///
/// Performance: the screen itself only watches the habit list; every cell
/// watches just its own (habit, day) status and the mood line has its own
/// consumer, so a tap repaints one cell instead of the whole grid.
class MonthlyScreen extends ConsumerStatefulWidget {
  const MonthlyScreen({super.key});

  @override
  ConsumerState<MonthlyScreen> createState() => _MonthlyScreenState();
}

class _MonthlyScreenState extends ConsumerState<MonthlyScreen> {
  static const double _labelW = 120;
  static const double _cellW = 48;
  static const double _rowH = 48;
  static const double _headerH = 56;
  static const double _moodH = 120;

  late DateTime _month;

  @override
  void initState() {
    super.initState();
    _month = firstOfMonth(ref.read(todayProvider));
  }

  void _shiftMonth(int delta) {
    setState(() => _month = DateTime(_month.year, _month.month + delta, 1));
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final habits = ref.watch(activeHabitsProvider).value;

    if (habits == null) {
      return const Center(child: CircularProgressIndicator());
    }
    if (habits.isEmpty) {
      return _EmptyState(onAdd: () => HabitEditDialog.show(context));
    }

    final t = ref.watch(todayProvider);
    final days = daysInMonth(_month);
    final isCurrentMonth = _month.year == t.year && _month.month == t.month;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _monthHeader(isCurrentMonth),
        Expanded(
          // The grid has fixed cell/row heights, so cap the system font scale here only (at 200% the
          // weekday letters and 2-line habit names overflowed); the rest of the app still scales fully.
          child: MediaQuery.withClampedTextScaling(
            maxScaleFactor: 1.3,
            child: SingleChildScrollView(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _labelColumn(colors, habits),
                  Expanded(
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SizedBox(
                        width: days * _cellW,
                        child: Column(
                          children: [
                            RepaintBoundary(
                              child: _dayHeaderRow(colors, days, t),
                            ),
                            for (final h in habits)
                              RepaintBoundary(
                                child: _HabitRow(
                                  habit: h,
                                  month: _month,
                                  days: days,
                                  todayDate: t,
                                  cellW: _cellW,
                                  rowH: _rowH,
                                ),
                              ),
                            const SizedBox(height: 8),
                            RepaintBoundary(
                              child: _MoodLine(
                                month: _month,
                                days: days,
                                cellW: _cellW,
                                height: _moodH,
                                todayIndex: isCurrentMonth ? t.day - 1 : null,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _monthHeader(bool isCurrentMonth) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Row(
        children: [
          Expanded(
            child: Semantics(
              header: true,
              child: Text(
                '${Metin.aylar[_month.month - 1]} ${_month.year}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ),
          if (!isCurrentMonth)
            TextButton(
              onPressed: () => setState(
                () => _month = firstOfMonth(ref.read(todayProvider)),
              ),
              child: const Text(Metin.bugunDon),
            ),
          IconButton(
            tooltip: Metin.oncekiAy,
            icon: const Icon(Icons.chevron_left),
            onPressed: () => _shiftMonth(-1),
          ),
          IconButton(
            tooltip: Metin.sonrakiAy,
            icon: const Icon(Icons.chevron_right),
            onPressed: () => _shiftMonth(1),
          ),
        ],
      ),
    );
  }

  /// Fixed left pane: spacer for the day header, one label per habit, mood label.
  Widget _labelColumn(AppColors colors, List<Habit> habits) {
    return SizedBox(
      width: _labelW,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: _headerH),
          for (final h in habits)
            SizedBox(
              height: _rowH,
              child: Row(
                children: [
                  const SizedBox(width: 12),
                  Icon(
                    iconFromCodePoint(h.iconCodePoint),
                    size: 16,
                    color: Color(h.colorValue),
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      h.name,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            ),
          const SizedBox(height: 8),
          SizedBox(
            height: _moodH,
            child: Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 12),
                child: Text(
                  Metin.mood,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: colors.textDim,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _dayHeaderRow(AppColors colors, int days, DateTime t) {
    return SizedBox(
      height: _headerH,
      child: Row(
        children: [
          for (var d = 1; d <= days; d++)
            _dayHeaderCell(colors, DateTime(_month.year, _month.month, d), t),
        ],
      ),
    );
  }

  Widget _dayHeaderCell(AppColors colors, DateTime day, DateTime t) {
    final isToday = day == t;
    return Semantics(
      label: Metin.aylikGunBasligi(day, isToday),
      excludeSemantics: true,
      child: SizedBox(
        width: _cellW,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 26,
              height: 26,
              alignment: Alignment.center,
              decoration: isToday
                  ? BoxDecoration(color: colors.done, shape: BoxShape.circle)
                  : null,
              child: Text(
                '${day.day}',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: isToday ? FontWeight.w800 : FontWeight.w600,
                  color: isToday ? Colors.white : colors.text,
                ),
              ),
            ),
            const SizedBox(height: 1),
            Text(
              kWeekdayShort[day.weekday - 1].substring(0, 1),
              style: TextStyle(fontSize: 12, color: colors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}

/// One habit's row of day cells. Stateless w.r.t. entry data — each cell
/// subscribes to its own status. Only the day-start setting is watched here,
/// to find the habit's first *tracking* day.
class _HabitRow extends ConsumerWidget {
  final Habit habit;
  final DateTime month;
  final int days;
  final DateTime todayDate;
  final double cellW;
  final double rowH;
  const _HabitRow({
    required this.habit,
    required this.month,
    required this.days,
    required this.todayDate,
    required this.cellW,
    required this.rowH,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // The tracking day the habit was created on, not the calendar day: a habit
    // added at 01:30 started on the day that was still running, so that cell
    // must stay markable.
    final created = dayOf(
      habit.createdAt,
      dayStartHour: ref.watch(dayStartHourProvider),
    );
    return SizedBox(
      height: rowH,
      child: Row(
        children: [
          for (var d = 1; d <= days; d++)
            _GridCell(
              key: ValueKey(
                'grid-cell-${habit.id}-${formatYmd(DateTime(month.year, month.month, d))}',
              ),
              habit: habit,
              day: DateTime(month.year, month.month, d),
              created: created,
              todayDate: todayDate,
              cellW: cellW,
              rowH: rowH,
            ),
        ],
      ),
    );
  }
}

/// A single day cell. Watches only its own status, so taps anywhere in the
/// grid rebuild exactly one cell.
class _GridCell extends ConsumerWidget {
  final Habit habit;
  final DateTime day;
  final DateTime created;
  final DateTime todayDate;
  final double cellW;
  final double rowH;
  const _GridCell({
    super.key,
    required this.habit,
    required this.day,
    required this.created,
    required this.todayDate,
    required this.cellW,
    required this.rowH,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final dateStr = formatYmd(day);
    final status = ref.watch(
      habitStatusesProvider(habit.id).select((m) => m[dateStr]),
    );
    final value = ref.watch(
      valuesByHabitProvider.select((m) => m[habit.id]?[dateStr] ?? 0),
    );

    final isFuture = day.isAfter(todayDate);
    final beforeCreated = day.isBefore(created);
    final scheduled = isScheduledOn(habit.scheduledWeekdays, day);
    final tappable = !isFuture && !beforeCreated;

    final Color fill;
    final Color glyphColor;
    if (status != null) {
      final c = statusColor(colors, status);
      fill = c.withValues(alpha: status == EntryStatus.done ? 1 : 0.22);
      glyphColor = status == EntryStatus.done ? Colors.white : c;
    } else {
      fill = colors.idle.withValues(
        alpha: (isFuture || beforeCreated || !scheduled) ? 0.45 : 1,
      );
      glyphColor = Colors.transparent;
    }

    final icon = statusIcon(status);
    final isCount = isCountHabit(habit);

    void tap() => cycleHabit(context, ref, habit, day);
    // Count habits take their amount on long press (tap still cycles ✓ ✗ –).
    void longPress() =>
        enterHabitAmount(context, ref, habit, day, currentValue: value);

    // The InkWell spans the whole 48dp cell (touch target); the coloured
    // box inside is inset 3px for the paper-grid look. The semantics node is
    // built by hand so TalkBack reads "Kitap, 12 Kasım: yapıldı" and the
    // glyph inside is not read a second time.
    return Semantics(
      label: Metin.hucreEtiketi(
        habitName: habit.name,
        day: day,
        status: status,
        value: isCount ? value : null,
        target: isCount ? habit.target : null,
        isFuture: isFuture,
        beforeCreated: beforeCreated,
        scheduled: scheduled,
      ),
      button: true,
      enabled: tappable,
      onTap: tappable ? tap : null,
      onLongPress: tappable && isCount ? longPress : null,
      excludeSemantics: true,
      child: SizedBox(
        width: cellW,
        height: rowH,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: tappable ? tap : null,
            onLongPress: tappable && isCount ? longPress : null,
            child: Padding(
              padding: const EdgeInsets.all(3),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 120),
                decoration: BoxDecoration(
                  color: fill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: icon == null
                    ? null
                    : Icon(icon, size: 18, color: glyphColor),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Bullet-journal style mood line under the grid, sharing the day axis:
/// x = day column centre, y = mood 1..5. Watches moods itself, so habit
/// taps never repaint it (and mood taps never repaint the grid).
class _MoodLine extends ConsumerWidget {
  final DateTime month;
  final int days;
  final double cellW;
  final double height;
  final int? todayIndex;
  const _MoodLine({
    required this.month,
    required this.days,
    required this.cellW,
    required this.height,
    required this.todayIndex,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final moodByDate = ref.watch(moodByDateProvider);
    final moods = List<int?>.generate(days, (i) {
      final date = formatYmd(DateTime(month.year, month.month, i + 1));
      return moodByDate[date]?.mood;
    });
    final recorded = moods.whereType<int>().length;

    return SizedBox(
      width: days * cellW,
      height: height,
      child: recorded > 0
          ? Semantics(
              label: Metin.moodGrafigiEtiketi(recorded),
              image: true,
              excludeSemantics: true,
              child: CustomPaint(
                painter: _MoodLinePainter(
                  moods: moods,
                  cellW: cellW,
                  lineColor: colors.gold,
                  gridColor: colors.border,
                  labelColor: colors.textDim,
                  todayIndex: todayIndex,
                ),
              ),
            )
          : Align(
              alignment: Alignment.centerLeft,
              child: Padding(
                padding: const EdgeInsets.only(left: 8),
                child: Text(
                  Metin.buAyMoodYok,
                  style: TextStyle(fontSize: 12, color: colors.textDim),
                ),
              ),
            ),
    );
  }
}

class _MoodLinePainter extends CustomPainter {
  final List<int?> moods;
  final double cellW;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final int? todayIndex;

  _MoodLinePainter({
    required this.moods,
    required this.cellW,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.todayIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const top = 8.0;
    const bottom = 8.0;
    final plotH = size.height - top - bottom;

    double yFor(int mood) => top + plotH * (1 - (mood - 1) / 4);
    double xFor(int i) => i * cellW + cellW / 2;

    // Light horizontal guides for each mood level.
    final gridPaint = Paint()
      ..color = gridColor.withValues(alpha: 0.55)
      ..strokeWidth = 1;
    for (var m = 1; m <= 5; m++) {
      final y = yFor(m);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Today marker.
    if (todayIndex != null && todayIndex! < moods.length) {
      final x = xFor(todayIndex!);
      canvas.drawLine(
        Offset(x, top - 4),
        Offset(x, top + plotH + 4),
        Paint()
          ..color = lineColor.withValues(alpha: 0.35)
          ..strokeWidth = 1.5,
      );
    }

    // Connect consecutive recorded days; break the line over gaps.
    final linePaint = Paint()
      ..color = lineColor
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;
    final path = Path();
    bool penDown = false;
    for (var i = 0; i < moods.length; i++) {
      final mood = moods[i];
      if (mood == null) {
        penDown = false;
        continue;
      }
      final p = Offset(xFor(i), yFor(mood));
      if (penDown) {
        path.lineTo(p.dx, p.dy);
      } else {
        path.moveTo(p.dx, p.dy);
        penDown = true;
      }
    }
    canvas.drawPath(path, linePaint);

    final dotPaint = Paint()..color = lineColor;
    for (var i = 0; i < moods.length; i++) {
      final mood = moods[i];
      if (mood == null) continue;
      canvas.drawCircle(Offset(xFor(i), yFor(mood)), 3.2, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodLinePainter old) =>
      old.moods != moods ||
      old.lineColor != lineColor ||
      old.gridColor != gridColor ||
      old.todayIndex != todayIndex;
}

class _EmptyState extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyState({required this.onAdd});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.grid_view_rounded, size: 64, color: colors.textDim),
            const SizedBox(height: 16),
            const Text(
              Metin.alsizBaslik,
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 6),
            Text(
              Metin.alsizAciklama,
              textAlign: TextAlign.center,
              style: TextStyle(color: colors.textDim),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text(Metin.alisanlikEkle),
            ),
          ],
        ),
      ),
    );
  }
}
