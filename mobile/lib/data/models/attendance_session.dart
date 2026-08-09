import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';

/// One attendance-taking event: a class on a specific calendar day.
///
/// A session owns many [AttendanceRecord]s (one per student). There is at most
/// one session per (classId, date) pair; re-opening the same day edits the
/// existing session rather than creating a duplicate.
class AttendanceSession {
  const AttendanceSession({
    required this.id,
    required this.classId,
    required this.date,
    required this.takenByUserId,
    required this.createdAt,
    this.note,
    this.updatedAt,
  });

  factory AttendanceSession.fromJson(Map<String, dynamic> json) {
    return AttendanceSession(
      id: Json.string(json, 'id'),
      classId: Json.string(json, 'classId'),
      date: AppDate.parseIso(Json.stringOrNull(json, 'date')) ?? AppDate.today(),
      takenByUserId: Json.string(json, 'takenByUserId'),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      note: Json.stringOrNull(json, 'note'),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  final String id;
  final String classId;

  /// Normalised to local midnight.
  final DateTime date;
  final String takenByUserId;
  final DateTime createdAt;
  final String? note;
  final DateTime? updatedAt;

  /// Stable key for the (class, day) uniqueness constraint.
  String get dayKey => '$classId@${AppDate.toIso(date)}';

  AttendanceSession copyWith({
    String? note,
    bool clearNote = false,
    DateTime? updatedAt,
  }) {
    return AttendanceSession(
      id: id,
      classId: classId,
      date: date,
      takenByUserId: takenByUserId,
      createdAt: createdAt,
      note: clearNote ? null : (note ?? this.note),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'classId': classId,
        'date': AppDate.toIso(date),
        'takenByUserId': takenByUserId,
        'createdAt': createdAt.toIso8601String(),
        'note': note,
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is AttendanceSession && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
