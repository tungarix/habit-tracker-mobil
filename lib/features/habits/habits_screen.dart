import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../shared/widgets/habit_avatar.dart';
import '../settings/ui_metin_b.dart';
import 'habit_edit_dialog.dart';

/// Manage habits: create, edit, archive, restore, delete.
class HabitsScreen extends ConsumerWidget {
  const HabitsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAsync = ref.watch(activeHabitsProvider);
    final archivedAsync = ref.watch(archivedHabitsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text(MetinB.alisanliklariYonet)),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => HabitEditDialog.show(context),
        icon: const Icon(Icons.add),
        label: const Text(MetinB.alisanlikFab),
      ),
      body: SafeArea(
        child: activeAsync.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text(MetinB.hata('$e'))),
          data: (active) {
            final archived = archivedAsync.value ?? const <Habit>[];
            return CustomScrollView(
              slivers: [
                if (active.isEmpty)
                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.all(24),
                      child: Center(child: Text(MetinB.aktifYok)),
                    ),
                  ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 0),
                  sliver: SliverReorderableList(
                    itemCount: active.length,
                    onReorderItem: (oldIndex, newIndex) {
                      final reordered = [...active];
                      final moved = reordered.removeAt(oldIndex);
                      reordered.insert(newIndex, moved);
                      ref
                          .read(habitRepositoryProvider)
                          .reorderHabits(reordered.map((h) => h.id).toList());
                    },
                    itemBuilder: (context, index) {
                      final h = active[index];
                      return _ActiveHabitTile(
                        key: ValueKey(h.id),
                        habit: h,
                        index: index,
                      );
                    },
                  ),
                ),
                if (archived.isNotEmpty) ...[
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                      child: Semantics(
                        header: true,
                        child: const Text(
                          MetinB.arsiv,
                          style: TextStyle(fontWeight: FontWeight.bold),
                        ),
                      ),
                    ),
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(12, 0, 12, 0),
                    sliver: SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) =>
                            _ArchivedHabitTile(habit: archived[index]),
                        childCount: archived.length,
                      ),
                    ),
                  ),
                ],
                const SliverToBoxAdapter(child: SizedBox(height: 96)),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _ActiveHabitTile extends ConsumerWidget {
  final Habit habit;
  final int index;

  const _ActiveHabitTile({
    required super.key,
    required this.habit,
    required this.index,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(habitRepositoryProvider);
    final days = parseWeekdays(habit.scheduledWeekdays);
    final schedule = days.isEmpty
        ? MetinB.herGun
        : days.map((d) => kWeekdayShort[d - 1]).join(' · ');
    final category = HabitCategory.tryParse(habit.category);
    final subtitle = category == null
        ? schedule
        : '${category.label} · $schedule';

    return Card(
      child: ListTile(
        onTap: () => HabitEditDialog.show(context, existing: habit),
        leading: ExcludeSemantics(child: HabitAvatar(habit: habit)),
        title: Text(
          habit.name,
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
        subtitle: Text(subtitle),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // 48dp drag handle; TalkBack users reorder with the list's own
            // "move up / move down" actions instead.
            ReorderableDragStartListener(
              index: index,
              child: const SizedBox(
                width: 48,
                height: 48,
                child: ExcludeSemantics(child: Icon(Icons.drag_handle)),
              ),
            ),
            PopupMenuButton<String>(
              tooltip: MetinB.menuAc(habit.name),
              onSelected: (value) {
                switch (value) {
                  case 'edit':
                    HabitEditDialog.show(context, existing: habit);
                  case 'archive':
                    repo.archive(habit.id);
                  case 'delete':
                    confirmDeleteHabit(context, ref, habit, offerArchive: true);
                }
              },
              itemBuilder: (_) => const [
                PopupMenuItem(value: 'edit', child: Text(MetinB.duzenle)),
                PopupMenuItem(value: 'archive', child: Text(MetinB.arsivle)),
                PopupMenuItem(value: 'delete', child: Text(MetinB.silNokta)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ArchivedHabitTile extends ConsumerWidget {
  final Habit habit;
  const _ArchivedHabitTile({required this.habit});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.read(habitRepositoryProvider);
    return Card(
      child: Opacity(
        opacity: 0.7,
        child: ListTile(
          leading: ExcludeSemantics(child: HabitAvatar(habit: habit, size: 36)),
          title: Text(habit.name),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: MetinB.geriYukle,
                icon: const Icon(Icons.unarchive_outlined),
                onPressed: () => repo.unarchive(habit.id),
              ),
              IconButton(
                tooltip: MetinB.sil,
                icon: const Icon(Icons.delete_outline),
                onPressed: () => confirmDeleteHabit(context, ref, habit),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Permanently deletes [habit] (and every mark on it) after a confirmation.
///
/// From the active list ([offerArchive]) the dialog points at "Arşivle" as the
/// reversible alternative — deleting also wipes the streak and history.
Future<void> confirmDeleteHabit(
  BuildContext context,
  WidgetRef ref,
  Habit habit, {
  bool offerArchive = false,
}) async {
  final repo = ref.read(habitRepositoryProvider);
  final ok = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text(MetinB.kaliciSilBaslik),
      content: Text(MetinB.kaliciSilAciklama(habit.name, offerArchive)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text(MetinB.iptal),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: Theme.of(dialogContext).colorScheme.error,
            foregroundColor: Theme.of(dialogContext).colorScheme.onError,
          ),
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text(MetinB.sil),
        ),
      ],
    ),
  );
  if (ok == true) await repo.delete(habit.id);
}
