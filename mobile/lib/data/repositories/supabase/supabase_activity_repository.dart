import 'package:supabase_flutter/supabase_flutter.dart';

import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../activity_repository.dart';
import 'supabase_repository_base.dart';

/// The audit trail, backed by Supabase.
///
/// Two things about this table shape the code below.
///
/// The column is an enum of five buckets, because that is what the feed filters
/// offer, while the app distinguishes two dozen actions. The bucket goes in the
/// column and the exact action into `meta`, so a filter still works and nothing
/// is lost. [Rows.activityBucket] and [Rows.activityType] are the two halves of
/// that; the database's own functions write only the bucket, and reading falls
/// back to it.
///
/// `actor_name` is stored rather than joined, so the feed still reads correctly
/// after somebody leaves: "Farhan Saeed saved attendance" should not decay into
/// "Someone saved attendance" a year later.
class SupabaseActivityRepository extends SupabaseRepositoryBase
    implements ActivityRepository {
  SupabaseActivityRepository(super.client, super.bus);

  /// The signed-in user's display name, kept for the lifetime of the session.
  /// Nearly every write needs it and it does not change underneath us.
  String? _cachedActorName;
  String? _cachedActorId;

  SupabaseQueryBuilder get _table => client.from('activity_logs');

  @override
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
  }) async {
    final String name = actorName ?? await _actorName(actorUserId);

    return write(
      () async {
        final Map<String, dynamic> row = await _table.insert(<String, dynamic>{
          // Row-level security requires this to be the caller: an audit trail
          // the audited can attribute to somebody else is not one.
          'actor_id': actorUserId,
          'actor_name': name,
          'organization_id': organizationId,
          'type': Rows.activityBucket(type),
          'message': summary,
          'meta': <String, dynamic>{
            'action': type.name,
            if (entityType != null) 'entity_type': entityType,
            if (entityId != null) 'entity_id': entityId,
            if (classId != null) 'class_id': classId,
            if (detail != null) 'detail': detail,
          },
        }).select('*').single();
        return Rows.activityLog(row);
      },
      touches: <DataEntity>{DataEntity.activity},
      classId: classId,
    );
  }

  @override
  Future<List<ActivityLog>> listForUser(String userId, {int limit = 50}) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _table
          .select('*')
          .eq('actor_id', userId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(Rows.activityLog).toList(growable: false);
    });
  }

  @override
  Future<List<ActivityLog>> listForOrganization(
    String organizationId, {
    int limit = 50,
    String? actorUserId,
  }) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _table.select('*').eq('organization_id', organizationId);
      if (actorUserId != null) {
        query = query.eq('actor_id', actorUserId);
      }

      final List<Map<String, dynamic>> rows =
          await query.order('created_at', ascending: false).limit(limit);
      return rows.map(Rows.activityLog).toList(growable: false);
    });
  }

  @override
  Future<List<ActivityLog>> listForClass(String classId, {int limit = 50}) {
    return read(() async {
      // The class id lives in meta rather than a column, because most entries
      // do not belong to a class at all and a column would be mostly null.
      final List<Map<String, dynamic>> rows = await _table
          .select('*')
          .filter('meta->>class_id', 'eq', classId)
          .order('created_at', ascending: false)
          .limit(limit);
      return rows.map(Rows.activityLog).toList(growable: false);
    });
  }

  @override
  Future<ActivityLog?> lastActivityFor(String userId, {ActivityType? type}) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _table.select('*').eq('actor_id', userId);

      // Filtering on the exact action rather than the bucket: the monitoring
      // screen asks "when did they last take a register", and the bucket would
      // also match somebody correcting one.
      if (type != null) {
        query = query.filter('meta->>action', 'eq', type.name);
      }

      final List<Map<String, dynamic>> rows =
          await query.order('created_at', ascending: false).limit(1);
      return rows.isEmpty ? null : Rows.activityLog(rows.first);
    });
  }

  Future<String> _actorName(String actorUserId) async {
    if (_cachedActorId == actorUserId && _cachedActorName != null) {
      return _cachedActorName!;
    }

    // A missing name must not stop the action that is being recorded, so this
    // falls back rather than failing: the column is not-null, and losing the
    // entry entirely would be a worse outcome than a vague one.
    try {
      final Map<String, dynamic>? row = await client
          .from('profiles')
          .select('full_name')
          .eq('id', actorUserId)
          .maybeSingle();
      final String? name = row == null ? null : Rows.strOrNull(row, 'full_name');
      _cachedActorId = actorUserId;
      _cachedActorName = name ?? 'Someone';
    } catch (_) {
      return 'Someone';
    }
    return _cachedActorName!;
  }
}
