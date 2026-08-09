import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../activity_repository.dart';
import '../student_repository.dart';

/// On-device implementation of [StudentRepository].
///
/// The A–Z ordering required by the spec is applied here rather than in the UI,
/// so every consumer — list screen, report, PDF — sees the same order.
class LocalStudentRepository implements StudentRepository {
  LocalStudentRepository(this._db, {required ActivityRepository activity})
      : _activity = activity;

  final LocalDatabase _db;
  final ActivityRepository _activity;

  @override
  Future<List<Student>> listForClass(String classId) async {
    final Set<String> studentIds = _db.enrollments
        .where((ClassEnrollment e) => e.classId == classId && e.active)
        .map((ClassEnrollment e) => e.studentId)
        .toSet();
    final List<Student> students = _db.students
        .where((Student s) => studentIds.contains(s.id))
        .toList();
    return sortAlphabetically(students);
  }

  @override
  Future<List<Student>> listForTeacher(String teacherId) async {
    return sortAlphabetically(
      _db.students.where((Student s) => s.ownerTeacherId == teacherId).toList(),
    );
  }

  @override
  Future<List<Student>> listForOrganization(String organizationId) async {
    return sortAlphabetically(
      _db.students
          .where((Student s) => s.organizationId == organizationId)
          .toList(),
    );
  }

  @override
  Future<Student?> findById(String studentId) async => _db.students.byId(studentId);

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

    final Student student = Student(
      id: IdGenerator.generate('stu'),
      ownerTeacherId: teacherId,
      fullName: fullName,
      createdAt: DateTime.now(),
      organizationId: organizationId,
      rollNumber: Format.cleanOrNull(draft.rollNumber),
      studentPhone: Format.cleanOrNull(draft.studentPhone),
      fatherPhone: Format.cleanOrNull(draft.fatherPhone),
      motherPhone: Format.cleanOrNull(draft.motherPhone),
      guardianName: Format.cleanOrNull(draft.guardianName),
      email: Format.cleanOrNull(draft.email)?.toLowerCase(),
      address: Format.cleanOrNull(draft.address),
      notes: Format.cleanOrNull(draft.notes),
    );

    await _db.students.put(student);
    if (classId != null) {
      await _createEnrollment(classId: classId, studentId: student.id);
    }
    _db.bus
      ..emit(DataEntity.students, id: student.id)
      ..emit(DataEntity.enrollments, classId: classId);

    final AppUser? teacher = _db.users.byId(teacherId);
    final SchoolClass? schoolClass = classId == null ? null : _db.classes.byId(classId);
    await _activity.record(
      actorUserId: teacherId,
      actorName: teacher?.displayName,
      organizationId: organizationId,
      type: ActivityType.studentAdded,
      summary: schoolClass == null
          ? 'Added student ${student.fullName}'
          : 'Added ${student.fullName} to ${schoolClass.name}',
      entityType: 'student',
      entityId: student.id,
      classId: classId,
    );
    return student;
  }

  @override
  Future<Student> update(String studentId, StudentDraft draft) async {
    final Student? existing = _db.students.byId(studentId);
    if (existing == null) throw const AppFailure.notFound('That student');

    final String fullName = Format.clean(draft.fullName);
    if (fullName.isEmpty) {
      throw const AppFailure.validation('Student name is required.');
    }

    final String? rollNumber = Format.cleanOrNull(draft.rollNumber);
    final String? studentPhone = Format.cleanOrNull(draft.studentPhone);
    final String? fatherPhone = Format.cleanOrNull(draft.fatherPhone);
    final String? motherPhone = Format.cleanOrNull(draft.motherPhone);
    final String? guardianName = Format.cleanOrNull(draft.guardianName);
    final String? email = Format.cleanOrNull(draft.email)?.toLowerCase();
    final String? address = Format.cleanOrNull(draft.address);
    final String? notes = Format.cleanOrNull(draft.notes);

    final Student updated = existing.copyWith(
      fullName: fullName,
      rollNumber: rollNumber,
      clearRollNumber: rollNumber == null,
      studentPhone: studentPhone,
      clearStudentPhone: studentPhone == null,
      fatherPhone: fatherPhone,
      clearFatherPhone: fatherPhone == null,
      motherPhone: motherPhone,
      clearMotherPhone: motherPhone == null,
      guardianName: guardianName,
      clearGuardianName: guardianName == null,
      email: email,
      clearEmail: email == null,
      address: address,
      clearAddress: address == null,
      notes: notes,
      clearNotes: notes == null,
      updatedAt: DateTime.now(),
    );

    await _db.students.put(updated);
    _db.bus.emit(DataEntity.students, id: studentId);

    final AppUser? teacher = _db.users.byId(existing.ownerTeacherId);
    await _activity.record(
      actorUserId: existing.ownerTeacherId,
      actorName: teacher?.displayName,
      organizationId: existing.organizationId,
      type: ActivityType.studentUpdated,
      summary: 'Updated student ${updated.fullName}',
      entityType: 'student',
      entityId: studentId,
    );
    return updated;
  }

  @override
  Future<void> delete(String studentId) async {
    final Student? existing = _db.students.byId(studentId);
    if (existing == null) return;

    await _db.attendanceRecords
        .deleteWhere((AttendanceRecord r) => r.studentId == studentId);
    await _db.marks.deleteWhere((AssessmentMark m) => m.studentId == studentId);
    await _db.enrollments
        .deleteWhere((ClassEnrollment e) => e.studentId == studentId);
    await _db.students.delete(studentId);

    _db.bus.emitAll(<DataEntity>{
      DataEntity.students,
      DataEntity.enrollments,
      DataEntity.attendance,
      DataEntity.marks,
    });

    final AppUser? teacher = _db.users.byId(existing.ownerTeacherId);
    await _activity.record(
      actorUserId: existing.ownerTeacherId,
      actorName: teacher?.displayName,
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
    final Student? student = _db.students.byId(studentId);
    if (student == null) throw const AppFailure.notFound('That student');
    if (_db.classes.byId(classId) == null) {
      throw const AppFailure.notFound('That class');
    }

    final ClassEnrollment enrollment =
        await _createEnrollment(classId: classId, studentId: studentId);
    _db.bus.emit(DataEntity.enrollments, classId: classId);

    final SchoolClass? schoolClass = _db.classes.byId(classId);
    await _activity.record(
      actorUserId: student.ownerTeacherId,
      actorName: _db.users.byId(student.ownerTeacherId)?.displayName,
      organizationId: student.organizationId,
      type: ActivityType.studentEnrolled,
      summary: 'Enrolled ${student.fullName} in ${schoolClass?.name ?? 'a class'}',
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
    final ClassEnrollment? enrollment = _db.enrollments.firstWhereOrNull(
      (ClassEnrollment e) =>
          e.classId == classId && e.studentId == studentId && e.active,
    );
    if (enrollment == null) return;

    // Soft-detach so historical attendance and marks stay intact.
    await _db.enrollments.put(
      enrollment.copyWith(active: false, unenrolledAt: DateTime.now()),
    );
    _db.bus.emit(DataEntity.enrollments, classId: classId);

    final Student? student = _db.students.byId(studentId);
    final SchoolClass? schoolClass = _db.classes.byId(classId);
    if (student != null) {
      await _activity.record(
        actorUserId: student.ownerTeacherId,
        actorName: _db.users.byId(student.ownerTeacherId)?.displayName,
        organizationId: student.organizationId,
        type: ActivityType.studentUnenrolled,
        summary:
            'Removed ${student.fullName} from ${schoolClass?.name ?? 'a class'}',
        entityType: 'student',
        entityId: studentId,
        classId: classId,
      );
    }
  }

  @override
  Future<List<String>> classIdsFor(String studentId) async {
    return _db.enrollments
        .where((ClassEnrollment e) => e.studentId == studentId && e.active)
        .map((ClassEnrollment e) => e.classId)
        .toList(growable: false);
  }

  @override
  Future<List<ClassEnrollment>> enrollmentsForClass(String classId) async {
    return _db.enrollments
        .where((ClassEnrollment e) => e.classId == classId)
        .toList(growable: false);
  }

  /// Shared A–Z comparator. Falls back to roll number when names collide so
  /// the order is stable between rebuilds.
  static List<Student> sortAlphabetically(List<Student> students) {
    students.sort((Student a, Student b) {
      final int byName = a.sortKey.compareTo(b.sortKey);
      if (byName != 0) return byName;
      final String aRoll = a.rollNumber ?? '';
      final String bRoll = b.rollNumber ?? '';
      final int byRoll = aRoll.compareTo(bRoll);
      return byRoll != 0 ? byRoll : a.id.compareTo(b.id);
    });
    return students;
  }

  Future<ClassEnrollment> _createEnrollment({
    required String classId,
    required String studentId,
  }) async {
    final ClassEnrollment? existing = _db.enrollments.firstWhereOrNull(
      (ClassEnrollment e) => e.classId == classId && e.studentId == studentId,
    );
    if (existing != null) {
      if (existing.active) return existing;
      // Re-activate rather than creating a duplicate row.
      final ClassEnrollment revived = ClassEnrollment(
        id: existing.id,
        classId: classId,
        studentId: studentId,
        enrolledAt: DateTime.now(),
      );
      await _db.enrollments.put(revived);
      return revived;
    }
    final ClassEnrollment enrollment = ClassEnrollment(
      id: IdGenerator.generate('enr'),
      classId: classId,
      studentId: studentId,
      enrolledAt: DateTime.now(),
    );
    await _db.enrollments.put(enrollment);
    return enrollment;
  }
}
