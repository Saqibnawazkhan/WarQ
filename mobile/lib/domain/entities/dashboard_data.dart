import '../../data/models/models.dart';
import 'attendance_summary.dart';

/// A class row on the dashboard and class list, with its aggregates resolved.
class ClassSummary {
  const ClassSummary({
    required this.schoolClass,
    required this.studentCount,
    required this.assessmentCount,
    required this.sessionCount,
    required this.attendance,
    this.lastSessionDate,
    this.averagePercentage,
    this.markedToday = false,
  });

  final SchoolClass schoolClass;
  final int studentCount;
  final int assessmentCount;
  final int sessionCount;
  final AttendanceSummary attendance;
  final DateTime? lastSessionDate;
  final double? averagePercentage;

  /// Whether attendance already exists for today — drives the dashboard's
  /// "pending attendance" call to action.
  final bool markedToday;

  String get id => schoolClass.id;
  String get name => schoolClass.name;
}

/// Today's attendance snapshot across every class a teacher owns.
class TodayAttendance {
  const TodayAttendance({
    required this.summary,
    required this.classesMarked,
    required this.classesTotal,
    required this.pendingClasses,
  });

  const TodayAttendance.empty()
      : summary = const AttendanceSummary.empty(),
        classesMarked = 0,
        classesTotal = 0,
        pendingClasses = const <SchoolClass>[];

  final AttendanceSummary summary;
  final int classesMarked;
  final int classesTotal;

  /// Classes with students that still have no attendance for today.
  final List<SchoolClass> pendingClasses;

  bool get isComplete => classesTotal > 0 && classesMarked >= classesTotal;
  bool get hasAnyRecords => summary.totalSessions > 0;
}

/// Everything the teacher dashboard renders.
class TeacherDashboardData {
  const TeacherDashboardData({
    required this.totalClasses,
    required this.totalStudents,
    required this.today,
    required this.recentClasses,
    required this.recentAssessments,
    required this.recentActivity,
    required this.overallAttendance,
    required this.assessmentsAwaitingMarks,
    this.overallAveragePercentage,
  });

  const TeacherDashboardData.empty()
      : totalClasses = 0,
        totalStudents = 0,
        today = const TodayAttendance.empty(),
        recentClasses = const <ClassSummary>[],
        recentAssessments = const <AssessmentSummary>[],
        recentActivity = const <ActivityLog>[],
        overallAttendance = const AttendanceSummary.empty(),
        assessmentsAwaitingMarks = const <AssessmentSummary>[],
        overallAveragePercentage = null;

  final int totalClasses;
  final int totalStudents;
  final TodayAttendance today;
  final List<ClassSummary> recentClasses;
  final List<AssessmentSummary> recentAssessments;
  final List<ActivityLog> recentActivity;
  final AttendanceSummary overallAttendance;

  /// Assessments where at least one enrolled student has no score yet.
  final List<AssessmentSummary> assessmentsAwaitingMarks;
  final double? overallAveragePercentage;

  bool get isEmpty => totalClasses == 0 && totalStudents == 0;
}

/// An assessment plus its grading progress.
class AssessmentSummary {
  const AssessmentSummary({
    required this.assessment,
    required this.className,
    required this.gradedCount,
    required this.studentCount,
    this.averagePercentage,
  });

  final Assessment assessment;
  final String className;
  final int gradedCount;
  final int studentCount;
  final double? averagePercentage;

  String get id => assessment.id;

  bool get isFullyGraded => studentCount > 0 && gradedCount >= studentCount;

  int get pendingCount => (studentCount - gradedCount).clamp(0, studentCount);

  double get progress => studentCount == 0 ? 0 : gradedCount / studentCount;
}

/// Aggregates for the organization admin dashboard.
class OrganizationDashboardData {
  const OrganizationDashboardData({
    required this.organization,
    required this.teacherCount,
    required this.classCount,
    required this.studentCount,
    required this.pendingInvitations,
    required this.attendance,
    required this.recentActivity,
    required this.teacherSnapshots,
    this.averagePercentage,
    this.sessionsThisWeek = 0,
  });

  final Organization? organization;
  final int teacherCount;
  final int classCount;
  final int studentCount;
  final int pendingInvitations;
  final AttendanceSummary attendance;
  final List<ActivityLog> recentActivity;

  /// One row per teacher, ordered by name.
  final List<TeacherSnapshot> teacherSnapshots;
  final double? averagePercentage;
  final int sessionsThisWeek;
}

/// Monitoring view of a single teacher inside an organization.
class TeacherSnapshot {
  const TeacherSnapshot({
    required this.teacher,
    required this.classCount,
    required this.studentCount,
    required this.assessmentCount,
    required this.sessionCount,
    required this.marksRecorded,
    required this.attendance,
    this.lastActivityAt,
    this.lastAttendanceAt,
    this.averagePercentage,
    this.classes = const <ClassSummary>[],
    this.gradeDistribution = const <String, int>{},
  });

  final AppUser teacher;
  final int classCount;
  final int studentCount;
  final int assessmentCount;
  final int sessionCount;
  final int marksRecorded;
  final AttendanceSummary attendance;
  final DateTime? lastActivityAt;
  final DateTime? lastAttendanceAt;
  final double? averagePercentage;

  /// Populated only on the detail screen; the list view leaves it empty.
  final List<ClassSummary> classes;
  final Map<String, int> gradeDistribution;

  bool get isActive {
    final DateTime? at = lastActivityAt;
    if (at == null) return false;
    return DateTime.now().difference(at).inDays <= 7;
  }
}
