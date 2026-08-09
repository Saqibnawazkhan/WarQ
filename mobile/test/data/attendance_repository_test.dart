import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/error/failure.dart';
import 'package:edu_manager/core/utils/date_utils.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/data/repositories/attendance_repository.dart';
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
    ahmed = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Ahmed Bilal',
      fatherPhone: '+92 300 1112222',
    );
    bilal = await addTestStudent(deps, teacher, schoolClass, name: 'Bilal Hussain');
  });

  tearDown(() async => deps.dispose());

  group('sheet', () {
    test('a fresh date returns an empty, unsaved sheet', () async {
      final AttendanceSheet sheet = await deps.attendance.sheetFor(
        classId: schoolClass.id,
        date: DateTime.now(),
        userId: teacher.id,
      );

      expect(sheet.isNew, isTrue);
      expect(sheet.records, isEmpty);
    });

    test('reopening a saved date returns the stored statuses', () async {
      final DateTime date = AppDate.today();
      await deps.attendance.save(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{
          ahmed.id: AttendanceStatus.absent,
          bilal.id: AttendanceStatus.present,
        },
      );

      final AttendanceSheet sheet = await deps.attendance.sheetFor(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
      );

      expect(sheet.isNew, isFalse);
      expect(sheet.records[ahmed.id]?.status, AttendanceStatus.absent);
      expect(sheet.records[bilal.id]?.status, AttendanceStatus.present);
      expect(sheet.presentCount, 1);
      expect(sheet.absentCount, 1);
    });
  });

  group('save', () {
    test('saving the same date twice updates instead of duplicating', () async {
      final DateTime date = AppDate.today();

      await deps.attendance.save(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{
          ahmed.id: AttendanceStatus.present,
          bilal.id: AttendanceStatus.present,
        },
      );
      final AttendanceSaveResult second = await deps.attendance.save(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{
          ahmed.id: AttendanceStatus.absent,
          bilal.id: AttendanceStatus.present,
        },
      );

      expect(second.wasUpdate, isTrue);
      expect(await deps.attendance.sessionsForClass(schoolClass.id), hasLength(1));
      expect(await deps.attendance.recordsForClass(schoolClass.id), hasLength(2));
    });

    test('reports only students who newly became absent', () async {
      final DateTime date = AppDate.today();

      final AttendanceSaveResult first = await deps.attendance.save(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{
          ahmed.id: AttendanceStatus.absent,
          bilal.id: AttendanceStatus.present,
        },
      );
      expect(first.newlyAbsentStudentIds, <String>[ahmed.id]);

      // Flag the record as notified, as the notification pipeline does.
      final List<AttendanceRecord> records =
          await deps.attendance.recordsForSession(first.session.id);
      await deps.attendance.markNotified(
        records
            .where((AttendanceRecord r) => r.studentId == ahmed.id)
            .map((AttendanceRecord r) => r.id),
      );

      final AttendanceSaveResult second = await deps.attendance.save(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{
          ahmed.id: AttendanceStatus.absent,
          bilal.id: AttendanceStatus.absent,
        },
      );

      expect(
        second.newlyAbsentStudentIds,
        <String>[bilal.id],
        reason: 'an already notified absence must not be re-reported',
      );
    });

    test('refuses a future date', () {
      expect(
        () => deps.attendance.save(
          classId: schoolClass.id,
          date: DateTime.now().add(const Duration(days: 1)),
          userId: teacher.id,
          statuses: <String, AttendanceStatus>{
            ahmed.id: AttendanceStatus.present,
          },
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

    test('refuses an empty roster', () {
      expect(
        () => deps.attendance.save(
          classId: schoolClass.id,
          date: AppDate.today(),
          userId: teacher.id,
          statuses: const <String, AttendanceStatus>{},
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('drops records for students who left the class', () async {
      final DateTime date = AppDate.today();
      await deps.attendance.save(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{
          ahmed.id: AttendanceStatus.present,
          bilal.id: AttendanceStatus.present,
        },
      );

      await deps.attendance.save(
        classId: schoolClass.id,
        date: date,
        userId: teacher.id,
        statuses: <String, AttendanceStatus>{ahmed.id: AttendanceStatus.present},
      );

      final List<AttendanceRecord> records =
          await deps.attendance.recordsForClass(schoolClass.id);
      expect(records, hasLength(1));
      expect(records.single.studentId, ahmed.id);
    });
  });

  group('history search', () {
    setUp(() async {
      final DateTime today = AppDate.today();
      for (int i = 1; i <= 3; i++) {
        await deps.attendance.save(
          classId: schoolClass.id,
          date: today.subtract(Duration(days: i)),
          userId: teacher.id,
          statuses: <String, AttendanceStatus>{
            ahmed.id: i.isEven ? AttendanceStatus.absent : AttendanceStatus.present,
            bilal.id: AttendanceStatus.present,
          },
        );
      }
    });

    test('filters by student', () async {
      final List<AttendanceRecord> records = await deps.attendance.search(
        AttendanceQuery(studentId: ahmed.id),
      );
      expect(records, hasLength(3));
      expect(
        records.every((AttendanceRecord r) => r.studentId == ahmed.id),
        isTrue,
      );
    });

    test('filters by status', () async {
      final List<AttendanceRecord> records = await deps.attendance.search(
        const AttendanceQuery(statuses: <AttendanceStatus>{AttendanceStatus.absent}),
      );
      expect(records, hasLength(1));
      expect(records.single.studentId, ahmed.id);
    });

    test('filters by date range', () async {
      final DateTime today = AppDate.today();
      final List<AttendanceRecord> records = await deps.attendance.search(
        AttendanceQuery(
          from: today.subtract(const Duration(days: 1)),
          to: today,
        ),
      );
      expect(records, hasLength(2), reason: 'only yesterday falls in range');
    });

    test('returns records newest first', () async {
      final List<AttendanceRecord> records =
          await deps.attendance.search(AttendanceQuery(studentId: ahmed.id));
      final List<AttendanceSession> sessions =
          await deps.attendance.sessionsForClass(schoolClass.id);
      final Map<String, DateTime> dates = <String, DateTime>{
        for (final AttendanceSession s in sessions) s.id: s.date,
      };

      final List<DateTime> ordered = records
          .map((AttendanceRecord r) => dates[r.sessionId]!)
          .toList(growable: false);
      for (int i = 1; i < ordered.length; i++) {
        expect(ordered[i - 1].isAfter(ordered[i]), isTrue);
      }
    });
  });

  test('deleting a session removes its records', () async {
    final AttendanceSaveResult result = await deps.attendance.save(
      classId: schoolClass.id,
      date: AppDate.today(),
      userId: teacher.id,
      statuses: <String, AttendanceStatus>{ahmed.id: AttendanceStatus.present},
    );

    await deps.attendance.deleteSession(result.session.id);

    expect(await deps.attendance.sessionsForClass(schoolClass.id), isEmpty);
    expect(await deps.attendance.recordsForClass(schoolClass.id), isEmpty);
  });
}
