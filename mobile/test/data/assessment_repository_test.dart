import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/error/failure.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/data/repositories/assessment_repository.dart';
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

  group('creation', () {
    test('creates every assessment type the spec lists', () async {
      for (final AssessmentType type in AssessmentType.values) {
        final Assessment assessment = await deps.assessments.create(
          classId: schoolClass.id,
          userId: teacher.id,
          draft: AssessmentDraft(
            name: '${type.name} item',
            type: type,
            date: DateTime.now(),
            totalMarks: type.suggestedTotalMarks,
            customTypeLabel: type == AssessmentType.custom ? 'Lab report' : null,
          ),
        );
        expect(assessment.type, type);
      }

      expect(
        await deps.assessments.listForClass(schoolClass.id),
        hasLength(AssessmentType.values.length),
      );
    });

    test('a custom assessment needs a type label', () {
      expect(
        () => deps.assessments.create(
          classId: schoolClass.id,
          userId: teacher.id,
          draft: AssessmentDraft(
            name: 'Something',
            type: AssessmentType.custom,
            date: DateTime.now(),
            totalMarks: 10,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('custom label is used as the display type', () async {
      final Assessment assessment = await deps.assessments.create(
        classId: schoolClass.id,
        userId: teacher.id,
        draft: AssessmentDraft(
          name: 'Lab 1',
          type: AssessmentType.custom,
          customTypeLabel: 'Lab report',
          date: DateTime.now(),
          totalMarks: 10,
        ),
      );
      expect(assessment.typeLabel, 'Lab report');
    });

    test('total marks must be positive', () {
      expect(
        () => deps.assessments.create(
          classId: schoolClass.id,
          userId: teacher.id,
          draft: AssessmentDraft(
            name: 'Bad quiz',
            type: AssessmentType.quiz,
            date: DateTime.now(),
            totalMarks: 0,
          ),
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('marks', () {
    late Assessment quiz;

    setUp(() async {
      quiz = await createTestAssessment(deps, teacher, schoolClass, totalMarks: 20);
    });

    test('saves and reads back marks per student', () async {
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[
          MarkEntry(studentId: ahmed.id, marksObtained: 18),
          MarkEntry(studentId: bilal.id, marksObtained: 12, remarks: 'Rushed'),
        ],
      );

      final Map<String, AssessmentMark> marks =
          await deps.assessments.marksForAssessment(quiz.id);

      expect(marks[ahmed.id]?.marksObtained, 18);
      expect(marks[bilal.id]?.remarks, 'Rushed');
      expect(marks[ahmed.id]?.percentageOf(20), 90);
    });

    test('a blank entry means not graded and removes any stored mark', () async {
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 18)],
      );
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id)],
      );

      final Map<String, AssessmentMark> marks =
          await deps.assessments.marksForAssessment(quiz.id);
      expect(marks[ahmed.id], isNull);
    });

    test('rejects marks above the total', () {
      expect(
        () => deps.assessments.saveMarks(
          assessmentId: quiz.id,
          entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 25)],
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('rejects negative marks', () {
      expect(
        () => deps.assessments.saveMarks(
          assessmentId: quiz.id,
          entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: -1)],
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('an absent student is graded as zero', () async {
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, absent: true)],
      );

      final Map<String, AssessmentMark> marks =
          await deps.assessments.marksForAssessment(quiz.id);
      expect(marks[ahmed.id]?.absent, isTrue);
      expect(marks[ahmed.id]?.effectiveMarks, 0);
      expect(marks[ahmed.id]?.isGraded, isTrue);
    });

    test('counts graded students per assessment', () async {
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[
          MarkEntry(studentId: ahmed.id, marksObtained: 18),
          MarkEntry(studentId: bilal.id),
        ],
      );

      final Map<String, int> counts =
          await deps.assessments.gradedCounts(<String>[quiz.id]);
      expect(counts[quiz.id], 1);
    });
  });

  group('editing', () {
    test('cannot lower the total below an existing score', () async {
      final Assessment quiz =
          await createTestAssessment(deps, teacher, schoolClass, totalMarks: 20);
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 18)],
      );

      expect(
        () => deps.assessments.update(
          quiz.id,
          AssessmentDraft(
            name: quiz.name,
            type: quiz.type,
            date: quiz.date,
            totalMarks: 10,
          ),
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.message,
            'message',
            contains('highest recorded score'),
          ),
        ),
      );
    });

    test('raising the total is allowed', () async {
      final Assessment quiz =
          await createTestAssessment(deps, teacher, schoolClass, totalMarks: 20);
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 18)],
      );

      final Assessment updated = await deps.assessments.update(
        quiz.id,
        AssessmentDraft(
          name: 'Quiz 1 (revised)',
          type: quiz.type,
          date: quiz.date,
          totalMarks: 25,
        ),
      );

      expect(updated.totalMarks, 25);
      expect(updated.name, 'Quiz 1 (revised)');
    });

    test('deleting an assessment removes its marks', () async {
      final Assessment quiz =
          await createTestAssessment(deps, teacher, schoolClass, totalMarks: 20);
      await deps.assessments.saveMarks(
        assessmentId: quiz.id,
        entries: <MarkEntry>[MarkEntry(studentId: ahmed.id, marksObtained: 18)],
      );

      await deps.assessments.delete(quiz.id);

      expect(await deps.assessments.findById(quiz.id), isNull);
      expect(await deps.assessments.marksForClass(schoolClass.id), isEmpty);
    });
  });

  group('listing', () {
    test('returns assessments newest first', () async {
      final DateTime today = DateTime.now();
      await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        name: 'Old quiz',
        date: today.subtract(const Duration(days: 20)),
      );
      await createTestAssessment(
        deps,
        teacher,
        schoolClass,
        name: 'New quiz',
        date: today,
      );

      final List<Assessment> list =
          await deps.assessments.listForClass(schoolClass.id);
      expect(list.first.name, 'New quiz');
      expect(list.last.name, 'Old quiz');
    });
  });
}
