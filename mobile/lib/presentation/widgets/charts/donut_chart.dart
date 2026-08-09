import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import 'chart_data.dart';

/// Donut chart with a centred value and a legend.
///
/// Drawn with a [CustomPainter] rather than a charting package so the app has
/// no extra dependency to keep compatible across Flutter releases.
class DonutChart extends StatelessWidget {
  const DonutChart({
    super.key,
    required this.slices,
    this.centerValue,
    this.centerLabel,
    this.size = 132,
    this.strokeWidth = 18,
    this.showLegend = true,
  });

  final List<ChartSlice> slices;
  final String? centerValue;
  final String? centerLabel;
  final double size;
  final double strokeWidth;
  final bool showLegend;

  double get _total =>
      slices.fold<double>(0, (double sum, ChartSlice s) => sum + s.value);

  @override
  Widget build(BuildContext context) {
    final bool hasData = _total > 0;

    final Widget chart = SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _DonutPainter(
          slices: hasData ? slices : const <ChartSlice>[],
          strokeWidth: strokeWidth,
          trackColor: context.semantic.subtleBorder,
        ),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (centerValue != null)
                Text(
                  centerValue!,
                  style: context.text.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              if (centerLabel != null)
                Text(
                  centerLabel!,
                  textAlign: TextAlign.center,
                  style: context.text.labelSmall?.copyWith(
                    color: context.semantic.mutedText,
                  ),
                ),
            ],
          ),
        ),
      ),
    );

    if (!showLegend) return chart;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: <Widget>[
        chart,
        const SizedBox(width: AppSpacing.xl),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              for (final ChartSlice slice in slices)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: ChartLegendEntry(
                    slice: slice,
                    total: _total,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

/// A single coloured legend row: swatch, label, count.
class ChartLegendEntry extends StatelessWidget {
  const ChartLegendEntry({super.key, required this.slice, required this.total});

  final ChartSlice slice;
  final double total;

  @override
  Widget build(BuildContext context) {
    final String count = slice.value == slice.value.roundToDouble()
        ? slice.value.toStringAsFixed(0)
        : slice.value.toStringAsFixed(1);
    final String share =
        total <= 0 ? '' : ' · ${(slice.value / total * 100).round()}%';

    return Row(
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: slice.color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        Expanded(
          child: Text(
            slice.label,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall,
          ),
        ),
        Text(
          '$count$share',
          style: context.text.labelMedium?.copyWith(
            color: context.semantic.mutedText,
          ),
        ),
      ],
    );
  }
}

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.slices,
    required this.strokeWidth,
    required this.trackColor,
  });

  final List<ChartSlice> slices;
  final double strokeWidth;
  final Color trackColor;

  @override
  void paint(Canvas canvas, Size size) {
    final Offset center = Offset(size.width / 2, size.height / 2);
    final double radius = (math.min(size.width, size.height) - strokeWidth) / 2;
    final Rect rect = Rect.fromCircle(center: center, radius: radius);

    final Paint track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = trackColor;
    canvas.drawCircle(center, radius, track);

    final double total =
        slices.fold<double>(0, (double sum, ChartSlice s) => sum + s.value);
    if (total <= 0) return;

    // A small gap between slices keeps adjacent colours readable.
    const double gap = 0.02;
    double start = -math.pi / 2;

    for (final ChartSlice slice in slices) {
      if (slice.value <= 0) continue;
      final double sweep = (slice.value / total) * math.pi * 2;
      final Paint paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = strokeWidth
        ..strokeCap = StrokeCap.butt
        ..color = slice.color;

      final double effectiveSweep =
          sweep > gap * 2 ? sweep - gap : sweep;
      canvas.drawArc(rect, start, effectiveSweep, false, paint);
      start += sweep;
    }
  }

  @override
  bool shouldRepaint(_DonutPainter oldDelegate) =>
      oldDelegate.slices != slices ||
      oldDelegate.strokeWidth != strokeWidth ||
      oldDelegate.trackColor != trackColor;
}
