import '../../data/models/models.dart';

/// Percentage → grade conversion.
///
/// Every grade shown anywhere in the app (list badges, performance screen,
/// PDFs) goes through this service, so switching an organization to a custom
/// scale changes all of them at once.
class GradingService {
  const GradingService();

  /// Safe percentage: returns `null` instead of dividing by zero.
  double? percentage({required double? obtained, required double total}) {
    if (obtained == null || total <= 0) return null;
    return (obtained / total) * 100;
  }

  GradeBand? gradeFor(double? percent, GradeScale scale) {
    if (percent == null) return null;
    return scale.bandFor(percent);
  }

  String gradeLabel(double? percent, GradeScale scale) =>
      gradeFor(percent, scale)?.label ?? '—';

  bool isPass(double? percent, GradeScale scale) {
    if (percent == null) return false;
    return percent >= scale.passPercent;
  }

  /// Weighted total across assessments.
  ///
  /// Only graded entries contribute — an assessment nobody has marked yet must
  /// not drag the class average towards zero.
  ({double obtained, double total}) aggregate(
    Iterable<({double? obtained, double total, double? weight})> entries,
  ) {
    double obtainedSum = 0;
    double totalSum = 0;
    for (final ({double? obtained, double total, double? weight}) entry in entries) {
      final double? value = entry.obtained;
      if (value == null || entry.total <= 0) continue;
      final double weight = entry.weight ?? 1;
      obtainedSum += value * weight;
      totalSum += entry.total * weight;
    }
    return (obtained: obtainedSum, total: totalSum);
  }

  /// Grade label → student count, ordered from the highest band down so charts
  /// and legends read consistently.
  Map<String, int> distribution(
    Iterable<double?> percentages,
    GradeScale scale,
  ) {
    final Map<String, int> counts = <String, int>{
      for (final GradeBand band in scale.bands) band.label: 0,
    };
    for (final double? percent in percentages) {
      if (percent == null) continue;
      final GradeBand band = scale.bandFor(percent);
      counts[band.label] = (counts[band.label] ?? 0) + 1;
    }
    return counts;
  }

  /// Mean of the non-null values, or `null` when there is nothing to average.
  double? average(Iterable<double?> values) {
    double sum = 0;
    int count = 0;
    for (final double? value in values) {
      if (value == null) continue;
      sum += value;
      count++;
    }
    return count == 0 ? null : sum / count;
  }
}
