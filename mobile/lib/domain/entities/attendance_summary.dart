import '../../data/models/enums.dart';

/// Aggregated attendance for one student (optionally scoped to one class).
///
/// Short leave sessions are removed from the denominator so a sanctioned absence
/// does not damage the percentage, while `late` still counts as attended.
class AttendanceSummary {
  const AttendanceSummary({
    required this.present,
    required this.absent,
    required this.late,
    required this.shortLeave,
  });

  const AttendanceSummary.empty()
      : present = 0,
        absent = 0,
        late = 0,
        shortLeave = 0;

  /// Builds a summary from raw statuses.
  factory AttendanceSummary.fromStatuses(Iterable<AttendanceStatus> statuses) {
    int present = 0;
    int absent = 0;
    int late = 0;
    int shortLeave = 0;
    for (final AttendanceStatus status in statuses) {
      switch (status) {
        case AttendanceStatus.present:
          present++;
        case AttendanceStatus.absent:
          absent++;
        case AttendanceStatus.late:
          late++;
        case AttendanceStatus.shortLeave:
          shortLeave++;
      }
    }
    return AttendanceSummary(
      present: present,
      absent: absent,
      late: late,
      shortLeave: shortLeave,
    );
  }

  final int present;
  final int absent;
  final int late;
  final int shortLeave;

  /// Every session the student has a record for.
  int get totalSessions => present + absent + late + shortLeave;

  /// Sessions that count towards the percentage.
  int get assessableSessions => present + absent + late;

  /// Present plus late.
  int get attended => present + late;

  bool get hasData => totalSessions > 0;

  /// `null` when there is nothing to divide by, which the UI renders as "—"
  /// rather than a misleading 0%.
  double? get percentage {
    if (assessableSessions == 0) return null;
    return (attended / assessableSessions) * 100;
  }

  double get percentageOrZero => percentage ?? 0;

  AttendanceSummary operator +(AttendanceSummary other) => AttendanceSummary(
        present: present + other.present,
        absent: absent + other.absent,
        late: late + other.late,
        shortLeave: shortLeave + other.shortLeave,
      );

  static AttendanceSummary combine(Iterable<AttendanceSummary> parts) {
    return parts.fold<AttendanceSummary>(
      const AttendanceSummary.empty(),
      (AttendanceSummary acc, AttendanceSummary next) => acc + next,
    );
  }

  @override
  String toString() =>
      'AttendanceSummary(P:$present A:$absent L:$late S:$shortLeave)';
}
