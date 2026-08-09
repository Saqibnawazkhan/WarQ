import '../../core/constants/app_constants.dart';
import '../../data/models/models.dart';
import 'attendance_summary.dart';

/// One student's outcome on one assessment, with the grade already resolved.
class AssessmentResult {
  const AssessmentResult({
    required this.assessment,
    this.mark,
    this.grade,
  });

  final Assessment assessment;
  final AssessmentMark? mark;
  final GradeBand? grade;

  bool get isGraded => mark?.isGraded ?? false;

  bool get wasAbsent => mark?.absent ?? false;

  double? get obtained => mark?.effectiveMarks;

  double get total => assessment.totalMarks;

  double? get percentage {
    final double? value = obtained;
    if (value == null || total <= 0) return null;
    return (value / total) * 100;
  }
}

/// Everything the performance screen and the student PDF need.
class StudentPerformance {
  const StudentPerformance({
    required this.student,
    required this.attendance,
    required this.results,
    required this.obtainedTotal,
    required this.maxTotal,
    required this.percentage,
    required this.grade,
    this.classId,
    this.className,
  });

  factory StudentPerformance.empty(Student student) => StudentPerformance(
        student: student,
        attendance: const AttendanceSummary.empty(),
        results: const <AssessmentResult>[],
        obtainedTotal: 0,
        maxTotal: 0,
        percentage: null,
        grade: null,
      );

  final Student student;
  final AttendanceSummary attendance;

  /// Ordered oldest → newest so the progression chart reads left to right.
  final List<AssessmentResult> results;

  /// Sum of scores across graded assessments only.
  final double obtainedTotal;

  /// Sum of totals across graded assessments only, so an ungraded quiz does
  /// not drag the percentage down.
  final double maxTotal;
  final double? percentage;
  final GradeBand? grade;
  final String? classId;
  final String? className;

  int get gradedCount => results.where((AssessmentResult r) => r.isGraded).length;

  int get pendingCount => results.length - gradedCount;

  bool get hasMarks => gradedCount > 0;

  bool get hasLowAttendance {
    final double? value = attendance.percentage;
    return value != null && value < AppConstants.attendanceRiskThreshold;
  }

  bool get isUnderperforming {
    final double? value = percentage;
    return value != null && value < AppConstants.performanceRiskThreshold;
  }

  bool get isAtRisk => hasLowAttendance || isUnderperforming;

  /// Best and worst graded results, used for the highlights row.
  AssessmentResult? get bestResult {
    AssessmentResult? best;
    for (final AssessmentResult result in results) {
      final double? value = result.percentage;
      if (value == null) continue;
      if (best == null || value > (best.percentage ?? -1)) best = result;
    }
    return best;
  }

  AssessmentResult? get weakestResult {
    AssessmentResult? worst;
    for (final AssessmentResult result in results) {
      final double? value = result.percentage;
      if (value == null) continue;
      if (worst == null || value < (worst.percentage ?? 101)) worst = result;
    }
    return worst;
  }
}

/// Class-wide roll-up used by the class dashboard and the class PDF.
class ClassPerformance {
  const ClassPerformance({
    required this.schoolClass,
    required this.students,
    required this.gradeScale,
    required this.sessionCount,
    required this.assessmentCount,
    required this.gradeDistribution,
    required this.averagePercentage,
    required this.averageAttendance,
    this.lastSessionDate,
  });

  final SchoolClass schoolClass;

  /// A–Z by student name, matching the list screens.
  final List<StudentPerformance> students;
  final GradeScale gradeScale;
  final int sessionCount;
  final int assessmentCount;

  /// Grade label → number of students, ordered high to low.
  final Map<String, int> gradeDistribution;
  final double? averagePercentage;
  final double? averageAttendance;
  final DateTime? lastSessionDate;

  int get studentCount => students.length;

  List<StudentPerformance> get atRisk =>
      students.where((StudentPerformance s) => s.isAtRisk).toList();

  List<StudentPerformance> topPerformers({int limit = 3}) {
    final List<StudentPerformance> graded = students
        .where((StudentPerformance s) => s.percentage != null)
        .toList()
      ..sort((StudentPerformance a, StudentPerformance b) =>
          b.percentage!.compareTo(a.percentage!));
    return graded.take(limit).toList();
  }

  List<StudentPerformance> needsAttention({int limit = 3}) {
    final List<StudentPerformance> risky = atRisk
      ..sort((StudentPerformance a, StudentPerformance b) {
        final double aScore = a.percentage ?? a.attendance.percentageOrZero;
        final double bScore = b.percentage ?? b.attendance.percentageOrZero;
        return aScore.compareTo(bScore);
      });
    return risky.take(limit).toList();
  }
}
