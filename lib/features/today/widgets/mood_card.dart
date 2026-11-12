import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/date_utils.dart';
import '../../../core/enums.dart';
import '../../../data/database/database.dart';
import '../../../data/providers.dart';
import '../../../shared/onay.dart';
import '../../../shared/theme.dart';
import '../../../ui_metin.dart';

/// Mood: one tap for today, 30-day line underneath.
class MoodCard extends ConsumerWidget {
  const MoodCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final day = ref.watch(todayProvider);
    final entry = ref.watch(todayMoodProvider);
    final selected = Mood.fromValue(entry?.mood);
    final moodByDate = ref.watch(moodByDateProvider);
    final colors = AppColors.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(Icons.mood_outlined, size: 18, color: colors.textDim),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    selected?.label ?? Metin.moodSoru,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: colors.textDim,
                    ),
                  ),
                ),
                if (selected != null)
                  IconButton(
                    tooltip: Metin.notTooltip,
                    icon: Icon(
                      (entry?.note?.isNotEmpty ?? false)
                          ? Icons.sticky_note_2_outlined
                          : Icons.edit_note,
                      color: colors.textDim,
                    ),
                    onPressed: () =>
                        _editNote(context, ref, formatYmd(day), entry?.note),
                  )
                else
                  const SizedBox(height: 48),
              ],
            ),
            MoodPicker(
              selected: selected,
              onTap: (mood) async {
                final repo = ref.read(habitRepositoryProvider);
                final dateStr = formatYmd(day);
                if (mood != selected) {
                  repo.setMood(dateStr, mood.value);
                  return;
                }
                // Aynı ruh haline tekrar dokunmak kaydı ve günün notunu siler: not varsa sor.
                if (entry?.note?.isNotEmpty ?? false) {
                  final ok = await onayIste(
                    context,
                    Metin.moodSilBaslik,
                    Metin.moodSilGovde,
                  );
                  if (!ok) return;
                }
                repo.clearMood(dateStr);
              },
            ),
            if (entry?.note?.isNotEmpty ?? false) ...[
              const SizedBox(height: 8),
              Text(
                entry!.note!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontStyle: FontStyle.italic,
                  color: colors.textDim,
                ),
              ),
            ],
            const SizedBox(height: 10),
            MoodStrip(moodByDate: moodByDate, endDay: day),
          ],
        ),
      ),
    );
  }

  Future<void> _editNote(
    BuildContext context,
    WidgetRef ref,
    String dateStr,
    String? current,
  ) async {
    final result = await showDialog<String>(
      context: context,
      builder: (context) => _NotDiyalogu(baslangic: current ?? ''),
    );
    if (result != null) {
      final trimmed = result.trim();
      await ref
          .read(habitRepositoryProvider)
          .setMoodNote(dateStr, trimmed.isEmpty ? null : trimmed);
    }
  }
}

/// Owns its controller: disposing it right after showDialog returns would run while the route is
/// still animating out, with the TextField still listening.
class _NotDiyalogu extends StatefulWidget {
  const _NotDiyalogu({required this.baslangic});
  final String baslangic;

  @override
  State<_NotDiyalogu> createState() => _NotDiyaloguState();
}

class _NotDiyaloguState extends State<_NotDiyalogu> {
  late final controller = TextEditingController(text: widget.baslangic);

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text(Metin.notBaslik),
    content: TextField(
      controller: controller,
      autofocus: true,
      maxLength: 200,
      decoration: const InputDecoration(hintText: Metin.notIpucu),
      onSubmitted: (v) => Navigator.pop(context, v),
    ),
    actions: [
      TextButton(onPressed: () => Navigator.pop(context), child: const Text(Metin.iptal)),
      FilledButton(onPressed: () => Navigator.pop(context, controller.text), child: const Text(Metin.kaydet)),
    ],
  );
}

/// Compact 30-day mood line. Small on purpose: with no history it must not
/// dominate the screen.
class MoodStrip extends StatelessWidget {
  final Map<String, MoodEntry> moodByDate;
  final DateTime endDay;
  final int days;
  final double height;

  const MoodStrip({
    super.key,
    required this.moodByDate,
    required this.endDay,
    this.days = 30,
    this.height = 60,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final series = [
      for (final day in lastDays(endDay, days))
        moodByDate[formatYmd(day)]?.mood,
    ];
    final recorded = series.where((m) => m != null).length;

    if (recorded == 0) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            Metin.moodYok,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: colors.textDim),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      label: Metin.moodCizgi(recorded),
      image: true,
      child: SizedBox(
        height: height,
        child: CustomPaint(
          size: Size.infinite,
          painter: _MoodStripPainter(
            series: series,
            line: colors.gold,
            grid: colors.border,
          ),
        ),
      ),
    );
  }
}

class _MoodStripPainter extends CustomPainter {
  final List<int?> series;
  final Color line;
  final Color grid;

  _MoodStripPainter({
    required this.series,
    required this.line,
    required this.grid,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const pad = 6.0;
    final plotH = size.height - pad * 2;
    final n = series.length;
    if (n == 0) return;

    double xAt(int i) => n == 1 ? size.width / 2 : size.width * (i / (n - 1));
    double yAt(int mood) => pad + plotH * (1 - (mood - 1) / 4);

    // Faint rails at the extremes only: enough to read height, no clutter.
    final gridPaint = Paint()
      ..color = grid.withValues(alpha: 0.5)
      ..strokeWidth = 1;
    for (final mood in [1, 5]) {
      final y = yAt(mood);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    final stroke = Paint()
      ..color = line
      ..strokeWidth = 1.8
      ..style = PaintingStyle.stroke
      ..strokeJoin = StrokeJoin.round;

    // Gaps break the line: absent days are not interpolated into a story.
    final path = Path();
    var penDown = false;
    for (var i = 0; i < n; i++) {
      final mood = series[i];
      if (mood == null) {
        penDown = false;
        continue;
      }
      final p = Offset(xAt(i), yAt(mood));
      penDown ? path.lineTo(p.dx, p.dy) : path.moveTo(p.dx, p.dy);
      penDown = true;
    }
    canvas.drawPath(path, stroke);

    final dot = Paint()..color = line;
    for (var i = 0; i < n; i++) {
      final mood = series[i];
      if (mood == null) continue;
      canvas.drawCircle(Offset(xAt(i), yAt(mood)), 2.4, dot);
    }
  }

  @override
  bool shouldRepaint(covariant _MoodStripPainter old) =>
      old.series != series || old.line != line || old.grid != grid;
}

/// Five one-tap mood buttons (48 dp). Tapping the selected one clears it.
class MoodPicker extends StatelessWidget {
  final Mood? selected;
  final ValueChanged<Mood> onTap;

  const MoodPicker({super.key, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    return Row(
      children: [
        for (final mood in Mood.values) ...[
          Expanded(
            child: Semantics(
      container: true,
              button: true,
              selected: mood == selected,
              label: mood.label,
              excludeSemantics: true,
              onTap: () => onTap(mood),
              child: Material(
                color: mood == selected
                    ? colors.surfaceAlt
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () => onTap(mood),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 140),
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: mood == selected
                            ? colors.done
                            : Colors.transparent,
                        width: 2,
                      ),
                    ),
                    child: Center(
                      child: AnimatedScale(
                        duration: const Duration(milliseconds: 160),
                        curve: Curves.easeOutBack,
                        scale: mood == selected ? 1.2 : 1,
                        child: Icon(
                          mood.icon,
                          size: 24,
                          color: mood == selected
                              ? colors.text
                              : colors.textDim,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (mood != Mood.values.last) const SizedBox(width: 4),
        ],
      ],
    );
  }
}
