import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/enums.dart';
import '../../../core/tasks.dart';
import '../../../data/database/database.dart';
import '../../../data/providers.dart';
import '../../../shared/theme.dart';
import '../../../ui_metin.dart';

/// One task line: checkbox, title, priority mark, due label (>= 48 dp tall).
/// Tap toggles done, long press edits. Used by the Bugün block and Görevler.
class TaskRow extends ConsumerWidget {
  final Task task;
  final VoidCallback? onEdit;

  const TaskRow({super.key, required this.task, this.onEdit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final day = ref.watch(todayProvider);
    final status = TaskStatus.fromStorage(task.status);
    final priority = TaskPriority.fromValue(task.priority);
    final bucket = bucketFor(task, day);
    final isDone = status == TaskStatus.done;
    final due = (task.dueDay != null && !isDone)
        ? _dueLabel(bucket, task.dueDay!, day)
        : null;

    final dueColor = switch (bucket) {
      DueBucket.overdue => colors.missed,
      DueBucket.today => colors.done,
      _ => colors.textDim,
    };

    final spoken = [
      task.title,
      isDone ? Metin.gorevBitti : Metin.gorevAcikDurum,
      if (status == TaskStatus.doing) Metin.yapiliyor,
      if (priority == TaskPriority.high && !isDone) Metin.yuksekOncelik,
      ?due,
    ].join(', ');

    void toggle() => ref.read(taskRepositoryProvider).toggleDone(task);

    return Semantics(
      container: true,
      button: true,
      checked: isDone,
      label: spoken,
      hint: Metin.gorevDuzenleIpucu,
      excludeSemantics: true,
      onTap: toggle,
      onLongPress: onEdit,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: toggle,
          onLongPress: onEdit,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 48),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 6),
              child: Row(
                children: [
                  _Checkbox(done: isDone, colors: colors),
                  const SizedBox(width: 12),
                  if (priority == TaskPriority.high && !isDone) ...[
                    Container(
                      width: 6,
                      height: 6,
                      decoration: BoxDecoration(
                        color: colors.missed,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Expanded(
                    child: Text(
                      task.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: status == TaskStatus.doing
                            ? FontWeight.w700
                            : null,
                        color: isDone ? colors.textDim : colors.text,
                        decoration: isDone ? TextDecoration.lineThrough : null,
                        decorationColor: colors.textDim,
                      ),
                    ),
                  ),
                  if (status == TaskStatus.doing) ...[
                    const SizedBox(width: 6),
                    Icon(Icons.bolt, size: 18, color: colors.gold),
                  ],
                  if (due != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      due,
                      style: kTabularNums.copyWith(
                        fontSize: 12,
                        color: dueColor,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static String _dueLabel(DueBucket bucket, String dueDay, DateTime today) {
    switch (bucket) {
      case DueBucket.today:
        return Metin.vadeBugun;
      case DueBucket.tomorrow:
        return Metin.vadeYarin;
      case DueBucket.overdue:
        return Metin.vadeGecti(calendarDaysBetween(parseYmd(dueDay), today));
      default:
        final d = parseYmd(dueDay);
        return '${d.day}.${d.month}';
    }
  }
}

class _Checkbox extends StatelessWidget {
  final bool done;
  final AppColors colors;
  const _Checkbox({required this.done, required this.colors});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 150),
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        color: done ? colors.done : Colors.transparent,
        border: Border.all(
          color: done ? colors.done : colors.textDim,
          width: 2,
        ),
        borderRadius: BorderRadius.circular(6),
      ),
      child: done
          // Dark fill is light green: a dark tick keeps the 3:1 graphic contrast.
          ? Icon(
              Icons.check,
              size: 16,
              color: Theme.of(context).brightness == Brightness.dark
                  ? colors.bg
                  : Colors.white,
            )
          : null,
    );
  }
}
