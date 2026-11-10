import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../data/providers.dart';
import '../../../shared/theme.dart';
import '../../../ui_metin.dart';
import '../task_edit_dialog.dart';
import 'task_row.dart';

/// Bugün block: what is due this week, plus a one-line adder. Undated tasks
/// stay out: they are not a commitment for this week.
class WeekTasksCard extends ConsumerWidget {
  /// Opens the Görevler tab.
  final VoidCallback? onShowAll;
  const WeekTasksCard({super.key, this.onShowAll});

  static const _maxShown = 5;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final colors = AppColors.of(context);
    final tasks = ref.watch(thisWeekTasksProvider);
    final summary = ref.watch(taskSummaryProvider);
    final shown = tasks.take(_maxShown).toList();

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 6, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  Icons.checklist_rtl_outlined,
                  size: 18,
                  color: colors.textDim,
                ),
                const SizedBox(width: 8),
                Text(
                  Metin.haftaBaslik,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: colors.textDim,
                  ),
                ),
                const Spacer(),
                if (summary.doneToday > 0)
                  Text(
                    Metin.haftaBugunBitti(summary.doneToday),
                    style: TextStyle(fontSize: 12, color: colors.textDim),
                  ),
                if (onShowAll != null)
                  IconButton(
                    tooltip: Metin.tumGorevler,
                    icon: Icon(Icons.chevron_right, color: colors.textDim),
                    onPressed: onShowAll,
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
            if (shown.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  summary.open == 0
                      ? Metin.haftaGorevYok
                      : Metin.haftaDisi(summary.open),
                  style: TextStyle(fontSize: 12, color: colors.textDim),
                ),
              )
            else
              for (final t in shown)
                TaskRow(
                  task: t,
                  onEdit: () => TaskEditDialog.show(context, existing: t),
                ),
            if (tasks.length > _maxShown)
              Padding(
                padding: const EdgeInsets.only(left: 6, top: 4),
                child: Text(
                  Metin.dahaFazla(tasks.length - _maxShown),
                  style: TextStyle(fontSize: 12, color: colors.textDim),
                ),
              ),
            const SizedBox(height: 10),
            const _QuickAdd(),
          ],
        ),
      ),
    );
  }
}

/// Single-line adder: type, submit, keep going. Priority and due date live in
/// the edit dialog; a quick task is due today.
class _QuickAdd extends ConsumerStatefulWidget {
  const _QuickAdd();

  @override
  ConsumerState<_QuickAdd> createState() => _QuickAddState();
}

class _QuickAddState extends ConsumerState<_QuickAdd> {
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final title = _controller.text.trim();
    if (title.isEmpty) return;
    await ref
        .read(taskRepositoryProvider)
        .create(title: title, dueDay: formatYmd(ref.read(todayProvider)));
    _controller.clear();
    _focus.requestFocus(); // stay in the flow
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return TextField(
      controller: _controller,
      focusNode: _focus,
      textInputAction: TextInputAction.done,
      onSubmitted: (_) => _submit(),
      style: const TextStyle(fontSize: 16),
      decoration: InputDecoration(
        hintText: Metin.hizliEkleIpucu,
        hintStyle: TextStyle(fontSize: 14, color: colors.textDim),
        prefixIcon: Icon(Icons.add, color: colors.textDim),
        suffixIcon: IconButton(
          tooltip: Metin.hizliEkleEtiket,
          icon: const Icon(Icons.send_outlined),
          onPressed: _submit,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: colors.border),
        ),
      ),
    );
  }
}
