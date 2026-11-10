import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../core/date_utils.dart';
import '../core/enums.dart';
import '../core/streak.dart';
import '../data/database/database.dart';
import '../data/providers.dart';
import '../ui_metin.dart';
import 'widgets/count_entry_dialog.dart';

/// Tap: ✓ → ✗ → – → boş for every habit kind (PLAN). Count habits get their
/// amount through [enterHabitAmount] on long press instead.
Future<void> cycleHabit(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime day,
) async {
  final dateStr = formatYmd(day);
  final next = await ref.read(habitRepositoryProvider).cycle(habit.id, dateStr);
  if (next == EntryStatus.done && context.mounted) {
    _celebrateMilestone(context, ref, habit, day, dateStr);
  }
}

/// Long press on a count habit: amount entry. Cancelling changes nothing.
Future<void> enterHabitAmount(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime day, {
  required int currentValue,
}) async {
  final amount = await CountEntryDialog.show(
    context,
    habit: habit,
    current: currentValue,
  );
  if (amount == null) return;
  await ref
      .read(habitRepositoryProvider)
      .setAmount(habit.id, formatYmd(day), amount, habit.target);
}

/// True for habits that record an amount against a daily target.
bool isCountHabit(Habit habit) =>
    habit.kind == HabitKind.count.storageName && habit.target > 1;

/// Quiet milestone note every 7th day of a streak: a nod, not confetti.
void _celebrateMilestone(
  BuildContext context,
  WidgetRef ref,
  Habit habit,
  DateTime day,
  String dateStr,
) {
  final statuses = {
    ...ref.read(habitStatusesProvider(habit.id)),
    dateStr: EntryStatus.done,
  };
  final streak = computeStreaks(
    habit,
    statuses,
    day,
    dayStartHour: ref.read(dayStartHourProvider),
  ).current;
  if (streak <= 0 || streak % 7 != 0) return;

  ScaffoldMessenger.of(context)
    ..clearSnackBars()
    ..showSnackBar(
      SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(Metin.seriNotu(habit.name, streak)),
      ),
    );
}
