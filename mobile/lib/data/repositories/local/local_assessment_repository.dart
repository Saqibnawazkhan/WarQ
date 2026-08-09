import '../../../core/error/failure.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../activity_repository.dart';
import '../assessment_repository.dart';

/// On-device implementation of [AssessmentRepository].
class LocalAssessmentRepository implements AssessmentRepository {
  LocalAssessmentRepository(this._db, {required ActivityRepository activity})
      : _activity = activity;

  final LocalDatabase _db;
  final ActivityRepository _activity;

  @override
  Future<List<Assessment>> listForClass(String classId) async {
    final List<Assessment> items =
        _db.assessments.where((Assessment a) => a.classId == classId).toList();
    _sortByDate(items);
    return items;
  }

  @override
  Future<List<Assessment>> listForTeacher(String teacherId) async {
    final Set<String> classIds = _db.classes
        .where((SchoolClass c) => c.teacherId == teacherId)
        .map((SchoolClass c) => c.id)
        .toSet();
    final List<Assessment> items = _db.assessments
        .where((Assessment a) => classIds.contains(a.classId))
        .toList();
    _sortByDate(items);
    return items;
  }

  @override
  Future<Assessment?> findById(String assessmentId) async =>
      _db.assessments.byId(assessmentId);

  @override
  Future<Assessment> create({
    required String classId,
    required String userId,
    required AssessmentDraft draft,
  }) async {
    final SchoolClass? schoolClass = _db.classes.byId(classId);
    if (schoolClass == null) throw const AppFailure.notFound('That class');
    _validate(draft);

    final Assessment assessment = Assessment(
      id: IdGenerator.generate('asm'),
      classId: classId,
      name: Format.clean(draft.name),
      type: draft.type,
      date: AppDate.dateOnly(draft.date),
      totalMarks: draft.totalMarks,
      createdByUserId: userId,
      createdAt: DateTime.now(),
      customTypeLabel: draft.type == AssessmentType.custom
          ? Format.cleanOrNull(draft.customTypeLabel)
          : null,
      description: Format.cleanOrNull(draft.description),
      weight: draft.weight,
    );

    await _db.assessments.put(assessment);
    _db.bus.emit(DataEntity.assessments, classId: classId);

    await _activity.record(
      actorUserId: userId,
      actorName: _db.users.byId(userId)?.displayName,
      organizationId: schoolClass.organizationId,
      type: ActivityType.assessmentCreated,
      summary: 'Created ${assessment.typeLabel.toLowerCase()} '
          '"${assessment.name}" for ${schoolClass.name}',
      detail: 'Total marks: ${Format.marks(assessment.totalMarks)}',
      entityType: 'assessment',
      entityId: assessment.id,
      classId: classId,
    );
    return assessment;
  }

  @override
  Future<Assessment> update(String assessmentId, AssessmentDraft draft) async {
    final Assessment? existing = _db.assessments.byId(assessmentId);
    if (existing == null) throw const AppFailure.notFound('That assessment');
    _validate(draft);

    // Lowering the total below an already recorded score would silently create
    // an impossible percentage, so block it with an actionable message.
    final double highest = _db.marks
        .where((AssessmentMark m) => m.assessmentId == assessmentId)
        .map((AssessmentMark m) => m.marksObtained ?? 0)
        .fold<double>(0, (double a, double b) => a > b ? a : b);
    if (draft.totalMarks < highest) {
      throw AppFailure.validation(
        'Total marks cannot be lower than the highest recorded score '
        '(${Format.marks(highest)}).',
      );
    }

    final String? description = Format.cleanOrNull(draft.description);
    final String? customLabel = draft.type == AssessmentType.custom
        ? Format.cleanOrNull(draft.customTypeLabel)
        : null;

    final Assessment updated = existing.copyWith(
      name: Format.clean(draft.name),
      type: draft.type,
      customTypeLabel: customLabel,
      clearCustomTypeLabel: customLabel == null,
      date: AppDate.dateOnly(draft.date),
      totalMarks: draft.totalMarks,
      description: description,
      clearDescription: description == null,
      weight: draft.weight,
      clearWeight: draft.weight == null,
      updatedAt: DateTime.now(),
    );

    await _db.assessments.put(updated);
    _db.bus.emit(DataEntity.assessments, classId: existing.classId);

    final SchoolClass? schoolClass = _db.classes.byId(existing.classId);
    await _activity.record(
      actorUserId: existing.createdByUserId,
      actorName: _db.users.byId(existing.createdByUserId)?.displayName,
      organizationId: schoolClass?.organizationId,
      type: ActivityType.assessmentUpdated,
      summary: 'Updated "${updated.name}" in ${schoolClass?.name ?? 'a class'}',
      entityType: 'assessment',
      entityId: assessmentId,
      classId: existing.classId,
    );
    return updated;
  }

  @override
  Future<void> delete(String assessmentId) async {
    final Assessment? existing = _db.assessments.byId(assessmentId);
    if (existing == null) return;

    await _db.marks.deleteWhere((AssessmentMark m) => m.assessmentId == assessmentId);
    await _db.assessments.delete(assessmentId);
    _db.bus
      ..emit(DataEntity.assessments, classId: existing.classId)
      ..emit(DataEntity.marks, classId: existing.classId);

    final SchoolClass? schoolClass = _db.classes.byId(existing.classId);
    await _activity.record(
      actorUserId: existing.createdByUserId,
      actorName: _db.users.byId(existing.createdByUserId)?.displayName,
      organizationId: schoolClass?.organizationId,
      type: ActivityType.assessmentDeleted,
      summary: 'Deleted "${existing.name}" from ${schoolClass?.name ?? 'a class'}',
      entityType: 'assessment',
      entityId: assessmentId,
      classId: existing.classId,
    );
  }

  @override
  Future<Map<String, AssessmentMark>> marksForAssessment(
    String assessmentId,
  ) async {
    return <String, AssessmentMark>{
      for (final AssessmentMark mark
          in _db.marks.where((AssessmentMark m) => m.assessmentId == assessmentId))
        mark.studentId: mark,
    };
  }

  @override
  Future<List<AssessmentMark>> marksForClass(String classId) async {
    return _db.marks
        .where((AssessmentMark m) => m.classId == classId)
        .toList(growable: false);
  }

  @override
  Future<List<AssessmentMark>> marksForStudent(
    String studentId, {
    String? classId,
  }) async {
    return _db.marks
        .where((AssessmentMark m) =>
            m.studentId == studentId && (classId == null || m.classId == classId))
        .toList(growable: false);
  }

  @override
  Future<void> saveMarks({
    required String assessmentId,
    required List<MarkEntry> entries,
  }) async {
    final Assessment? assessment = _db.assessments.byId(assessmentId);
    if (assessment == null) throw const AppFailure.notFound('That assessment');

    final Map<String, AssessmentMark> existing =
        await marksForAssessment(assessmentId);
    final DateTime now = DateTime.now();
    final List<AssessmentMark> toWrite = <AssessmentMark>[];
    final List<String> toDelete = <String>[];
    bool hadPreviousMarks = existing.values.any((AssessmentMark m) => m.isGraded);

    for (final MarkEntry entry in entries) {
      final AssessmentMark? before = existing[entry.studentId];
      final double? value = entry.marksObtained;

      if (value != null && (value < 0 || value > assessment.totalMarks)) {
        throw AppFailure.validation(
          'Marks must be between 0 and ${Format.marks(assessment.totalMarks)}.',
        );
      }

      final bool isBlank =
          value == null && !entry.absent && Format.cleanOrNull(entry.remarks) == null;
      if (isBlank) {
        // Clearing a field removes the row so it reads as "not graded".
        if (before != null) toDelete.add(before.id);
        continue;
      }

      toWrite.add(
        AssessmentMark(
          id: before?.id ?? IdGenerator.generate('mrk'),
          assessmentId: assessmentId,
          classId: assessment.classId,
          studentId: entry.studentId,
          recordedAt: before?.recordedAt ?? now,
          marksObtained: entry.absent ? null : value,
          remarks: Format.cleanOrNull(entry.remarks),
          absent: entry.absent,
          updatedAt: before == null ? null : now,
        ),
      );
    }

    for (final String id in toDelete) {
      await _db.marks.delete(id);
    }
    if (toWrite.isNotEmpty) await _db.marks.putAll(toWrite);
    _db.bus.emit(DataEntity.marks, classId: assessment.classId);

    final SchoolClass? schoolClass = _db.classes.byId(assessment.classId);
    final int gradedCount = toWrite.where((AssessmentMark m) => m.isGraded).length;
    await _activity.record(
      actorUserId: assessment.createdByUserId,
      actorName: _db.users.byId(assessment.createdByUserId)?.displayName,
      organizationId: schoolClass?.organizationId,
      type: hadPreviousMarks ? ActivityType.marksUpdated : ActivityType.marksEntered,
      summary: '${hadPreviousMarks ? 'Updated' : 'Entered'} marks for '
          '"${assessment.name}"',
      detail: '$gradedCount student${gradedCount == 1 ? '' : 's'} graded',
      entityType: 'assessment',
      entityId: assessmentId,
      classId: assessment.classId,
    );
  }

  @override
  Future<void> deleteMark(String markId) async {
    final AssessmentMark? mark = _db.marks.byId(markId);
    if (mark == null) return;
    await _db.marks.delete(markId);
    _db.bus.emit(DataEntity.marks, classId: mark.classId);
  }

  @override
  Future<Map<String, int>> gradedCounts(Iterable<String> assessmentIds) async {
    final Set<String> wanted = assessmentIds.toSet();
    final Map<String, int> counts = <String, int>{
      for (final String id in wanted) id: 0,
    };
    for (final AssessmentMark mark in _db.marks.all) {
      if (!wanted.contains(mark.assessmentId)) continue;
      if (!mark.isGraded) continue;
      counts[mark.assessmentId] = (counts[mark.assessmentId] ?? 0) + 1;
    }
    return counts;
  }

  void _validate(AssessmentDraft draft) {
    if (Format.clean(draft.name).isEmpty) {
      throw const AppFailure.validation('Assessment name is required.');
    }
    if (draft.totalMarks <= 0) {
      throw const AppFailure.validation('Total marks must be greater than zero.');
    }
    if (draft.type == AssessmentType.custom &&
        Format.cleanOrNull(draft.customTypeLabel) == null) {
      throw const AppFailure.validation('Give your custom assessment a type name.');
    }
  }

  void _sortByDate(List<Assessment> items) {
    items.sort((Assessment a, Assessment b) {
      final int byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : b.createdAt.compareTo(a.createdAt);
    });
  }
}
