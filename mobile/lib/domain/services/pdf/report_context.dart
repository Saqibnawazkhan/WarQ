import '../../../data/models/models.dart';

/// Shared metadata printed on every report.
class ReportContext {
  ReportContext({
    required this.teacher,
    required this.gradeScale,
    this.organization,
    DateTime? generatedAt,
  }) : generatedAt = generatedAt ?? DateTime.now();

  final AppUser teacher;
  final GradeScale gradeScale;
  final Organization? organization;
  final DateTime generatedAt;

  String get issuerName => organization?.name ?? teacher.displayName;

  String get teacherLine {
    final String? title = teacher.title;
    return title == null ? teacher.displayName : '${teacher.displayName} · $title';
  }
}
