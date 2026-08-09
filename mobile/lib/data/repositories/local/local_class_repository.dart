import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../activity_repository.dart';
import '../class_repository.dart';

/// On-device implementation of [ClassRepository].
class LocalClassRepository implements ClassRepository {
  LocalClassRepository(this._db, {required ActivityRepository activity})
      : _activity = activity;

  final LocalDatabase _db;
  final ActivityRepository _activity;

  @override
  Future<List<SchoolClass>> listForTeacher(
    String teacherId, {
    bool includeArchived = false,
    bool alphabetical = false,
  }) async {
    final List<SchoolClass> items = _db.classes
        .where((SchoolClass c) =>
            c.teacherId == teacherId && (includeArchived || !c.archived))
        .toList();
    _sort(items, alphabetical: alphabetical);
    return items;
  }

  @override
  Future<List<SchoolClass>> listForOrganization(
    String organizationId, {
    bool includeArchived = false,
  }) async {
    final List<SchoolClass> items = _db.classes
        .where((SchoolClass c) =>
            c.organizationId == organizationId &&
            (includeArchived || !c.archived))
        .toList();
    _sort(items, alphabetical: true);
    return items;
  }

  @override
  Future<SchoolClass?> findById(String classId) async => _db.classes.byId(classId);

  @override
  Future<SchoolClass> create({
    required String teacherId,
    required ClassDraft draft,
    String? organizationId,
  }) async {
    final String name = Format.clean(draft.name);
    if (name.isEmpty) {
      throw const AppFailure.validation('Class name is required.');
    }

    final SchoolClass created = SchoolClass(
      id: IdGenerator.generate('cls'),
      teacherId: teacherId,
      name: name,
      createdAt: DateTime.now(),
      organizationId: organizationId,
      subject: Format.cleanOrNull(draft.subject),
      section: Format.cleanOrNull(draft.section),
      session: Format.cleanOrNull(draft.session),
      description: Format.cleanOrNull(draft.description),
      colorSeed: IdGenerator.generate('seed'),
    );

    await _db.classes.put(created);
    _db.bus.emit(DataEntity.classes, id: created.id);

    final AppUser? teacher = _db.users.byId(teacherId);
    await _activity.record(
      actorUserId: teacherId,
      actorName: teacher?.displayName,
      organizationId: organizationId,
      type: ActivityType.classCreated,
      summary: 'Created class ${created.name}',
      entityType: 'class',
      entityId: created.id,
      classId: created.id,
    );
    return created;
  }

  @override
  Future<SchoolClass> update(String classId, ClassDraft draft) async {
    final SchoolClass? existing = _db.classes.byId(classId);
    if (existing == null) throw const AppFailure.notFound('That class');

    final String name = Format.clean(draft.name);
    if (name.isEmpty) {
      throw const AppFailure.validation('Class name is required.');
    }

    final String? subject = Format.cleanOrNull(draft.subject);
    final String? section = Format.cleanOrNull(draft.section);
    final String? session = Format.cleanOrNull(draft.session);
    final String? description = Format.cleanOrNull(draft.description);

    final SchoolClass updated = existing.copyWith(
      name: name,
      subject: subject,
      clearSubject: subject == null,
      section: section,
      clearSection: section == null,
      session: session,
      clearSession: session == null,
      description: description,
      clearDescription: description == null,
      updatedAt: DateTime.now(),
    );

    await _db.classes.put(updated);
    _db.bus.emit(DataEntity.classes, id: classId);

    final AppUser? teacher = _db.users.byId(existing.teacherId);
    await _activity.record(
      actorUserId: existing.teacherId,
      actorName: teacher?.displayName,
      organizationId: existing.organizationId,
      type: ActivityType.classUpdated,
      summary: 'Updated class ${updated.name}',
      entityType: 'class',
      entityId: classId,
      classId: classId,
    );
    return updated;
  }

  @override
  Future<SchoolClass> setArchived(String classId, bool archived) async {
    final SchoolClass? existing = _db.classes.byId(classId);
    if (existing == null) throw const AppFailure.notFound('That class');
    final SchoolClass updated =
        existing.copyWith(archived: archived, updatedAt: DateTime.now());
    await _db.classes.put(updated);
    _db.bus.emit(DataEntity.classes, id: classId);
    return updated;
  }

  @override
  Future<void> delete(String classId) async {
    final SchoolClass? existing = _db.classes.byId(classId);
    if (existing == null) return;

    // Cascade: everything scoped to the class goes with it. Student records
    // survive because they belong to the teacher, not the class.
    await _db.attendanceRecords
        .deleteWhere((AttendanceRecord r) => r.classId == classId);
    await _db.attendanceSessions
        .deleteWhere((AttendanceSession s) => s.classId == classId);
    await _db.marks.deleteWhere((AssessmentMark m) => m.classId == classId);
    await _db.assessments.deleteWhere((Assessment a) => a.classId == classId);
    await _db.enrollments.deleteWhere((ClassEnrollment e) => e.classId == classId);
    await _db.classes.delete(classId);

    _db.bus.emitAll(<DataEntity>{
      DataEntity.classes,
      DataEntity.enrollments,
      DataEntity.attendance,
      DataEntity.assessments,
      DataEntity.marks,
    });

    final AppUser? teacher = _db.users.byId(existing.teacherId);
    await _activity.record(
      actorUserId: existing.teacherId,
      actorName: teacher?.displayName,
      organizationId: existing.organizationId,
      type: ActivityType.classDeleted,
      summary: 'Deleted class ${existing.name}',
      entityType: 'class',
      entityId: classId,
    );
  }

  @override
  Future<Map<String, int>> studentCounts(Iterable<String> classIds) async {
    final Set<String> wanted = classIds.toSet();
    final Map<String, int> counts = <String, int>{
      for (final String id in wanted) id: 0,
    };
    for (final ClassEnrollment enrollment in _db.enrollments.all) {
      if (!enrollment.active) continue;
      if (!wanted.contains(enrollment.classId)) continue;
      counts[enrollment.classId] = (counts[enrollment.classId] ?? 0) + 1;
    }
    return counts;
  }

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
