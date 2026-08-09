import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import 'chart_data.dart';

/// Line chart of percentages over time — the student's marks progression.
///
/// Deliberately minimal: gridlines at 0/50/100, a filled area under the line
/// and a dot per assessment, with labels underneath.
class TrendChart extends StatelessWidget {
  const TrendChart({
    super.key,
    required this.points,
    this.height = 160,
    this.showLabels = true,
    this.lineColor,
  });

  final List<TrendPoint> points;
  final double height;
  final bool showLabels;
  final Color? lineColor;

  @override
  Widget build(BuildContext context) {
    if (points.isEmpty) {
      return SizedBox(
        height: height,
        child: Center(
          child: Text(
            'No graded assessments yet',
            style: context.text.bodySmall?.copyWith(
              color: context.semantic.mutedText,
            ),
          ),
        ),
      );
    }

    final Color color = lineColor ?? context.colors.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        SizedBox(
          height: height,
          child: CustomPaint(
            painter: _TrendPainter(
              points: points,
              lineColor: color,
              gridColor: context.semantic.subtleBorder,
              labelColor: context.semantic.mutedText,
              surfaceColor: context.colors.surface,
              textDirection: Directionality.of(context),
            ),
          ),
        ),
        if (showLabels) ...<Widget>[
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: <Widget>[
              for (final TrendPoint point in points)
                Expanded(
                  child: Text(
                    point.label,
                    maxLines: 2,
                    textAlign: TextAlign.center,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelSmall?.copyWith(
                      color: context.semantic.mutedText,
                      height: 1.15,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ],
    );
  }
}

class _TrendPainter extends CustomPainter {
  _TrendPainter({
    required this.points,
    required this.lineColor,
    required this.gridColor,
    required this.labelColor,
    required this.surfaceColor,
    required this.textDirection,
  });

  final List<TrendPoint> points;
  final Color lineColor;
  final Color gridColor;
  final Color labelColor;
  final Color surfaceColor;
  final TextDirection textDirection;

  static const double _leftGutter = 30;
  static const double _topPadding = 8;
  static const double _bottomPadding = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final double chartLeft = _leftGutter;
    final double chartWidth = size.width - chartLeft;
    final double chartHeight = size.height - _topPadding - _bottomPadding;
    if (chartWidth <= 0 || chartHeight <= 0) return;

    final Paint grid = Paint()
      ..color = gridColor
      ..strokeWidth = 1;

    // Gridlines and axis labels at 0 / 50 / 100 percent.
    for (final int value in <int>[0, 50, 100]) {
      final double y = _topPadding + chartHeight * (1 - value / 100);
      canvas.drawLine(Offset(chartLeft, y), Offset(size.width, y), grid);
      _paintText(canvas, '$value', Offset(0, y - 6), labelColor);
    }

    final int count = points.length;
    double xFor(int index) => count == 1
        ? chartLeft + chartWidth / 2
        : chartLeft + (chartWidth / (count - 1)) * index;
    double yFor(double value) =>
        _topPadding + chartHeight * (1 - value.clamp(0, 100) / 100);

    final Path line = Path();
    final Path area = Path();
    for (int i = 0; i < count; i++) {
      final Offset point = Offset(xFor(i), yFor(points[i].value));
      if (i == 0) {
        line.moveTo(point.dx, point.dy);
        area.moveTo(point.dx, _topPadding + chartHeight);
        area.lineTo(point.dx, point.dy);
      } else {
        line.lineTo(point.dx, point.dy);
        area.lineTo(point.dx, point.dy);
      }
    }
    area
      ..lineTo(xFor(count - 1), _topPadding + chartHeight)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: <Color>[
            lineColor.withValues(alpha: 0.22),
            lineColor.withValues(alpha: 0.02),
          ],
        ).createShader(Rect.fromLTWH(chartLeft, _topPadding, chartWidth, chartHeight)),
    );

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.4
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..color = lineColor,
    );

    for (int i = 0; i < count; i++) {
      final Offset point = Offset(xFor(i), yFor(points[i].value));
      canvas.drawCircle(point, 4.5, Paint()..color = surfaceColor);
      canvas.drawCircle(
        point,
        4.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2.2
          ..color = lineColor,
      );
    }
  }

  void _paintText(Canvas canvas, String text, Offset offset, Color color) {
    final TextPainter painter = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(fontSize: 10, color: color),
      ),
      textDirection: textDirection,
    )..layout(maxWidth: _leftGutter - 4);
    painter.paint(canvas, offset);
  }

  @override
  bool shouldRepaint(_TrendPainter oldDelegate) =>
      oldDelegate.points != points ||
      oldDelegate.lineColor != lineColor ||
      oldDelegate.gridColor != gridColor;
}
