import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/data/repositories/assessment_repository.dart';
import 'package:edu_manager/data/repositories/student_repository.dart';
import 'package:edu_manager/domain/services/report_service.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

/// PDF bytes always start with the `%PDF` magic number.
const List<int> _pdfMagic = <int>[0x25, 0x50, 0x44, 0x46];

void main() {
  late AppDependencies deps;
  late AppUser teacher;
  late SchoolClass schoolClass;
  late Student ahmed;

  setUp(() async {
    deps = await createTestDependencies();
    teacher = await registerTestTeacher(deps, fullName: 'Ahmed Raza');
    schoolClass = await createTestClass(deps, teacher);
    ahmed = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Ahmed Bilal',
      rollNumber: 'SE-26-001',
      fatherPhone: '+92 300 1112222',
    );
    await addTestStudent(deps, teacher, schoolClass, name: 'Zain Abbas');

    final Assessment quiz =
        await createTestAssessment(deps, teacher, schoolClass, totalMarks: 20);
    await deps.assessments.saveMarks(
      assessmentId: quiz.id,
      entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 18)],
    );
    await deps.attendance.save(
      classId: schoolClass.id,
      date: DateTime.now(),
      userId: teacher.id,
      statuses: <String, AttendanceStatus>{ahmed.id: AttendanceStatus.present},
    );
  });

  tearDown(() async => deps.dispose());

  test('produces a valid student report PDF', () async {
    final GeneratedReport report = await deps.reports.studentReport(
      studentId: ahmed.id,
      teacher: teacher,
      classId: schoolClass.id,
    );

    expect(report.bytes.length, greaterThan(1000));
    expect(report.bytes.sublist(0, 4), _pdfMagic);
    expect(report.fileName, endsWith('.pdf'));
    expect(report.fileName, contains('student-report'));
    expect(report.fileName, contains('ahmed-bilal'));
    expect(report.isLandscape, isFalse);
    expect(report.title, contains('Ahmed Bilal'));
  });

  test('produces a valid class report PDF in landscape', () async {
    final GeneratedReport report = await deps.reports.classReport(
      classId: schoolClass.id,
      teacher: teacher,
    );

    expect(report.bytes.sublist(0, 4), _pdfMagic);
    expect(report.isLandscape, isTrue);
    expect(report.fileName, contains('class-report'));
    expect(report.subtitle, contains('2 students'));
  });

  test('handles a class with no marks or attendance', () async {
    final SchoolClass empty =
        await createTestClass(deps, teacher, name: 'Fresh Class');
    await addTestStudent(deps, teacher, empty, name: 'New Student');

    final GeneratedReport report = await deps.reports.classReport(
      classId: empty.id,
      teacher: teacher,
    );

    expect(report.bytes.sublist(0, 4), _pdfMagic);
  });

  test('handles a student with no data at all', () async {
    final Student lonely = await deps.students.create(
      teacherId: teacher.id,
      draft: const StudentDraft(fullName: 'Unenrolled Student'),
    );

    final GeneratedReport report = await deps.reports.studentReport(
      studentId: lonely.id,
      teacher: teacher,
    );

    expect(report.bytes.sublist(0, 4), _pdfMagic);
  });

  test('records report generation in the activity log', () async {
    await deps.reports.classReport(classId: schoolClass.id, teacher: teacher);

    final List<ActivityLog> logs = await deps.activity.listForUser(teacher.id);
    expect(
      logs.any((ActivityLog l) => l.type == ActivityType.reportGenerated),
      isTrue,
    );
  });
}
