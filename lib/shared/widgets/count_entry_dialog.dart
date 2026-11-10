import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../data/database/database.dart';
import '../../ui_metin.dart';
import '../theme.dart';

/// Amount entry for a count habit ("10 bin adım", "Derin çalışma 90 dk").
///
/// Returns the entered amount, or null if cancelled. 0 clears the day.
class CountEntryDialog extends StatefulWidget {
  final Habit habit;
  final int current;

  const CountEntryDialog({
    super.key,
    required this.habit,
    required this.current,
  });

  static Future<int?> show(
    BuildContext context, {
    required Habit habit,
    required int current,
  }) {
    return showDialog<int>(
      context: context,
      builder: (_) => CountEntryDialog(habit: habit, current: current),
    );
  }

  @override
  State<CountEntryDialog> createState() => _CountEntryDialogState();
}

class _CountEntryDialogState extends State<CountEntryDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.current > 0 ? '${widget.current}' : '',
  );

  int get _amount => int.tryParse(_controller.text.trim()) ?? 0;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() => Navigator.of(context).pop(_amount);

  /// Quick nudges sized to the target, so 10 000 steps does not need typing.
  List<int> get _steps {
    final target = widget.habit.target;
    final step = target >= 1000
        ? (target / 10).round()
        : target >= 100
        ? 25
        : target >= 20
        ? 10
        : 1;
    return [step, target];
  }

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final target = widget.habit.target;
    final ratio = target == 0 ? 0.0 : (_amount / target).clamp(0.0, 1.0);

    return AlertDialog(
      title: Text(widget.habit.name),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              Metin.gunlukHedef(target),
              style: TextStyle(fontSize: 12, color: colors.textDim),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _controller,
              autofocus: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              textInputAction: TextInputAction.done,
              onChanged: (_) => setState(() {}),
              onSubmitted: (_) => _submit(),
              style: kTabularNums.copyWith(fontSize: 22),
              decoration: const InputDecoration(
                labelText: Metin.bugunkuMiktar,
                helperText: Metin.sifirIpucu,
              ),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: ratio,
                minHeight: 6,
                color: Color(widget.habit.colorValue),
                backgroundColor: colors.idle,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              ratio >= 1 ? Metin.hedefTamam : '%${(ratio * 100).round()}',
              style: kTabularNums.copyWith(
                fontSize: 12,
                color: ratio >= 1 ? colors.done : colors.textDim,
              ),
            ),
            const SizedBox(height: 14),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final step in _steps)
                  OutlinedButton(
                    onPressed: () {
                      _controller.text = '${_amount + step}';
                      setState(() {});
                    },
                    child: Text('+$step'),
                  ),
                OutlinedButton(
                  onPressed: () {
                    _controller.text = '$target';
                    setState(() {});
                  },
                  child: const Text(Metin.hedefDugme),
                ),
              ],
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(Metin.iptal),
        ),
        FilledButton(onPressed: _submit, child: const Text(Metin.kaydet)),
      ],
    );
  }
}
