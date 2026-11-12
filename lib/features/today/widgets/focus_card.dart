import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/enums.dart';
import '../../../core/sessions.dart';
import '../../../data/providers.dart';
import '../../../shared/theme.dart';
import '../../../ui_metin.dart';
import '../focus_controller.dart';

/// Pomodoro timer + this week's focus totals. The timer itself is a
/// [FocusController]; this card only draws it and forwards start/stop.
class FocusCard extends ConsumerStatefulWidget {
  const FocusCard({super.key});

  @override
  ConsumerState<FocusCard> createState() => _FocusCardState();
}

class _FocusCardState extends ConsumerState<FocusCard> with AutomaticKeepAliveClientMixin {
  static const _presets = <int>[25, 45, 15]; // minutes

  // Scrolled off screen in the Bugün list: keep the chosen length and the results subscription.
  @override
  bool get wantKeepAlive => true;

  int _planned = 25;
  StreamSubscription<FocusResult>? _sub;

  SessionKind get _kind =>
      _planned <= 15 ? SessionKind.rest : SessionKind.focus;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(focusControllerProvider).results.listen(_onResult);
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  void _onResult(FocusResult r) {
    if (!mounted) return;
    final String? message;
    if (r.saved && r.completed) {
      message = Metin.seansBitti(r.kind.label, formatDuration(r.durationS));
    } else if (!r.saved && !r.completed) {
      message = Metin.kisaSeans;
    } else {
      message = null;
    }
    if (message == null) return;
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(
        SnackBar(duration: const Duration(seconds: 3), content: Text(message)),
      );
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final colors = AppColors.of(context);
    final controller = ref.watch(focusControllerProvider);
    final summary = ref.watch(focusSummaryProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: ValueListenableBuilder<FocusState>(
          valueListenable: controller.state,
          builder: (context, s, _) {
            final total = (s.running ? s.plannedMinutes : _planned) * 60;
            final remaining = s.running ? s.remainingSeconds : total;
            final progress = s.running ? 1 - remaining / total : 0.0;
            final kind = s.running ? s.kind : _kind;

            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Icon(Icons.timer_outlined, size: 18, color: colors.textDim),
                    const SizedBox(width: 8),
                    Text(
                      Metin.odak,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: colors.textDim,
                      ),
                    ),
                    const Spacer(),
                    if (summary.dayStreak > 1)
                      Text(
                        Metin.gunUstUste(summary.dayStreak),
                        style: TextStyle(fontSize: 12, color: colors.textDim),
                      ),
                  ],
                ),
                const SizedBox(height: 14),
                Semantics(
      container: true,
                  label: Metin.kalanSure(formatClock(remaining)),
                  excludeSemantics: true,
                  child: Center(
                    child: Text(
                      formatClock(remaining),
                      style: kTabularNums.copyWith(
                        fontSize: 44,
                        fontWeight: FontWeight.w700,
                        height: 1,
                        color: s.running ? colors.done : colors.text,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 6,
                    color: kind == SessionKind.focus
                        ? colors.done
                        : colors.gold,
                    backgroundColor: colors.idle,
                  ),
                ),
                const SizedBox(height: 14),
                if (!s.running) ...[
                  Row(
                    children: [
                      for (final m in _presets) ...[
                        Expanded(
                          child: _PresetChip(
                            label: Metin.dakika(m),
                            selected: _planned == m,
                            onTap: () => setState(() => _planned = m),
                          ),
                        ),
                        if (m != _presets.last) const SizedBox(width: 8),
                      ],
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        controller.start(kind: _kind, plannedMinutes: _planned),
                    icon: const Icon(Icons.play_arrow_rounded, size: 22),
                    label: Text(Metin.baslat(_kind.label)),
                  ),
                ] else
                  OutlinedButton.icon(
                    onPressed: controller.stop,
                    icon: const Icon(Icons.stop_rounded, size: 20),
                    label: const Text(Metin.bitir),
                  ),
                const SizedBox(height: 14),
                Divider(height: 1, color: colors.border),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: _Stat(
                        label: Metin.odakBugun,
                        value: formatDuration(summary.todaySeconds),
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: Metin.odakSon7,
                        value: formatDuration(summary.last7Seconds),
                      ),
                    ),
                    Expanded(
                      child: _Stat(
                        label: Metin.odakSeans,
                        value: '${summary.last7Sessions}',
                      ),
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _PresetChip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _PresetChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      excludeSemantics: true,
      onTap: onTap,
      child: Material(
        color: selected ? colors.surfaceAlt : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: onTap,
          child: Container(
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: selected ? colors.done : colors.border),
            ),
            child: Text(
              label,
              style: kTabularNums.copyWith(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: selected ? colors.text : colors.textDim,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  final String label;
  final String value;
  const _Stat({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 12, color: colors.textDim)),
        const SizedBox(height: 2),
        Text(
          value,
          style: kTabularNums.copyWith(
            fontSize: 16,
            fontWeight: FontWeight.w700,
            color: colors.text,
          ),
        ),
      ],
    );
  }
}
