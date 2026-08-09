import '../../core/utils/json_utils.dart';

/// A single student's score on a single assessment.
///
/// [marksObtained] is nullable on purpose: a blank score means "not graded
/// yet", which is different from a zero and must be excluded from averages.
class AssessmentMark {
  const AssessmentMark({
    required this.id,
    required this.assessmentId,
    required this.classId,
    required this.studentId,
    required this.recordedAt,
    this.marksObtained,
    this.remarks,
    this.absent = false,
    this.updatedAt,
  });

  factory AssessmentMark.fromJson(Map<String, dynamic> json) {
    return AssessmentMark(
      id: Json.string(json, 'id'),
      assessmentId: Json.string(json, 'assessmentId'),
      classId: Json.string(json, 'classId'),
      studentId: Json.string(json, 'studentId'),
      recordedAt: Json.dateTime(json, 'recordedAt', fallback: DateTime.now()),
      marksObtained: Json.numberOrNull(json, 'marksObtained'),
      remarks: Json.stringOrNull(json, 'remarks'),
      absent: Json.boolean(json, 'absent'),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  final String id;
  final String assessmentId;

  /// Denormalised so class-wide queries do not need to resolve the assessment.
  final String classId;
  final String studentId;
  final DateTime recordedAt;

  /// `null` means not graded yet.
  final double? marksObtained;
  final String? remarks;

  /// The student missed the assessment. Scored as 0 but flagged in reports.
  final bool absent;
  final DateTime? updatedAt;

  bool get isGraded => marksObtained != null || absent;

  /// Effective score used in calculations: an absent student scores zero.
  double? get effectiveMarks {
    if (absent) return 0;
    return marksObtained;
  }

  double? percentageOf(double totalMarks) {
    final double? value = effectiveMarks;
    if (value == null || totalMarks <= 0) return null;
    return (value / totalMarks) * 100;
  }

  AssessmentMark copyWith({
    double? marksObtained,
    bool clearMarks = false,
    String? remarks,
    bool clearRemarks = false,
    bool? absent,
    DateTime? updatedAt,
  }) {
    return AssessmentMark(
      id: id,
      assessmentId: assessmentId,
      classId: classId,
      studentId: studentId,
      recordedAt: recordedAt,
      marksObtained: clearMarks ? null : (marksObtained ?? this.marksObtained),
      remarks: clearRemarks ? null : (remarks ?? this.remarks),
      absent: absent ?? this.absent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'assessmentId': assessmentId,
        'classId': classId,
        'studentId': studentId,
        'recordedAt': recordedAt.toIso8601String(),
        'marksObtained': marksObtained,
        'remarks': remarks,
        'absent': absent,
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is AssessmentMark && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
