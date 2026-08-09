import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../activity_repository.dart';

/// On-device audit trail.
class LocalActivityRepository implements ActivityRepository {
  LocalActivityRepository(this._db);

  final LocalDatabase _db;

  /// Keeps the log from growing without bound on a device that is never
  /// synced. Oldest entries are trimmed first.
  static const int _maxEntries = 500;

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
    final ActivityLog log = ActivityLog(
      id: IdGenerator.generate('act'),
      actorUserId: actorUserId,
      type: type,
      summary: summary,
      createdAt: DateTime.now(),
      actorName: actorName,
      organizationId: organizationId,
      entityType: entityType,
      entityId: entityId,
      classId: classId,
      detail: detail,
    );
    await _db.activityLogs.put(log);
    await _trim();
    _db.bus.emit(DataEntity.activity, id: log.id);
    return log;
  }

  @override
  Future<List<ActivityLog>> listForUser(String userId, {int limit = 50}) async {
    return _sorted(
      _db.activityLogs.where((ActivityLog l) => l.actorUserId == userId),
      limit,
    );
  }

  @override
  Future<List<ActivityLog>> listForOrganization(
    String organizationId, {
    int limit = 50,
    String? actorUserId,
  }) async {
    return _sorted(
      _db.activityLogs.where((ActivityLog l) =>
          l.organizationId == organizationId &&
          (actorUserId == null || l.actorUserId == actorUserId)),
      limit,
    );
  }

  @override
  Future<List<ActivityLog>> listForClass(String classId, {int limit = 50}) async {
    return _sorted(
      _db.activityLogs.where((ActivityLog l) => l.classId == classId),
      limit,
    );
  }

  @override
  Future<ActivityLog?> lastActivityFor(String userId, {ActivityType? type}) async {
    final List<ActivityLog> matches = _sorted(
      _db.activityLogs.where((ActivityLog l) =>
          l.actorUserId == userId && (type == null || l.type == type)),
      1,
    );
    return matches.isEmpty ? null : matches.first;
  }

  List<ActivityLog> _sorted(Iterable<ActivityLog> input, int limit) {
    final List<ActivityLog> items = input.toList()
      ..sort((ActivityLog a, ActivityLog b) => b.createdAt.compareTo(a.createdAt));
    return limit <= 0 || items.length <= limit
        ? items
        : items.sublist(0, limit);
  }

  Future<void> _trim() async {
    if (_db.activityLogs.length <= _maxEntries) return;
    final List<ActivityLog> ordered = _db.activityLogs.all
      ..sort((ActivityLog a, ActivityLog b) => b.createdAt.compareTo(a.createdAt));
    final Set<String> keep =
        ordered.take(_maxEntries).map((ActivityLog l) => l.id).toSet();
    await _db.activityLogs.deleteWhere((ActivityLog l) => !keep.contains(l.id));
  }
}
