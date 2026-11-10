import 'package:flutter/material.dart';

import '../../../core/date_utils.dart';
import '../../../core/enums.dart';
import '../../../core/stats.dart';
import '../../../shared/theme.dart';
import '../../../ui_metin.dart';

/// 30-day heat strip, laid out as two rows of 15 so cells stay readable on a
/// phone (one row of 30 would shrink to ~8 px). Oldest day first, newest last.
/// Colour carries the data: the habit's own hue, fuller day = stronger.
class HeatStrip extends StatelessWidget {
  final String habitName;
  final List<HeatPoint> points;
  final DateTime endDay;
  final Color color;

  static const _perRow = 15;
  static const _gap = 4.0;

  const HeatStrip({
    super.key,
    required this.habitName,
    required this.points,
    required this.endDay,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final colors = AppColors.of(context);
    final days = lastDays(endDay, points.length);

    return LayoutBuilder(
      builder: (context, c) {
        final size = ((c.maxWidth - _gap * (_perRow - 1)) / _perRow).clamp(
          8.0,
          24.0,
        );
        Widget row(int from, int to) => Row(
          children: [
            for (var i = from; i < to && i < points.length; i++) ...[
              if (i > from) const SizedBox(width: _gap),
              _Cell(
                habitName: habitName,
                point: points[i],
                day: days[i],
                color: color,
                colors: colors,
                size: size,
              ),
            ],
          ],
        );
        return Column(
          children: [
            row(0, _perRow),
            if (points.length > _perRow) ...[
              const SizedBox(height: _gap),
              row(_perRow, points.length),
            ],
          ],
        );
      },
    );
  }
}

class _Cell extends StatelessWidget {
  final String habitName;
  final HeatPoint point;
  final DateTime day;
  final Color color;
  final AppColors colors;
  final double size;

  const _Cell({
    required this.habitName,
    required this.point,
    required this.day,
    required this.color,
    required this.colors,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    final (fill, label) = switch (point.cell) {
      // 0.35..1.0 keeps even a barely-started day visible against the surface.
      HeatCell.done => (
        color.withValues(alpha: 0.35 + 0.65 * point.intensity),
        Metin.durum(EntryStatus.done),
      ),
      HeatCell.missed when point.intensity > 0 => (
        color.withValues(alpha: 0.15 + 0.30 * point.intensity),
        Metin.isiKismi,
      ),
      HeatCell.missed => (
        colors.missed.withValues(alpha: 0.30),
        Metin.durum(EntryStatus.missed),
      ),
      HeatCell.skipped => (
        colors.skipped.withValues(alpha: 0.30),
        Metin.durum(EntryStatus.skipped),
      ),
      HeatCell.inactive => (
        colors.idle.withValues(alpha: 0.6),
        Metin.durum(null),
      ),
    };

    return Semantics(
      container: true,
      label: Metin.hucre(habitName, day, label),
      excludeSemantics: true,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(size * 0.25),
        ),
      ),
    );
  }
}
