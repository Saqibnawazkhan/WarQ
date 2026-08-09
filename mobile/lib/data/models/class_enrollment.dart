import '../../core/utils/json_utils.dart';

/// Join record between a [Student] and a class ("class_students" table).
///
/// Keeping enrollment separate means a student can appear in several classes,
/// and unenrolling preserves the historical attendance and marks rather than
/// deleting the person.
class ClassEnrollment {
  const ClassEnrollment({
    required this.id,
    required this.classId,
    required this.studentId,
    required this.enrolledAt,
    this.active = true,
    this.unenrolledAt,
  });

  factory ClassEnrollment.fromJson(Map<String, dynamic> json) {
    return ClassEnrollment(
      id: Json.string(json, 'id'),
      classId: Json.string(json, 'classId'),
      studentId: Json.string(json, 'studentId'),
      enrolledAt: Json.dateTime(json, 'enrolledAt', fallback: DateTime.now()),
      active: Json.boolean(json, 'active', fallback: true),
      unenrolledAt: Json.dateTimeOrNull(json, 'unenrolledAt'),
    );
  }

  final String id;
  final String classId;
  final String studentId;
  final DateTime enrolledAt;
  final bool active;
  final DateTime? unenrolledAt;

  ClassEnrollment copyWith({bool? active, DateTime? unenrolledAt}) {
    return ClassEnrollment(
      id: id,
      classId: classId,
      studentId: studentId,
      enrolledAt: enrolledAt,
      active: active ?? this.active,
      unenrolledAt: unenrolledAt ?? this.unenrolledAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'classId': classId,
        'studentId': studentId,
        'enrolledAt': enrolledAt.toIso8601String(),
        'active': active,
        'unenrolledAt': unenrolledAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is ClassEnrollment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
