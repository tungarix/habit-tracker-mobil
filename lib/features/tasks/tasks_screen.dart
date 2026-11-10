import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/enums.dart';
import '../../core/tasks.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../shared/theme.dart';
import '../../ui_metin.dart';
import 'task_edit_dialog.dart';
import 'widgets/task_row.dart';

/// Full task list, grouped by urgency. One flat list per group: no boards, no
/// projects. Lives as the second bottom-navigation tab.
class TasksScreen extends ConsumerStatefulWidget {
  const TasksScreen({super.key});

  @override
  ConsumerState<TasksScreen> createState() => _TasksScreenState();
}

class _TasksScreenState extends ConsumerState<TasksScreen> {
  bool _showDone = false;

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final all = ref.watch(sortedTasksProvider);
    final day = ref.watch(todayProvider);
    final summary = ref.watch(taskSummaryProvider);

    final open = all
        .where((t) => TaskStatus.fromStorage(t.status) != TaskStatus.done)
        .toList();
    final done = all
        .where((t) => TaskStatus.fromStorage(t.status) == TaskStatus.done)
        .toList();

    final groups = <(String, List<Task>)>[
      (Metin.grupGeciken, _inBucket(open, day, DueBucket.overdue)),
      (Metin.grupBugun, _inBucket(open, day, DueBucket.today)),
      (Metin.grupYarin, _inBucket(open, day, DueBucket.tomorrow)),
      (Metin.grupBuHafta, _inBucket(open, day, DueBucket.thisWeek)),
      (Metin.grupSonra, _inBucket(open, day, DueBucket.later)),
      (Metin.grupTarihsiz, _inBucket(open, day, DueBucket.someday)),
    ];

    return Scaffold(
      appBar: AppBar(
        title: const Text(Metin.gorevlerBaslik),
        actions: [
          if (done.isNotEmpty)
            TextButton.icon(
              onPressed: () => setState(() => _showDone = !_showDone),
              icon: Icon(
                _showDone ? Icons.visibility_off : Icons.visibility,
                size: 18,
              ),
              label: Text(Metin.bitenler(done.length)),
            ),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => TaskEditDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text(Metin.gorevEkleKisa),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: [
          if (summary.open == 0 && done.isEmpty)
            Padding(
              padding: const EdgeInsets.only(top: 48),
              child: Column(
                children: [
                  Icon(
                    Icons.checklist_rtl_outlined,
                    size: 56,
                    color: colors.textDim,
                  ),
                  const SizedBox(height: 14),
                  const Text(
                    Metin.gorevYok,
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    Metin.ilkGorev,
                    textAlign: TextAlign.center,
                    style: TextStyle(color: colors.textDim),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: () => TaskEditDialog.show(context),
                    icon: const Icon(Icons.add),
                    label: const Text(Metin.gorevEkle),
                  ),
                ],
              ),
            ),
          for (final (title, items) in groups)
            if (items.isNotEmpty) ...[
              _GroupHeader(title: title, count: items.length),
              for (final t in items)
                TaskRow(
                  task: t,
                  onEdit: () => TaskEditDialog.show(context, existing: t),
                ),
              const SizedBox(height: 10),
            ],
          if (_showDone && done.isNotEmpty) ...[
            Row(
              children: [
                Expanded(
                  child: _GroupHeader(
                    title: Metin.grupBitenler,
                    count: done.length,
                  ),
                ),
                TextButton(
                  onPressed: () => _confirmClear(context),
                  child: Text(
                    Metin.temizle,
                    style: TextStyle(color: colors.missed),
                  ),
                ),
              ],
            ),
            for (final t in done)
              TaskRow(
                task: t,
                onEdit: () => TaskEditDialog.show(context, existing: t),
              ),
          ],
        ],
      ),
    );
  }

  static List<Task> _inBucket(List<Task> tasks, DateTime day, DueBucket b) =>
      tasks.where((t) => bucketFor(t, day) == b).toList();

  Future<void> _confirmClear(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text(Metin.temizleBaslik),
        content: const Text(Metin.temizleGovde),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text(Metin.iptal),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () => Navigator.pop(context, true),
            child: const Text(Metin.sil),
          ),
        ],
      ),
    );
    if (ok == true) {
      await ref.read(taskRepositoryProvider).clearDone();
    }
  }
}

class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  const _GroupHeader({required this.title, required this.count});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      header: true,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(6, 12, 6, 4),
        child: Row(
          children: [
            Text(
              title,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: colors.textDim,
              ),
            ),
            const SizedBox(width: 6),
            Text(
              '$count',
              style: kTabularNums.copyWith(fontSize: 12, color: colors.textDim),
            ),
          ],
        ),
      ),
    );
  }
}
