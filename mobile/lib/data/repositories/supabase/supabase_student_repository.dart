import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../activity_repository.dart';
import '../student_repository.dart';
import 'supabase_repository_base.dart';

/// Students backed by Supabase.
///
/// A student belongs to the teacher who created them, not to a class, so the
/// same person can sit in several of that teacher's classes through the
/// `class_students` join table. Leaving a class is a soft detach, which is what
/// keeps last term's registers and marks readable after a student moves on.
///
/// Phone numbers live in `student_contacts`, one row per relation, so the three
/// optional numbers on [StudentDraft] are written as up to three rows and a
/// cleared number is a deleted row rather than an empty string.
class SupabaseStudentRepository extends SupabaseRepositoryBase
    implements StudentRepository {
  SupabaseStudentRepository(
    super.client,
    super.bus, {
    required ActivityRepository activity,
  }) : _activity = activity;

  final ActivityRepository _activity;

  /// The contacts have to come back with the student: [Rows.student] reads the
  /// three numbers out of the embedded rows.
  static const String _columns = '*, student_contacts(*)';

  SupabaseQueryBuilder get _table => client.from('students');

  @override
  Future<List<Student>> listForClass(String classId) {
    return read(() async {
      // Two steps rather than one embedded query: PostgREST can filter a parent
      // by its children, but not while also excluding children that have been
      // detached, and a student who left the class must not appear.
      final List<String> ids = await _activeStudentIds(classId);
      if (ids.isEmpty) return const <Student>[];

      final List<Map<String, dynamic>> rows =
          await _table.select(_columns).inFilter('id', ids);
      return _sorted(rows);
    });
  }

  @override
  Future<List<Student>> listForTeacher(String teacherId) {
    return read(() async {
      final List<Map<String, dynamic>> rows =
          await _table.select(_columns).eq('teacher_id', teacherId);
      return _sorted(rows);
    });
  }

  @override
  Future<List<Student>> listForOrganization(String organizationId) {
    return read(() async {
      final List<Map<String, dynamic>> rows =
          await _table.select(_columns).eq('organization_id', organizationId);
      return _sorted(rows);
    });
  }

  @override
  Future<Student?> findById(String studentId) {
    return read(() async {
      final Map<String, dynamic>? row =
          await _table.select(_columns).eq('id', studentId).maybeSingle();
      return row == null ? null : Rows.student(row);
    });
  }

  @override
  Future<Student> create({
    required String teacherId,
    required StudentDraft draft,
    String? classId,
    String? organizationId,
  }) async {
    final String fullName = Format.clean(draft.fullName);
    if (fullName.isEmpty) {
      throw const AppFailure.validation('Student name is required.');
    }

    final Student created = await write(
      () async {
        final Map<String, dynamic> row = await _table.insert(<String, dynamic>{
          'teacher_id': teacherId,
          'organization_id': organizationId,
          'full_name': fullName,
          ..._optionalFields(draft),
        }).select(_columns).single();

        final String studentId = Rows.str(row, 'id');
        await _writeContacts(studentId, draft);

        // Re-read so the returned student carries the contacts just written;
        // the insert's own row was selected before they existed.
        return await _requireById(studentId);
      },
      touches: <DataEntity>{DataEntity.students},
    );

    await _activity.record(
      actorUserId: requireUserId,
      organizationId: organizationId,
      type: ActivityType.studentAdded,
      summary: 'Added student ${created.fullName}',
      entityType: 'student',
      entityId: created.id,
      classId: classId,
    );

    if (classId != null) {
      await enroll(classId: classId, studentId: created.id);
    }
    return created;
  }

  @override
  Future<Student> update(String studentId, StudentDraft draft) async {
    final String fullName = Format.clean(draft.fullName);
    if (fullName.isEmpty) {
      throw const AppFailure.validation('Student name is required.');
    }

    final Student updated = await write(
      () async {
        final List<Map<String, dynamic>> rows = await _table.update(
          <String, dynamic>{
            'full_name': fullName,
            ..._optionalFields(draft),
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
        ).eq('id', studentId).select('id');

        if (rows.isEmpty) throw const AppFailure.notFound('That student');
        await _writeContacts(studentId, draft);
        return await _requireById(studentId);
      },
      touches: <DataEntity>{DataEntity.students},
      id: studentId,
    );

    await _activity.record(
      actorUserId: requireUserId,
      organizationId: updated.organizationId,
      type: ActivityType.studentUpdated,
      summary: 'Updated student ${updated.fullName}',
      entityType: 'student',
      entityId: studentId,
    );
    return updated;
  }

  @override
  Future<void> delete(String studentId) async {
    final Student? existing = await findById(studentId);
    if (existing == null) return;

    // Contacts, enrolments, attendance rows and marks all cascade from the
    // foreign key, so this is genuinely one statement.
    await write(
      () => _table.delete().eq('id', studentId),
      touches: <DataEntity>{
        DataEntity.students,
        DataEntity.enrollments,
        DataEntity.attendance,
        DataEntity.marks,
      },
      id: studentId,
    );

    await _activity.record(
      actorUserId: requireUserId,
      organizationId: existing.organizationId,
      type: ActivityType.studentRemoved,
      summary: 'Deleted student ${existing.fullName}',
      entityType: 'student',
      entityId: studentId,
    );
  }

  @override
  Future<ClassEnrollment> enroll({
    required String classId,
    required String studentId,
  }) async {
    final Student? student = await findById(studentId);
    if (student == null) throw const AppFailure.notFound('That student');

    final Map<String, dynamic>? schoolClass = await read(
      () => client.from('classes').select('id, name').eq('id', classId).maybeSingle(),
    );
    if (schoolClass == null) throw const AppFailure.notFound('That class');

    final ClassEnrollment enrollment = await write(
      () async {
        final Map<String, dynamic>? existing = await client
            .from('class_students')
            .select('*')
            .eq('class_id', classId)
            .eq('student_id', studentId)
            .maybeSingle();

        // Already in the class: leave the original enrolment date alone, so the
        // roster does not claim they joined again today.
        if (existing != null && existing['unenrolled_at'] == null) {
          return Rows.enrollment(existing);
        }

        // A returning student reuses their row instead of accumulating a second
        // one, which is what the unique (class_id, student_id) index requires.
        if (existing != null) {
          final Map<String, dynamic> revived = await client
              .from('class_students')
              .update(<String, dynamic>{
                'unenrolled_at': null,
                'enrolled_at': DateTime.now().toUtc().toIso8601String(),
              })
              .eq('id', Rows.str(existing, 'id'))
              .select('*')
              .single();
          return Rows.enrollment(revived);
        }

        final Map<String, dynamic> row = await client
            .from('class_students')
            .insert(<String, dynamic>{
              'class_id': classId,
              'student_id': studentId,
            })
            .select('*')
            .single();
        return Rows.enrollment(row);
      },
      touches: <DataEntity>{DataEntity.enrollments},
      classId: classId,
    );

    await _activity.record(
      actorUserId: requireUserId,
      organizationId: student.organizationId,
      type: ActivityType.studentEnrolled,
      summary: 'Enrolled ${student.fullName} in '
          '${Rows.str(schoolClass, 'name', fallback: 'a class')}',
      entityType: 'student',
      entityId: studentId,
      classId: classId,
    );
    return enrollment;
  }

  @override
  Future<void> unenroll({
    required String classId,
    required String studentId,
  }) async {
    final List<Map<String, dynamic>> detached = await write(
      () => client
          .from('class_students')
          .update(<String, dynamic>{
            'unenrolled_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('class_id', classId)
          .eq('student_id', studentId)
          .isFilter('unenrolled_at', null)
          .select('id'),
      touches: <DataEntity>{DataEntity.enrollments},
      classId: classId,
    );

    // Not enrolled in the first place. Nothing happened, so nothing is logged.
    if (detached.isEmpty) return;

    final Student? student = await findById(studentId);
    if (student == null) return;

    final Map<String, dynamic>? schoolClass = await read(
      () => client.from('classes').select('name').eq('id', classId).maybeSingle(),
    );

    await _activity.record(
      actorUserId: requireUserId,
      organizationId: student.organizationId,
      type: ActivityType.studentUnenrolled,
      summary: 'Removed ${student.fullName} from '
          '${schoolClass == null ? 'a class' : Rows.str(schoolClass, 'name', fallback: 'a class')}',
      entityType: 'student',
      entityId: studentId,
      classId: classId,
    );
  }

  @override
  Future<List<String>> classIdsFor(String studentId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('class_students')
          .select('class_id')
          .eq('student_id', studentId)
          .isFilter('unenrolled_at', null);
      return rows
          .map((Map<String, dynamic> row) => Rows.str(row, 'class_id'))
          .toList(growable: false);
    });
  }

  @override
  Future<List<ClassEnrollment>> enrollmentsForClass(String classId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await client
          .from('class_students')
          .select('*')
          .eq('class_id', classId);
      return rows.map(Rows.enrollment).toList(growable: false);
    });
  }

  /// Ids of students who are in the class right now.
  Future<List<String>> _activeStudentIds(String classId) async {
    final List<Map<String, dynamic>> rows = await client
        .from('class_students')
        .select('student_id')
        .eq('class_id', classId)
        .isFilter('unenrolled_at', null);
    return rows
        .map((Map<String, dynamic> row) => Rows.str(row, 'student_id'))
        .toList(growable: false);
  }

  Future<Student> _requireById(String studentId) async {
    final Map<String, dynamic> row =
        await _table.select(_columns).eq('id', studentId).single();
    return Rows.student(row);
  }

  /// Blank becomes null rather than an empty string, so "not provided" has one
  /// representation and the length checks on these columns never see a value
  /// that is only whitespace.
  Map<String, dynamic> _optionalFields(StudentDraft draft) => <String, dynamic>{
        'roll_no': Format.cleanOrNull(draft.rollNumber),
        'email': Format.cleanOrNull(draft.email),
        'address': Format.cleanOrNull(draft.address),
        'guardian_name': Format.cleanOrNull(draft.guardianName),
        'notes': Format.cleanOrNull(draft.notes),
      };

  /// Replaces the student's numbers with what the draft holds: a number that is
  /// present is written, one that has been cleared has its row removed. Deleting
  /// rather than storing an empty string is what makes "has nobody to call"
  /// answerable with a join, which is how absence alerts find their recipients.
  Future<void> _writeContacts(String studentId, StudentDraft draft) async {
    final Map<RecipientRelation, String?> numbers = <RecipientRelation, String?>{
      RecipientRelation.student: Format.cleanOrNull(draft.studentPhone),
      RecipientRelation.father: Format.cleanOrNull(draft.fatherPhone),
      RecipientRelation.mother: Format.cleanOrNull(draft.motherPhone),
    };

    final List<Map<String, dynamic>> upserts = <Map<String, dynamic>>[];
    final List<String> cleared = <String>[];

    numbers.forEach((RecipientRelation relation, String? phone) {
      final String label = Rows.contactLabelToDb(relation);
      if (phone == null) {
        cleared.add(label);
      } else {
        upserts.add(<String, dynamic>{
          'student_id': studentId,
          'label': label,
          'phone': phone,
        });
      }
    });

    if (upserts.isNotEmpty) {
      await client
          .from('student_contacts')
          .upsert(upserts, onConflict: 'student_id,label');
    }
    if (cleared.isNotEmpty) {
      await client
          .from('student_contacts')
          .delete()
          .eq('student_id', studentId)
          .inFilter('label', cleared);
    }
  }

  /// A to Z by name, which is how every student list in the app is presented.
  List<Student> _sorted(List<Map<String, dynamic>> rows) {
    final List<Student> items = rows.map(Rows.student).toList();
    items.sort((Student a, Student b) =>
        a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase()));
    return items;
  }
}
