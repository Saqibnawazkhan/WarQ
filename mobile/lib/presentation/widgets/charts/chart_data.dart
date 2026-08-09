import 'package:flutter/material.dart';

/// One slice / bar / point in a chart.
class ChartSlice {
  const ChartSlice({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final double value;
  final Color color;
}

/// One point on a trend line.
class TrendPoint {
  const TrendPoint({
    required this.label,
    required this.value,
    this.caption,
  });

  final String label;

  /// Percentage in the 0–100 range.
  final double value;
  final String? caption;
}
