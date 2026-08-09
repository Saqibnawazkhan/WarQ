import 'package:edu_manager/data/models/enums.dart';
import 'package:edu_manager/domain/entities/attendance_summary.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AttendanceSummary', () {
    test('counts each status', () {
      final AttendanceSummary summary = AttendanceSummary.fromStatuses(
        <AttendanceStatus>[
          AttendanceStatus.present,
          AttendanceStatus.present,
          AttendanceStatus.absent,
          AttendanceStatus.late,
          AttendanceStatus.shortLeave,
        ],
      );

      expect(summary.present, 2);
      expect(summary.absent, 1);
      expect(summary.late, 1);
      expect(summary.shortLeave, 1);
      expect(summary.totalSessions, 5);
    });

    test('counts late as attended', () {
      final AttendanceSummary summary = AttendanceSummary.fromStatuses(
        <AttendanceStatus>[
          AttendanceStatus.present,
          AttendanceStatus.late,
          AttendanceStatus.absent,
          AttendanceStatus.absent,
        ],
      );

      expect(summary.attended, 2);
      expect(summary.percentage, 50);
    });

    test('excludes short leave sessions from the denominator', () {
      final AttendanceSummary summary = AttendanceSummary.fromStatuses(
        <AttendanceStatus>[
          AttendanceStatus.present,
          AttendanceStatus.present,
          AttendanceStatus.shortLeave,
        ],
      );

      expect(summary.totalSessions, 3);
      expect(summary.assessableSessions, 2);
      // An authorised absence must not damage the percentage.
      expect(summary.percentage, 100);
    });

    test('returns null instead of a misleading zero when there is no data', () {
      const AttendanceSummary summary = AttendanceSummary.empty();

      expect(summary.hasData, isFalse);
      expect(summary.percentage, isNull);
      expect(summary.percentageOrZero, 0);
    });

    test('returns null when every session was short leave', () {
      final AttendanceSummary summary = AttendanceSummary.fromStatuses(
        <AttendanceStatus>[AttendanceStatus.shortLeave, AttendanceStatus.shortLeave],
      );

      expect(summary.hasData, isTrue);
      expect(summary.percentage, isNull);
    });

    test('combines summaries across classes', () {
      final AttendanceSummary combined = AttendanceSummary.combine(
        <AttendanceSummary>[
          const AttendanceSummary(present: 3, absent: 1, late: 0, shortLeave: 0),
          const AttendanceSummary(present: 2, absent: 2, late: 1, shortLeave: 1),
        ],
      );

      expect(combined.present, 5);
      expect(combined.absent, 3);
      expect(combined.late, 1);
      expect(combined.shortLeave, 1);
      expect(combined.percentage, closeTo(66.67, 0.01));
    });
  });

  group('AttendanceStatus', () {
    test('only absences trigger guardian notifications', () {
      expect(AttendanceStatus.absent.notifiesGuardians, isTrue);
      expect(AttendanceStatus.present.notifiesGuardians, isFalse);
      expect(AttendanceStatus.late.notifiesGuardians, isFalse);
      expect(AttendanceStatus.shortLeave.notifiesGuardians, isFalse);
    });
  });
}
