import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// One student's attendance outcome within an [AttendanceSession].
class AttendanceRecord {
  const AttendanceRecord({
    required this.id,
    required this.sessionId,
    required this.classId,
    required this.studentId,
    required this.status,
    required this.markedAt,
    this.note,
    this.notified = false,
  });

  factory AttendanceRecord.fromJson(Map<String, dynamic> json) {
    return AttendanceRecord(
      id: Json.string(json, 'id'),
      sessionId: Json.string(json, 'sessionId'),
      classId: Json.string(json, 'classId'),
      studentId: Json.string(json, 'studentId'),
      status: Json.enumValue(
        json,
        'status',
        AttendanceStatus.values,
        AttendanceStatus.present,
      ),
      markedAt: Json.dateTime(json, 'markedAt', fallback: DateTime.now()),
      note: Json.stringOrNull(json, 'note'),
      notified: Json.boolean(json, 'notified'),
    );
  }

  final String id;
  final String sessionId;

  /// Denormalised for fast per-class queries without joining the session.
  final String classId;
  final String studentId;
  final AttendanceStatus status;
  final DateTime markedAt;
  final String? note;

  /// True once the absence notification pipeline has processed this record, so
  /// editing a saved session does not re-notify guardians.
  final bool notified;

  AttendanceRecord copyWith({
    AttendanceStatus? status,
    String? note,
    bool clearNote = false,
    DateTime? markedAt,
    bool? notified,
  }) {
    return AttendanceRecord(
      id: id,
      sessionId: sessionId,
      classId: classId,
      studentId: studentId,
      status: status ?? this.status,
      markedAt: markedAt ?? this.markedAt,
      note: clearNote ? null : (note ?? this.note),
      notified: notified ?? this.notified,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'sessionId': sessionId,
        'classId': classId,
        'studentId': studentId,
        'status': status.name,
        'markedAt': markedAt.toIso8601String(),
        'note': note,
        'notified': notified,
      });

  @override
  bool operator ==(Object other) => other is AttendanceRecord && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
