import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/error/failure.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/data/repositories/assessment_repository.dart';
import 'package:edu_manager/data/repositories/student_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late AppDependencies deps;
  late AppUser teacher;
  late SchoolClass schoolClass;

  setUp(() async {
    deps = await createTestDependencies();
    teacher = await registerTestTeacher(deps);
    schoolClass = await createTestClass(deps, teacher);
  });

  tearDown(() async => deps.dispose());

  group('creation', () {
    test('only the name is required', () async {
      final Student student = await deps.students.create(
        teacherId: teacher.id,
        classId: schoolClass.id,
        draft: const StudentDraft(fullName: 'Ahmed Bilal'),
      );

      expect(student.fullName, 'Ahmed Bilal');
      expect(student.rollNumber, isNull);
      expect(student.studentPhone, isNull);
      expect(student.fatherPhone, isNull);
      expect(student.motherPhone, isNull);
      expect(student.hasAnyContact, isFalse);
    });

    test('rejects a blank name', () {
      expect(
        () => deps.students.create(
          teacherId: teacher.id,
          draft: const StudentDraft(fullName: '   '),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            FailureCode.validation,
          ),
        ),
      );
    });

    test('normalises whitespace in the name', () async {
      final Student student = await deps.students.create(
        teacherId: teacher.id,
        draft: const StudentDraft(fullName: '  Ayesha    Siddiqui  '),
      );
      expect(student.fullName, 'Ayesha Siddiqui');
    });

    test('collects only the contact numbers that were provided', () async {
      final Student student = await deps.students.create(
        teacherId: teacher.id,
        draft: const StudentDraft(
          fullName: 'Hira Nawaz',
          fatherPhone: '+92 300 1112222',
          motherPhone: '   ',
        ),
      );

      expect(student.contactNumbers, hasLength(1));
      expect(student.contactNumbers.single.relation, RecipientRelation.father);
      expect(student.motherPhone, isNull);
    });
  });

  group('A–Z ordering', () {
    test('class roster comes back alphabetically regardless of insert order',
        () async {
      for (final String name in <String>[
        'Zain Abbas',
        'ayesha siddiqui',
        'Musa Rehman',
        'Bilal Hussain',
      ]) {
        await addTestStudent(deps, teacher, schoolClass, name: name);
      }

      final List<Student> roster =
          await deps.students.listForClass(schoolClass.id);

      expect(
        roster.map((Student s) => s.fullName).toList(),
        <String>['ayesha siddiqui', 'Bilal Hussain', 'Musa Rehman', 'Zain Abbas'],
      );
    });

    test('section letters group non-alphabetic names under #', () async {
      final Student numeric = await deps.students.create(
        teacherId: teacher.id,
        draft: const StudentDraft(fullName: '3rd Row Student'),
      );
      expect(numeric.sectionLetter, '#');

      final Student normal = await deps.students.create(
        teacherId: teacher.id,
        draft: const StudentDraft(fullName: 'kiran aslam'),
      );
      expect(normal.sectionLetter, 'K');
    });
  });

  group('enrollment', () {
    test('a student can belong to several classes', () async {
      final SchoolClass second =
          await createTestClass(deps, teacher, name: 'Database Systems');
      final Student student =
          await addTestStudent(deps, teacher, schoolClass, name: 'Noor Fatima');

      await deps.students.enroll(classId: second.id, studentId: student.id);

      expect(await deps.students.classIdsFor(student.id), hasLength(2));
      expect(await deps.students.listForClass(second.id), hasLength(1));
    });

    test('enrolling twice does not create a duplicate', () async {
      final Student student =
          await addTestStudent(deps, teacher, schoolClass, name: 'Noor Fatima');

      await deps.students.enroll(
        classId: schoolClass.id,
        studentId: student.id,
      );

      final List<ClassEnrollment> enrollments =
          await deps.students.enrollmentsForClass(schoolClass.id);
      expect(enrollments.where((ClassEnrollment e) => e.active), hasLength(1));
    });

    test('unenrolling keeps the student record and their history', () async {
      final Student student =
          await addTestStudent(deps, teacher, schoolClass, name: 'Noor Fatima');
      final Assessment assessment =
          await createTestAssessment(deps, teacher, schoolClass);
      await deps.assessments.saveMarks(
        assessmentId: assessment.id,
        entries: <MarkEntry>[MarkEntry(studentId: student.id, marksObtained: 15)],
      );

      await deps.students.unenroll(
        classId: schoolClass.id,
        studentId: student.id,
      );

      expect(await deps.students.listForClass(schoolClass.id), isEmpty);
      expect(await deps.students.findById(student.id), isNotNull);
      expect(
        await deps.assessments.marksForStudent(student.id),
        hasLength(1),
        reason: 'history is preserved when a student leaves a class',
      );
    });

    test('re-enrolling a previously removed student reactivates the row',
        () async {
      final Student student =
          await addTestStudent(deps, teacher, schoolClass, name: 'Noor Fatima');
      await deps.students
          .unenroll(classId: schoolClass.id, studentId: student.id);
      await deps.students.enroll(classId: schoolClass.id, studentId: student.id);

      final List<ClassEnrollment> enrollments =
          await deps.students.enrollmentsForClass(schoolClass.id);
      expect(enrollments, hasLength(1));
      expect(enrollments.single.active, isTrue);
    });
  });

  group('deletion', () {
    test('deleting a student removes their attendance and marks', () async {
      final Student student =
          await addTestStudent(deps, teacher, schoolClass, name: 'Noor Fatima');
      final Assessment assessment =
          await createTestAssessment(deps, teacher, schoolClass);
      await deps.assessments.saveMarks(
        assessmentId: assessment.id,
        entries: <MarkEntry>[MarkEntry(studentId: student.id, marksObtained: 15)],
      );
      await deps.attendance.save(
        classId: schoolClass.id,
        date: DateTime.now(),
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{student.id: AttendanceStatus.present},
      );

      await deps.students.delete(student.id);

      expect(await deps.students.findById(student.id), isNull);
      expect(await deps.assessments.marksForStudent(student.id), isEmpty);
      expect(await deps.attendance.recordsForStudent(student.id), isEmpty);
    });
  });

  group('class deletion cascade', () {
    test('removes class-scoped data but keeps the students', () async {
      final Student student =
          await addTestStudent(deps, teacher, schoolClass, name: 'Noor Fatima');
      await createTestAssessment(deps, teacher, schoolClass);
      await deps.attendance.save(
        classId: schoolClass.id,
        date: DateTime.now(),
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{student.id: AttendanceStatus.absent},
      );

      await deps.classes.delete(schoolClass.id);

      expect(await deps.classes.findById(schoolClass.id), isNull);
      expect(await deps.assessments.listForClass(schoolClass.id), isEmpty);
      expect(await deps.attendance.sessionsForClass(schoolClass.id), isEmpty);
      expect(
        await deps.students.findById(student.id),
        isNotNull,
        reason: 'students belong to the teacher, not the class',
      );
    });
  });
}
