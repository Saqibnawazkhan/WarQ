import '../models/models.dart';

/// Append-only audit trail.
abstract class ActivityRepository {
  Future<ActivityLog> record({
    required String actorUserId,
    required ActivityType type,
    required String summary,
    String? actorName,
    String? organizationId,
    String? entityType,
    String? entityId,
    String? classId,
    String? detail,
  });

  Future<List<ActivityLog>> listForUser(String userId, {int limit = 50});

  Future<List<ActivityLog>> listForOrganization(
    String organizationId, {
    int limit = 50,
    String? actorUserId,
  });

  Future<List<ActivityLog>> listForClass(String classId, {int limit = 50});

  /// Most recent entry by a given actor, used on the teacher monitoring screen.
  Future<ActivityLog?> lastActivityFor(String userId, {ActivityType? type});
}
