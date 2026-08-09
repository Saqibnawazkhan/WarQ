import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/entities/student_performance.dart';
import 'base_controller.dart';

/// One attendance entry on the student profile timeline.
class StudentAttendanceEntry {
  const StudentAttendanceEntry({
    required this.date,
    required this.status,
    required this.className,
  });

  final DateTime date;
  final AttendanceStatus status;
  final String className;
}

/// Backs the student profile / performance screen.
class StudentProfileController extends BaseController {
  StudentProfileController(
    this._deps,
    this.studentId, {
    this.classId,
  }) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.students,
      DataEntity.attendance,
      DataEntity.marks,
      DataEntity.assessments,
      DataEntity.enrollments,
    });
  }

  final AppDependencies _deps;
  final String studentId;

  /// When set the profile is scoped to a single class.
  final String? classId;

  Student? _student;
  StudentPerformance? _performance;
  SchoolClass? _schoolClass;
  GradeScale? _gradeScale;
  List<SchoolClass> _enrolledClasses = const <SchoolClass>[];
  List<StudentAttendanceEntry> _attendanceLog = const <StudentAttendanceEntry>[];

  Student? get student => _student;
  StudentPerformance? get performance => _performance;
  SchoolClass? get schoolClass => _schoolClass;
  GradeScale? get gradeScale => _gradeScale;
  List<SchoolClass> get enrolledClasses => _enrolledClasses;
  List<StudentAttendanceEntry> get attendanceLog => _attendanceLog;

  /// Graded results only, oldest → newest, for the progression chart.
  List<AssessmentResult> get gradedResults =>
      _performance?.results.where((AssessmentResult r) => r.isGraded).toList() ??
      const <AssessmentResult>[];

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _student = await _deps.students.findById(studentId);
        if (_student == null) throw StateError('missing student');

        _performance = await _deps.analytics.studentPerformance(
          studentId: studentId,
          classId: classId,
        );
        _schoolClass =
            classId == null ? null : await _deps.classes.findById(classId!);
        _gradeScale = await _deps.gradeScales.resolveFor(
          organizationId:
              _schoolClass?.organizationId ?? _student?.organizationId,
        );

        final List<String> classIds =
            await _deps.students.classIdsFor(studentId);
        final List<SchoolClass> classes = <SchoolClass>[];
        for (final String id in classIds) {
          final SchoolClass? found = await _deps.classes.findById(id);
          if (found != null) classes.add(found);
        }
        classes.sort((SchoolClass a, SchoolClass b) =>
            a.name.toLowerCase().compareTo(b.name.toLowerCase()));
        _enrolledClasses = classes;

        _attendanceLog = await _buildAttendanceLog(classes);
      },
      refreshing: refreshing,
    );
  }

  Future<List<StudentAttendanceEntry>> _buildAttendanceLog(
    List<SchoolClass> classes,
  ) async {
    final List<AttendanceRecord> records =
        await _deps.attendance.recordsForStudent(studentId, classId: classId);
    if (records.isEmpty) return const <StudentAttendanceEntry>[];

    final Map<String, String> classNames = <String, String>{
      for (final SchoolClass c in classes) c.id: c.name,
      if (_schoolClass != null) _schoolClass!.id: _schoolClass!.name,
    };

    final Map<String, DateTime> sessionDates = <String, DateTime>{};
    for (final String id in records.map((AttendanceRecord r) => r.classId).toSet()) {
      for (final AttendanceSession session
          in await _deps.attendance.sessionsForClass(id)) {
        sessionDates[session.id] = session.date;
      }
    }

    final List<StudentAttendanceEntry> entries = <StudentAttendanceEntry>[
      for (final AttendanceRecord record in records)
        if (sessionDates[record.sessionId] != null)
          StudentAttendanceEntry(
            date: sessionDates[record.sessionId]!,
            status: record.status,
            className: classNames[record.classId] ?? 'Class',
          ),
    ]..sort((StudentAttendanceEntry a, StudentAttendanceEntry b) =>
        b.date.compareTo(a.date));
    return entries;
  }

  Future<Student?> updateStudent(StudentDraft draft) {
    return guardAction<Student>(() => _deps.students.update(studentId, draft));
  }

  Future<bool> deleteStudent() async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.students.delete(studentId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> removeFromClass(String targetClassId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.students
          .unenroll(classId: targetClassId, studentId: studentId);
      return true;
    });
    return ok ?? false;
  }
}
