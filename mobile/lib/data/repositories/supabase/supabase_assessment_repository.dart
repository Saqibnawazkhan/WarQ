import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../activity_repository.dart';
import '../assessment_repository.dart';
import 'supabase_repository_base.dart';

/// Assessments and marks backed by Supabase.
///
/// Marks are saved through the `save_marks` function rather than row by row,
/// for the same reason attendance is: a screenful of marks is one act of
/// grading, and half of it arriving is worse than none of it.
///
/// `marks` has no surrogate key — it is keyed by (assessment_id, student_id) —
/// so a mark's id in the app is those two joined by a colon.
class SupabaseAssessmentRepository extends SupabaseRepositoryBase
    implements AssessmentRepository {
  SupabaseAssessmentRepository(
    super.client,
    super.bus, {
    required ActivityRepository activity,
  }) : _activity = activity;

  final ActivityRepository _activity;

  SupabaseQueryBuilder get _table => client.from('assessments');
  SupabaseQueryBuilder get _marks => client.from('marks');

  @override
  Future<List<Assessment>> listForClass(String classId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _table
          .select('*')
          .eq('class_id', classId)
          .order('date', ascending: false);
      return rows.map(Rows.assessment).toList(growable: false);
    });
  }

  @override
  Future<List<Assessment>> listForTeacher(String teacherId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _table
          .select('*, classes!inner(teacher_id)')
          .eq('classes.teacher_id', teacherId)
          .order('date', ascending: false);
      return rows.map(Rows.assessment).toList(growable: false);
    });
  }

  @override
  Future<Assessment?> findById(String assessmentId) {
    return read(() async {
      final Map<String, dynamic>? row =
          await _table.select('*').eq('id', assessmentId).maybeSingle();
      return row == null ? null : Rows.assessment(row);
    });
  }

  @override
  Future<Assessment> create({
    required String classId,
    required String userId,
    required AssessmentDraft draft,
  }) async {
    final String name = Format.clean(draft.name);
    if (name.isEmpty) {
      throw const AppFailure.validation('Assessment name is required.');
    }

    final Assessment created = await write(
      () async {
        final Map<String, dynamic> row = await _table.insert(<String, dynamic>{
          'class_id': classId,
          ..._fields(draft, name),
        }).select('*').single();
        return Rows.assessment(row);
      },
      touches: <DataEntity>{DataEntity.assessments},
      classId: classId,
    );

    await _logAssessmentActivity(
      created,
      userId,
      ActivityType.assessmentCreated,
      'Created ${created.name}',
    );
    return created;
  }

  @override
  Future<Assessment> update(String assessmentId, AssessmentDraft draft) async {
    final String name = Format.clean(draft.name);
    if (name.isEmpty) {
      throw const AppFailure.validation('Assessment name is required.');
    }

    final Assessment updated = await write(
      () async {
        final List<Map<String, dynamic>> rows = await _table.update(
          <String, dynamic>{
            ..._fields(draft, name),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ).eq('id', assessmentId).select('*');

        if (rows.isEmpty) throw const AppFailure.notFound('That assessment');
        return Rows.assessment(rows.first);
      },
      touches: <DataEntity>{DataEntity.assessments},
      id: assessmentId,
    );

    await _logAssessmentActivity(
      updated,
      requireUserId,
      ActivityType.assessmentUpdated,
      'Updated ${updated.name}',
    );
    return updated;
  }

  @override
  Future<void> delete(String assessmentId) async {
    final Assessment? existing = await findById(assessmentId);
    if (existing == null) return;

    // The marks cascade from the assessment's foreign key.
    await write(
      () => _table.delete().eq('id', assessmentId),
      touches: <DataEntity>{DataEntity.assessments, DataEntity.marks},
      id: assessmentId,
      classId: existing.classId,
    );

    await _logAssessmentActivity(
      existing,
      requireUserId,
      ActivityType.assessmentDeleted,
      'Deleted ${existing.name}',
    );
  }

  @override
  Future<Map<String, AssessmentMark>> marksForAssessment(String assessmentId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _marks
          .select('*, assessments!inner(class_id)')
          .eq('assessment_id', assessmentId);
      return <String, AssessmentMark>{
        for (final AssessmentMark mark in _toMarks(rows)) mark.studentId: mark,
      };
    });
  }

  @override
  Future<List<AssessmentMark>> marksForClass(String classId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _marks
          .select('*, assessments!inner(class_id)')
          .eq('assessments.class_id', classId);
      return _toMarks(rows);
    });
  }

  @override
  Future<List<AssessmentMark>> marksForStudent(
    String studentId, {
    String? classId,
  }) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _marks
          .select('*, assessments!inner(class_id)')
          .eq('student_id', studentId);
      if (classId != null) {
        query = query.eq('assessments.class_id', classId);
      }
      return _toMarks(await query);
    });
  }

  @override
  Future<void> saveMarks({
    required String assessmentId,
    required List<MarkEntry> entries,
  }) async {
    final Assessment? assessment = await findById(assessmentId);
    if (assessment == null) throw const AppFailure.notFound('That assessment');

    await write(
      () => client.rpc<Map<String, dynamic>>(
        'save_marks',
        params: <String, dynamic>{
          'p_assessment_id': assessmentId,
          'p_entries': <Map<String, dynamic>>[
            for (final MarkEntry entry in entries)
              <String, dynamic>{
                'student_id': entry.studentId,
                // Null clears the box. An absent student carries no score by
                // construction, so the two are never sent together.
                'score': entry.absent ? null : entry.marksObtained,
                'absent': entry.absent,
                'remarks': Format.cleanOrNull(entry.remarks),
              },
          ],
        },
      ),
      touches: <DataEntity>{DataEntity.marks},
      id: assessmentId,
      classId: assessment.classId,
    );

    await _logAssessmentActivity(
      assessment,
      requireUserId,
      ActivityType.marksEntered,
      'Entered marks for ${assessment.name}',
    );
  }

  @override
  Future<void> deleteMark(String markId) async {
    final int split = markId.indexOf(':');
    if (split <= 0 || split == markId.length - 1) {
      throw const AppFailure.validation('That mark could not be identified.');
    }

    await write(
      () => _marks
          .delete()
          .eq('assessment_id', markId.substring(0, split))
          .eq('student_id', markId.substring(split + 1)),
      touches: <DataEntity>{DataEntity.marks},
      id: markId,
    );
  }

  @override
  Future<Map<String, int>> gradedCounts(Iterable<String> assessmentIds) {
    final Set<String> wanted = assessmentIds.toSet();
    final Map<String, int> counts = <String, int>{
      for (final String id in wanted) id: 0,
    };
    if (wanted.isEmpty) return Future<Map<String, int>>.value(counts);

    return read(() async {
      // A recorded absence counts as graded: the teacher has decided, there is
      // simply no number. Only an untouched box is ungraded, and those have no
      // row at all.
      final List<Map<String, dynamic>> rows = await _marks
          .select('assessment_id, score, absent')
          .inFilter('assessment_id', wanted.toList());

      for (final Map<String, dynamic> row in rows) {
        if (row['score'] == null && !Rows.boolean(row, 'absent')) continue;
        final String id = Rows.str(row, 'assessment_id');
        if (!counts.containsKey(id)) continue;
        counts[id] = counts[id]! + 1;
      }
      return counts;
    });
  }

  Map<String, dynamic> _fields(AssessmentDraft draft, String name) =>
      <String, dynamic>{
        'name': name,
        'type': Rows.assessmentTypeToDb(draft.type),
        'date': AppDate.toIso(draft.date),
        'total_marks': draft.totalMarks,
        'custom_type_label': Format.cleanOrNull(draft.customTypeLabel),
        'description': Format.cleanOrNull(draft.description),
        'weight': draft.weight,
      };

  /// The class id lives on the assessment, and [AssessmentMark] carries it, so
  /// the parent is embedded rather than fetched again per mark.
  List<AssessmentMark> _toMarks(List<Map<String, dynamic>> rows) {
    return rows.map((Map<String, dynamic> row) {
      final Map<String, dynamic> assessment =
          (row['assessments'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};
      return Rows.assessmentMark(
        row,
        classId: Rows.str(assessment, 'class_id'),
      );
    }).toList();
  }

  Future<void> _logAssessmentActivity(
    Assessment subject,
    String actorUserId,
    ActivityType type,
    String summary,
  ) async {
    final Map<String, dynamic>? schoolClass = await read(
      () => client
          .from('classes')
          .select('organization_id')
          .eq('id', subject.classId)
          .maybeSingle(),
    );

    await _activity.record(
      actorUserId: actorUserId,
      organizationId: schoolClass == null
          ? null
          : Rows.strOrNull(schoolClass, 'organization_id'),
      type: type,
      summary: summary,
      entityType: 'assessment',
      entityId: subject.id,
      classId: subject.classId,
    );
  }
}
