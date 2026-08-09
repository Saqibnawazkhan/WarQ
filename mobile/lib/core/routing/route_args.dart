import '../../data/models/models.dart';
import '../../domain/services/report_service.dart';

/// Typed arguments for named routes.
///
/// Passing a small argument object instead of a raw map keeps navigation
/// call sites type-checked and makes the route table readable.
class ClassFormArgs {
  const ClassFormArgs({this.existing});

  /// `null` creates a new class.
  final SchoolClass? existing;

  bool get isEditing => existing != null;
}

class ClassDetailArgs {
  const ClassDetailArgs({required this.classId, this.initialTab = 0});

  final String classId;

  /// 0 = students, 1 = attendance, 2 = assessments.
  final int initialTab;
}

class StudentFormArgs {
  const StudentFormArgs({this.classId, this.existing});

  /// When set, a newly created student is enrolled in this class.
  final String? classId;
  final Student? existing;

  bool get isEditing => existing != null;
}

class StudentDetailArgs {
  const StudentDetailArgs({required this.studentId, this.classId});

  final String studentId;

  /// Scopes attendance and marks to one class when provided.
  final String? classId;
}

class EnrollStudentsArgs {
  const EnrollStudentsArgs({required this.classId, required this.className});

  final String classId;
  final String className;
}

class MarkAttendanceArgs {
  const MarkAttendanceArgs({required this.classId, this.date});

  final String classId;
  final DateTime? date;
}

class AttendanceHistoryArgs {
  const AttendanceHistoryArgs({this.classId, this.studentId});

  final String? classId;
  final String? studentId;
}

class AssessmentFormArgs {
  const AssessmentFormArgs({required this.classId, this.existing});

  final String classId;
  final Assessment? existing;

  bool get isEditing => existing != null;
}

class AssessmentMarksArgs {
  const AssessmentMarksArgs({required this.assessmentId});

  final String assessmentId;
}

class ReportPreviewArgs {
  const ReportPreviewArgs({required this.report});

  final GeneratedReport report;
}

class TeacherDetailArgs {
  const TeacherDetailArgs({required this.teacherId});

  final String teacherId;
}

class InviteTeacherArgs {
  const InviteTeacherArgs({this.prefilledEmail});

  final String? prefilledEmail;
}
