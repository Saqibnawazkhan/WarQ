import '../models/models.dart';

/// Fields accepted when creating or editing an assessment.
class AssessmentDraft {
  const AssessmentDraft({
    required this.name,
    required this.type,
    required this.date,
    required this.totalMarks,
    this.customTypeLabel,
    this.description,
    this.weight,
  });

  final String name;
  final AssessmentType type;
  final DateTime date;
  final double totalMarks;
  final String? customTypeLabel;
  final String? description;
  final double? weight;
}

/// One student's entry on the mark-entry screen.
class MarkEntry {
  const MarkEntry({
    required this.studentId,
    this.marksObtained,
    this.remarks,
    this.absent = false,
  });

  final String studentId;
  final double? marksObtained;
  final String? remarks;
  final bool absent;
}

/// Assessments and the marks recorded against them.
abstract class AssessmentRepository {
  Future<List<Assessment>> listForClass(String classId);

  Future<List<Assessment>> listForTeacher(String teacherId);

  Future<Assessment?> findById(String assessmentId);

  Future<Assessment> create({
    required String classId,
    required String userId,
    required AssessmentDraft draft,
  });

  Future<Assessment> update(String assessmentId, AssessmentDraft draft);

  /// Deletes the assessment and every mark recorded against it.
  Future<void> delete(String assessmentId);

  /// Marks for one assessment keyed by student id.
  Future<Map<String, AssessmentMark>> marksForAssessment(String assessmentId);

  Future<List<AssessmentMark>> marksForClass(String classId);

  Future<List<AssessmentMark>> marksForStudent(
    String studentId, {
    String? classId,
  });

  /// Upserts every entry in one transaction-like batch.
  Future<void> saveMarks({
    required String assessmentId,
    required List<MarkEntry> entries,
  });

  Future<void> deleteMark(String markId);

  /// How many students have a graded entry, per assessment id.
  Future<Map<String, int>> gradedCounts(Iterable<String> assessmentIds);
}
