import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../activity_repository.dart';
import '../class_repository.dart';
import 'supabase_repository_base.dart';

/// Classes backed by Supabase.
///
/// Creation goes through the `create_class` function rather than an insert,
/// because the server decides three things the client should not: the
/// organization the class is filed under (taken from the teacher's own profile,
/// never from the request), the colour, and the activity-log entry. The other
/// writes are ordinary updates, so they log their own activity here.
class SupabaseClassRepository extends SupabaseRepositoryBase
    implements ClassRepository {
  SupabaseClassRepository(
    super.client,
    super.bus, {
    required ActivityRepository activity,
  }) : _activity = activity;

  final ActivityRepository _activity;

  static const String _columns = '*';

  SupabaseQueryBuilder get _table => client.from('classes');

  @override
  Future<List<SchoolClass>> listForTeacher(
    String teacherId, {
    bool includeArchived = false,
    bool alphabetical = false,
  }) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _table.select(_columns).eq('teacher_id', teacherId);
      if (!includeArchived) {
        query = query.isFilter('archived_at', null);
      }

      final List<SchoolClass> items = (await query)
          .map(Rows.schoolClass)
          .toList();
      _sort(items, alphabetical: alphabetical);
      return items;
    });
  }

  @override
  Future<List<SchoolClass>> listForOrganization(
    String organizationId, {
    bool includeArchived = false,
  }) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _table.select(_columns).eq('organization_id', organizationId);
      if (!includeArchived) {
        query = query.isFilter('archived_at', null);
      }

      final List<SchoolClass> items = (await query)
          .map(Rows.schoolClass)
          .toList();
      _sort(items, alphabetical: true);
      return items;
    });
  }

  @override
  Future<SchoolClass?> findById(String classId) {
    return read(() async {
      final Map<String, dynamic>? row =
          await _table.select(_columns).eq('id', classId).maybeSingle();
      return row == null ? null : Rows.schoolClass(row);
    });
  }

  @override
  Future<SchoolClass> create({
    required String teacherId,
    required ClassDraft draft,
    String? organizationId,
  }) {
    final String name = Format.clean(draft.name);
    if (name.isEmpty) {
      throw const AppFailure.validation('Class name is required.');
    }

    // teacherId and organizationId are deliberately not sent: the function
    // reads both from the caller's own profile, so a request cannot file a
    // class under someone else's name or organization.
    return write(
      () async {
        final Map<String, dynamic> row = await client.rpc<Map<String, dynamic>>(
          'create_class',
          params: <String, dynamic>{
            'class_name': name,
            'class_section': Format.cleanOrNull(draft.section),
            'class_session': Format.cleanOrNull(draft.session),
            'class_subject': Format.cleanOrNull(draft.subject),
            'class_description': Format.cleanOrNull(draft.description),
          },
        );
        return Rows.schoolClass(row);
      },
      touches: <DataEntity>{DataEntity.classes, DataEntity.activity},
    );
  }

  @override
  Future<SchoolClass> update(String classId, ClassDraft draft) async {
    final String name = Format.clean(draft.name);
    if (name.isEmpty) {
      throw const AppFailure.validation('Class name is required.');
    }

    final SchoolClass updated = await write(
      () async {
        final List<Map<String, dynamic>> rows = await _table.update(
          <String, dynamic>{
            'name': name,
            'subject': Format.cleanOrNull(draft.subject),
            'section': Format.cleanOrNull(draft.section),
            'session': Format.cleanOrNull(draft.session),
            'description': Format.cleanOrNull(draft.description),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ).eq('id', classId).select(_columns);

        // An update that matched nothing is either a class that has gone or one
        // this teacher cannot see. Both read as "not found" from here.
        if (rows.isEmpty) throw const AppFailure.notFound('That class');
        return Rows.schoolClass(rows.first);
      },
      touches: <DataEntity>{DataEntity.classes},
      id: classId,
      classId: classId,
    );

    await _logClassActivity(
      updated,
      ActivityType.classUpdated,
      'Updated class ${updated.name}',
    );
    return updated;
  }

  @override
  Future<SchoolClass> setArchived(String classId, bool archived) {
    return write(
      () async {
        final List<Map<String, dynamic>> rows = await _table.update(
          <String, dynamic>{
            'archived_at':
                archived ? DateTime.now().toUtc().toIso8601String() : null,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ).eq('id', classId).select(_columns);

        if (rows.isEmpty) throw const AppFailure.notFound('That class');
        return Rows.schoolClass(rows.first);
      },
      touches: <DataEntity>{DataEntity.classes},
      id: classId,
      classId: classId,
    );
  }

  @override
  Future<void> delete(String classId) async {
    // Read first, so the activity entry can name the class after it is gone.
    final SchoolClass? existing = await findById(classId);
    if (existing == null) return;

    // Enrolments, attendance and assessments all cascade from the foreign key.
    // Students survive because they belong to the teacher, not to the class.
    await write(
      () => _table.delete().eq('id', classId),
      touches: <DataEntity>{
        DataEntity.classes,
        DataEntity.enrollments,
        DataEntity.attendance,
        DataEntity.assessments,
        DataEntity.marks,
      },
      id: classId,
      classId: classId,
    );

    await _logClassActivity(
      existing,
      ActivityType.classDeleted,
      'Deleted class ${existing.name}',
    );
  }

  @override
  Future<Map<String, int>> studentCounts(Iterable<String> classIds) {
    final Set<String> wanted = classIds.toSet();
    final Map<String, int> counts = <String, int>{
      for (final String id in wanted) id: 0,
    };
    if (wanted.isEmpty) return Future<Map<String, int>>.value(counts);

    return read(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('class_students')
          .select('class_id')
          .inFilter('class_id', wanted.toList())
          .isFilter('unenrolled_at', null);

      for (final Map<String, dynamic> row in rows) {
        final String id = Rows.str(row, 'class_id');
        if (!counts.containsKey(id)) continue;
        counts[id] = counts[id]! + 1;
      }
      return counts;
    });
  }

  Future<void> _logClassActivity(
    SchoolClass subject,
    ActivityType type,
    String summary,
  ) async {
    // Attributed to whoever is signed in, not to the class's owner: the audit
    // trail's insert policy requires actor_id to be the caller, and an entry
    // someone can file under another person's name is not an audit trail.
    await _activity.record(
      actorUserId: requireUserId,
      organizationId: subject.organizationId,
      type: type,
      summary: summary,
      entityType: 'class',
      entityId: subject.id,
      classId: subject.id,
    );
  }

  /// Newest first by default, matching the hub screen; alphabetical where the
  /// caller is showing a browsable list. Sorted here rather than in the query
  /// because the default key is "updated, or created if never updated", which
  /// PostgREST cannot express as an ordering.
  void _sort(List<SchoolClass> items, {required bool alphabetical}) {
    if (alphabetical) {
      items.sort((SchoolClass a, SchoolClass b) =>
          a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    } else {
      items.sort((SchoolClass a, SchoolClass b) {
        final DateTime aAt = a.updatedAt ?? a.createdAt;
        final DateTime bAt = b.updatedAt ?? b.createdAt;
        return bAt.compareTo(aAt);
      });
    }
  }
}
