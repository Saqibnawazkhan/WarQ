import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/utils/date_utils.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/data/repositories/assessment_repository.dart';
import 'package:edu_manager/domain/entities/dashboard_data.dart';
import 'package:edu_manager/domain/entities/student_performance.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late AppDependencies deps;
  late AppUser teacher;
  late SchoolClass schoolClass;
  late Student ahmed;
  late Student bilal;

  setUp(() async {
    deps = await createTestDependencies();
    teacher = await registerTestTeacher(deps);
    schoolClass = await createTestClass(deps, teacher);
    ahmed = await addTestStudent(deps, teacher, schoolClass, name: 'Ahmed Bilal');
    bilal = await addTestStudent(deps, teacher, schoolClass, name: 'Bilal Hussain');
  });

  tearDown(() async => deps.dispose());

  group('studentPerformance', () {
    test('totals graded assessments only', () async {
      final Assessment quiz = await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        name: 'Quiz 1',
        totalMarks: 20,
      );
      final Assessment midterm = await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        name: 'Midterm',
        totalMarks: 50,
        type: AssessmentType.midterm,
      );

      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 18)],
      );
      // The midterm is deliberately left ungraded for Ahmed.

      final StudentPerformance performance =
          await deps.analytics.studentPerformance(
        studentId: ahmed.id,
        classId: schoolClass.id,
      );

      expect(performance.obtainedTotal, 18);
      expect(
        performance.maxTotal,
        20,
        reason: 'the ungraded midterm must not enter the denominator',
      );
      expect(performance.percentage, 90);
      expect(performance.grade?.label, 'A+');
      expect(performance.gradedCount, 1);
      expect(performance.pendingCount, 1);
      expect(midterm.id, isNotEmpty);
    });

    test('an absent student scores zero but is counted as graded', () async {
      final Assessment quiz = await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        totalMarks: 20,
      );
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, absent: true)],
      );

      final StudentPerformance performance =
          await deps.analytics.studentPerformance(
        studentId: ahmed.id,
        classId: schoolClass.id,
      );

      expect(performance.percentage, 0);
      expect(performance.gradedCount, 1);
      expect(performance.results.single.wasAbsent, isTrue);
    });

    test('reports no percentage when nothing has been graded', () async {
      await createTestAssessment(deps, teacher, schoolClass);

      final StudentPerformance performance =
          await deps.analytics.studentPerformance(
        studentId: ahmed.id,
        classId: schoolClass.id,
      );

      expect(performance.hasMarks, isFalse);
      expect(performance.percentage, isNull);
      expect(performance.grade, isNull);
    });

    test('orders results oldest first for the progression chart', () async {
      final DateTime today = AppDate.today();
      await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        name: 'Recent',
        date: today,
      );
      await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        name: 'Older',
        date: today.subtract(const Duration(days: 30)),
      );

      final StudentPerformance performance =
          await deps.analytics.studentPerformance(
        studentId: ahmed.id,
        classId: schoolClass.id,
      );

      expect(
        performance.results.map((AssessmentResult r) => r.assessment.name).toList(),
        <String>['Older', 'Recent'],
      );
    });

    test('flags a student with low attendance as at risk', () async {
      final DateTime today = AppDate.today();
      for (int i = 1; i <= 4; i++) {
        await deps.attendance.save(
          classId: schoolClass.id,
          date: today.subtract(Duration(days: i)),
          userId: teacher.id,
          statuses: <String, AttendanceStatus>{
            ahmed.id: i == 1 ? AttendanceStatus.present : AttendanceStatus.absent,
            bilal.id: AttendanceStatus.present,
          },
        );
      }

      final StudentPerformance risky = await deps.analytics.studentPerformance(
        studentId: ahmed.id,
        classId: schoolClass.id,
      );
      final StudentPerformance fine = await deps.analytics.studentPerformance(
        studentId: bilal.id,
        classId: schoolClass.id,
      );

      expect(risky.attendance.percentage, 25);
      expect(risky.hasLowAttendance, isTrue);
      expect(risky.isAtRisk, isTrue);
      expect(fine.attendance.percentage, 100);
      expect(fine.isAtRisk, isFalse);
    });
  });

  group('classPerformance', () {
    test('lists students A–Z with class averages and distribution', () async {
      final Assessment quiz = await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        totalMarks: 20,
      );
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[
          MarkEntry(studentId: ahmed.id, marksObtained: 18), // 90% → A+
          MarkEntry(studentId: bilal.id, marksObtained: 14), // 70% → B
        ],
      );

      final ClassPerformance performance =
          await deps.analytics.classPerformance(schoolClass.id);

      expect(
        performance.students.map((StudentPerformance p) => p.student.fullName),
        <String>['Ahmed Bilal', 'Bilal Hussain'],
      );
      expect(performance.averagePercentage, 80);
      expect(performance.gradeDistribution['A+'], 1);
      expect(performance.gradeDistribution['B'], 1);
      expect(performance.assessmentCount, 1);
    });

    test('top performers and at-risk lists are derived consistently', () async {
      final Assessment quiz = await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        totalMarks: 20,
      );
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[
          MarkEntry(studentId: ahmed.id, marksObtained: 19),
          MarkEntry(studentId: bilal.id, marksObtained: 6), // 30% → failing
        ],
      );

      final ClassPerformance performance =
          await deps.analytics.classPerformance(schoolClass.id);

      expect(performance.topPerformers().first.student.id, ahmed.id);
      expect(performance.atRisk.single.student.id, bilal.id);
    });
  });

  group('teacherDashboard', () {
    test('counts distinct students across classes', () async {
      final SchoolClass second =
          await createTestClass(deps, teacher, name: 'Database Systems');
      await deps.students.enroll(classId: second.id, studentId: ahmed.id);

      final TeacherDashboardData data =
          await deps.analytics.teacherDashboard(teacher);

      expect(data.totalClasses, 2);
      expect(
        data.totalStudents,
        2,
        reason: 'Ahmed is in both classes but is one person',
      );
    });

    test('lists classes with no attendance today as pending', () async {
      final TeacherDashboardData data =
          await deps.analytics.teacherDashboard(teacher);

      expect(data.today.classesTotal, 1);
      expect(data.today.classesMarked, 0);
      expect(data.today.pendingClasses.single.id, schoolClass.id);
    });

    test('a class with no students is not an outstanding attendance task',
        () async {
      await createTestClass(deps, teacher, name: 'Empty Class');

      final TeacherDashboardData data =
          await deps.analytics.teacherDashboard(teacher);

      expect(data.totalClasses, 2);
      expect(
        data.today.classesTotal,
        1,
        reason: 'only classes with students can have attendance taken',
      );
    });

    test('surfaces assessments that still need marks', () async {
      final Assessment quiz =
          await createTestAssessment(deps, teacher, schoolClass, totalMarks: 20);
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 18)],
      );

      final TeacherDashboardData data =
          await deps.analytics.teacherDashboard(teacher);

      expect(data.assessmentsAwaitingMarks, hasLength(1));
      expect(data.assessmentsAwaitingMarks.single.gradedCount, 1);
      expect(data.assessmentsAwaitingMarks.single.studentCount, 2);
      expect(data.assessmentsAwaitingMarks.single.pendingCount, 1);
    });

    test('is empty and safe for a brand new teacher', () async {
      final AppUser fresh = await deps.auth.registerTeacher(
        fullName: 'New Teacher',
        email: 'new@test.com',
        password: 'password123',
      );

      final TeacherDashboardData data =
          await deps.analytics.teacherDashboard(fresh);

      expect(data.isEmpty, isTrue);
      expect(data.today.pendingClasses, isEmpty);
      expect(data.overallAveragePercentage, isNull);
    });
  });
}
