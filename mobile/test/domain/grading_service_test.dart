import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/domain/services/grading_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const GradingService grading = GradingService();
  final GradeScale scale = GradeScale.platformDefault();

  group('GradingService.gradeFor', () {
    test('maps the boundaries of the default scale from the spec', () {
      expect(grading.gradeLabel(100, scale), 'A+');
      expect(grading.gradeLabel(90, scale), 'A+');
      expect(grading.gradeLabel(89.9, scale), 'A');
      expect(grading.gradeLabel(80, scale), 'A');
      expect(grading.gradeLabel(79.9, scale), 'B');
      expect(grading.gradeLabel(70, scale), 'B');
      expect(grading.gradeLabel(69.9, scale), 'C');
      expect(grading.gradeLabel(60, scale), 'C');
      expect(grading.gradeLabel(59.9, scale), 'D');
      expect(grading.gradeLabel(50, scale), 'D');
      expect(grading.gradeLabel(49.9, scale), 'F');
      expect(grading.gradeLabel(0, scale), 'F');
    });

    test('returns a dash when there is no percentage to grade', () {
      expect(grading.gradeLabel(null, scale), '—');
      expect(grading.gradeFor(null, scale), isNull);
    });
  });

  group('GradingService.percentage', () {
    test('computes a percentage from marks', () {
      expect(grading.percentage(obtained: 18, total: 20), 90);
      expect(grading.percentage(obtained: 0, total: 20), 0);
    });

    test('returns null rather than dividing by zero or grading a blank', () {
      expect(grading.percentage(obtained: null, total: 20), isNull);
      expect(grading.percentage(obtained: 10, total: 0), isNull);
    });
  });

  group('GradingService.aggregate', () {
    test('excludes ungraded entries from both sides of the ratio', () {
      final ({double obtained, double total}) result = grading.aggregate(
        <({double? obtained, double total, double? weight})>[
          (obtained: 18, total: 20, weight: null),
          (obtained: null, total: 50, weight: null), // not graded yet
          (obtained: 20, total: 25, weight: null),
        ],
      );

      expect(result.obtained, 38);
      // The ungraded 50-mark assessment must not appear in the denominator.
      expect(result.total, 45);
    });

    test('applies weights when provided', () {
      final ({double obtained, double total}) result = grading.aggregate(
        <({double? obtained, double total, double? weight})>[
          (obtained: 10, total: 10, weight: 2),
          (obtained: 5, total: 10, weight: 1),
        ],
      );

      expect(result.obtained, 25);
      expect(result.total, 30);
    });
  });

  group('GradingService.distribution', () {
    test('counts students per band and keeps every band present', () {
      final Map<String, int> distribution = grading.distribution(
        <double?>[95, 85, 84, 72, null, 40],
        scale,
      );

      expect(distribution['A+'], 1);
      expect(distribution['A'], 2);
      expect(distribution['B'], 1);
      expect(distribution['C'], 0);
      expect(distribution['D'], 0);
      expect(distribution['F'], 1);
      // Ungraded students are not counted anywhere.
      expect(distribution.values.reduce((int a, int b) => a + b), 5);
    });
  });

  group('GradingService.average', () {
    test('ignores nulls and returns null for an empty set', () {
      expect(grading.average(<double?>[80, null, 100]), 90);
      expect(grading.average(<double?>[null, null]), isNull);
      expect(grading.average(<double?>[]), isNull);
    });
  });

  group('GradeScale', () {
    test('sorts bands from highest threshold down', () {
      final GradeScale custom = GradeScale(
        id: 'x',
        name: 'Custom',
        createdAt: DateTime(2026),
        bands: const <GradeBand>[
          GradeBand(label: 'Pass', minPercent: 0),
          GradeBand(label: 'Distinction', minPercent: 75),
          GradeBand(label: 'Merit', minPercent: 60),
        ],
      );

      expect(
        custom.bands.map((GradeBand b) => b.label).toList(),
        <String>['Distinction', 'Merit', 'Pass'],
      );
      expect(custom.bandFor(80).label, 'Distinction');
      expect(custom.bandFor(61).label, 'Merit');
      expect(custom.bandFor(10).label, 'Pass');
    });

    test('exposes an inclusive display range per band', () {
      final ({double min, double? max}) top = scale.rangeFor(scale.bands.first);
      expect(top.min, 90);
      expect(top.max, isNull);

      final ({double min, double? max}) second = scale.rangeFor(scale.bands[1]);
      expect(second.min, 80);
      expect(second.max, 90);
    });
  });
}
