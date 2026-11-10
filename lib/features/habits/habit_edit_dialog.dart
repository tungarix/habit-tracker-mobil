import 'package:drift/drift.dart' show Value;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/constants.dart';
import '../../core/date_utils.dart';
import '../../core/enums.dart';
import '../../data/database/database.dart';
import '../../data/providers.dart';
import '../../shared/habit_style.dart';
import '../../ui_metin.dart';

/// Add / edit a habit. Pass [existing] to edit, leave null to create.
class HabitEditDialog extends ConsumerStatefulWidget {
  final Habit? existing;
  const HabitEditDialog({super.key, this.existing});

  static Future<void> show(BuildContext context, {Habit? existing}) {
    return showDialog<void>(
      context: context,
      builder: (_) => HabitEditDialog(existing: existing),
    );
  }

  @override
  ConsumerState<HabitEditDialog> createState() => _HabitEditDialogState();
}

class _HabitEditDialogState extends ConsumerState<HabitEditDialog> {
  late final TextEditingController _name;
  late final TextEditingController _desc;
  late int _colorValue;
  late int _iconCodePoint;
  late String _category; // HabitCategory.name; '' = none (legacy)
  late String _kind; // HabitKind.storageName
  late final TextEditingController _target;
  late Set<int> _weekdays; // empty = every day

  bool get _isCount => _kind == HabitKind.count.storageName;

  bool get _isEdit => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _name = TextEditingController(text: e?.name ?? '');
    _desc = TextEditingController(text: e?.description ?? '');
    _colorValue = e?.colorValue ?? kHabitColors.first.toARGB32();
    _iconCodePoint = e?.iconCodePoint ?? kHabitIcons.first.codePoint;
    _category = e?.category ?? HabitCategory.beden.name;
    _kind = e?.kind ?? HabitKind.bool_.storageName;
    _target = TextEditingController(text: '${e?.target ?? 1}');
    _weekdays = e == null
        ? <int>{}
        : parseWeekdays(e.scheduledWeekdays).toSet();
  }

  @override
  void dispose() {
    _name.dispose();
    _desc.dispose();
    _target.dispose();
    super.dispose();
  }

  /// Daily target: only meaningful for count habits, always 1 for bool ones.
  int get _targetValue {
    if (!_isCount) return 1;
    final parsed = int.tryParse(_target.text.trim());
    if (parsed == null || parsed < 1) return 1;
    return parsed;
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) return;
    final repo = ref.read(habitRepositoryProvider);
    final desc = _desc.text.trim().isEmpty ? null : _desc.text.trim();
    final weekdays = weekdaysToString(_weekdays);

    if (_isEdit) {
      await repo.updateHabit(
        widget.existing!.copyWith(
          name: name,
          description: Value(desc),
          colorValue: _colorValue,
          iconCodePoint: _iconCodePoint,
          category: _category,
          kind: _kind,
          target: _targetValue,
          scheduledWeekdays: weekdays,
        ),
      );
    } else {
      await repo.createHabit(
        name: name,
        description: desc,
        colorValue: _colorValue,
        iconCodePoint: _iconCodePoint,
        category: _category,
        kind: _kind,
        target: _targetValue,
        scheduledWeekdays: weekdays,
      );
    }
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final dim = Theme.of(context).colorScheme.onSurfaceVariant;
    return AlertDialog(
      title: Text(_isEdit ? Metin.alisanligiDuzenle : Metin.yeniAlisanlik),
      content: SizedBox(
        width: 380,
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _name,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: Metin.ad,
                  hintText: Metin.adIpucu,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _desc,
                decoration: const InputDecoration(labelText: Metin.aciklama),
              ),
              const SizedBox(height: 20),
              const _SectionLabel(Metin.tur),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final k in HabitKind.values)
                    ChoiceChip(
                      label: Text(k.label),
                      selected: _kind == k.storageName,
                      onSelected: (_) => setState(() => _kind = k.storageName),
                    ),
                ],
              ),
              if (_isCount) ...[
                const SizedBox(height: 12),
                TextField(
                  controller: _target,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: Metin.gunlukHedefAlan,
                    hintText: Metin.gunlukHedefIpucu,
                    helperText: Metin.gunlukHedefYardim,
                    helperMaxLines: 2,
                  ),
                ),
              ],
              const SizedBox(height: 20),
              const _SectionLabel(Metin.kategori),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: [
                  for (final c in HabitCategory.values)
                    ChoiceChip(
                      label: Text(c.label),
                      selected: _category == c.name,
                      onSelected: (_) => setState(() => _category = c.name),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              const _SectionLabel(Metin.renk),
              const SizedBox(height: 4),
              _ColorPicker(
                selected: _colorValue,
                onSelected: (c) => setState(() => _colorValue = c),
              ),
              const SizedBox(height: 20),
              const _SectionLabel(Metin.ikon),
              const SizedBox(height: 4),
              _IconPicker(
                selectedCodePoint: _iconCodePoint,
                color: Color(_colorValue),
                onSelected: (cp) => setState(() => _iconCodePoint = cp),
              ),
              const SizedBox(height: 20),
              const _SectionLabel(Metin.planliGunler),
              const SizedBox(height: 4),
              Text(
                _weekdays.isEmpty ? Metin.herGun : Metin.seciliGunlerde,
                style: TextStyle(color: dim, fontSize: 12),
              ),
              const SizedBox(height: 8),
              _WeekdayPicker(
                selected: _weekdays,
                onChanged: (s) => setState(() => _weekdays = s),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Metin.iptal),
        ),
        FilledButton(onPressed: _save, child: const Text(Metin.kaydet)),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);
  @override
  Widget build(BuildContext context) => Semantics(
    header: true,
    child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
  );
}

/// One 48dp tap target around a smaller visual swatch, with a spoken label
/// and selected state for TalkBack.
class _PickerCell extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Widget child;
  const _PickerCell({
    required this.label,
    required this.selected,
    required this.onTap,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: label,
      button: true,
      selected: selected,
      excludeSemantics: true,
      onTap: onTap,
      child: InkResponse(
        onTap: onTap,
        radius: 24,
        child: SizedBox(width: 48, height: 48, child: Center(child: child)),
      ),
    );
  }
}

class _ColorPicker extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelected;
  const _ColorPicker({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      children: [
        for (var i = 0; i < kHabitColors.length; i++)
          _PickerCell(
            label: Metin.renkAdi(i),
            selected: kHabitColors[i].toARGB32() == selected,
            onTap: () => onSelected(kHabitColors[i].toARGB32()),
            child: Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: kHabitColors[i],
                shape: BoxShape.circle,
                border: Border.all(
                  color: kHabitColors[i].toARGB32() == selected
                      ? Theme.of(context).colorScheme.onSurface
                      : Colors.transparent,
                  width: 3,
                ),
              ),
              child: kHabitColors[i].toARGB32() == selected
                  ? const Icon(Icons.check, color: Colors.white, size: 18)
                  : null,
            ),
          ),
      ],
    );
  }
}

class _IconPicker extends StatelessWidget {
  final int selectedCodePoint;
  final Color color;
  final ValueChanged<int> onSelected;
  const _IconPicker({
    required this.selectedCodePoint,
    required this.color,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Wrap(
      children: [
        for (var i = 0; i < kHabitIcons.length; i++)
          _PickerCell(
            label: Metin.ikonAdi(i),
            selected: kHabitIcons[i].codePoint == selectedCodePoint,
            onTap: () => onSelected(kHabitIcons[i].codePoint),
            child: Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: kHabitIcons[i].codePoint == selectedCodePoint
                    ? color.withValues(alpha: 0.2)
                    : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: kHabitIcons[i].codePoint == selectedCodePoint
                      ? color
                      : Colors.transparent,
                  width: 2,
                ),
              ),
              child: Icon(
                kHabitIcons[i],
                color: kHabitIcons[i].codePoint == selectedCodePoint
                    ? color
                    : scheme.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }
}

class _WeekdayPicker extends StatelessWidget {
  final Set<int> selected;
  final ValueChanged<Set<int>> onChanged;
  const _WeekdayPicker({required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (var day = 1; day <= 7; day++)
          FilterChip(
            label: Text(kWeekdayShort[day - 1]),
            selected: selected.contains(day),
            onSelected: (on) {
              final next = {...selected};
              if (on) {
                next.add(day);
              } else {
                next.remove(day);
              }
              onChanged(next);
            },
          ),
      ],
    );
  }
}
