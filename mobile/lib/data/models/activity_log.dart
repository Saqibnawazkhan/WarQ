import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// Append-only audit record.
///
/// Powers the teacher's "Recent activity" list and the organization admin's
/// monitoring feed. Entries are never edited, only added.
class ActivityLog {
  const ActivityLog({
    required this.id,
    required this.actorUserId,
    required this.type,
    required this.summary,
    required this.createdAt,
    this.actorName,
    this.organizationId,
    this.entityType,
    this.entityId,
    this.classId,
    this.detail,
  });

  factory ActivityLog.fromJson(Map<String, dynamic> json) {
    return ActivityLog(
      id: Json.string(json, 'id'),
      actorUserId: Json.string(json, 'actorUserId'),
      type: Json.enumValue(
        json,
        'type',
        ActivityType.values,
        ActivityType.signedIn,
      ),
      summary: Json.string(json, 'summary'),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      actorName: Json.stringOrNull(json, 'actorName'),
      organizationId: Json.stringOrNull(json, 'organizationId'),
      entityType: Json.stringOrNull(json, 'entityType'),
      entityId: Json.stringOrNull(json, 'entityId'),
      classId: Json.stringOrNull(json, 'classId'),
      detail: Json.stringOrNull(json, 'detail'),
    );
  }

  final String id;
  final String actorUserId;
  final ActivityType type;

  /// Pre-rendered one-line description, e.g. "Marked attendance for CS-201".
  final String summary;
  final DateTime createdAt;

  /// Snapshot of the actor's name so the feed stays readable after a rename.
  final String? actorName;
  final String? organizationId;
  final String? entityType;
  final String? entityId;
  final String? classId;
  final String? detail;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'actorUserId': actorUserId,
        'type': type.name,
        'summary': summary,
        'createdAt': createdAt.toIso8601String(),
        'actorName': actorName,
        'organizationId': organizationId,
        'entityType': entityType,
        'entityId': entityId,
        'classId': classId,
        'detail': detail,
      });

  @override
  bool operator ==(Object other) => other is ActivityLog && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
