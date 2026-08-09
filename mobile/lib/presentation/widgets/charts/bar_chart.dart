import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import 'chart_data.dart';

/// Horizontal bars — used for grade distribution, where the category labels
/// (A+, A, B…) read better on the left than rotated under a vertical axis.
class HorizontalBarChart extends StatelessWidget {
  const HorizontalBarChart({
    super.key,
    required this.slices,
    this.maxValue,
    this.labelWidth = 34,
    this.barHeight = 10,
    this.showValues = true,
  });

  final List<ChartSlice> slices;

  /// Defaults to the largest value so the tallest bar fills the row.
  final double? maxValue;
  final double labelWidth;
  final double barHeight;
  final bool showValues;

  @override
  Widget build(BuildContext context) {
    final double max = maxValue ??
        slices.fold<double>(
          0,
          (double acc, ChartSlice s) => s.value > acc ? s.value : acc,
        );
    final double total =
        slices.fold<double>(0, (double sum, ChartSlice s) => sum + s.value);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final ChartSlice slice in slices)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: Row(
              children: <Widget>[
                SizedBox(
                  width: labelWidth,
                  child: Text(
                    slice.label,
                    style: context.text.labelMedium
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                ),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(barHeight),
                    child: LinearProgressIndicator(
                      value: max <= 0 ? 0 : (slice.value / max).clamp(0, 1),
                      minHeight: barHeight,
                      backgroundColor: context.semantic.subtleBorder,
                      valueColor: AlwaysStoppedAnimation<Color>(slice.color),
                    ),
                  ),
                ),
                if (showValues) ...<Widget>[
                  const SizedBox(width: AppSpacing.md),
                  SizedBox(
                    width: 62,
                    child: Text(
                      total <= 0
                          ? '0'
                          : '${slice.value.toStringAsFixed(0)} '
                              '(${(slice.value / total * 100).round()}%)',
                      textAlign: TextAlign.end,
                      style: context.text.labelSmall?.copyWith(
                        color: context.semantic.mutedText,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}

/// A single labelled progress bar, used for attendance and grading progress.
class LabeledProgressBar extends StatelessWidget {
  const LabeledProgressBar({
    super.key,
    required this.label,
    required this.value,
    this.trailingLabel,
    this.color,
    this.height = 8,
  });

  final String label;

  /// 0–1.
  final double value;
  final String? trailingLabel;
  final Color? color;
  final double height;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                label,
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ),
            if (trailingLabel != null)
              Text(
                trailingLabel!,
                style: context.text.labelMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
          ],
        ),
        const SizedBox(height: AppSpacing.sm),
        ClipRRect(
          borderRadius: BorderRadius.circular(height),
          child: LinearProgressIndicator(
            value: value.isNaN ? 0 : value.clamp(0, 1),
            minHeight: height,
            backgroundColor: context.semantic.subtleBorder,
            valueColor: AlwaysStoppedAnimation<Color>(
              color ?? context.colors.primary,
            ),
          ),
        ),
      ],
    );
  }
}
