import '../../app/app_dependencies.dart';
import '../../core/constants/app_constants.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../../domain/entities/dashboard_data.dart';
import '../../domain/entities/student_performance.dart';
import 'base_controller.dart';

/// Backs the class hub: roster, attendance history and assessments.
///
/// The roster is the [ClassPerformance] student list, so the attendance
/// percentage and grade shown next to each name come from the same computation
/// as the reports.
class ClassDetailController extends BaseController {
  ClassDetailController(this._deps, this._teacher, this.classId) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.classes,
      DataEntity.students,
      DataEntity.enrollments,
      DataEntity.attendance,
      DataEntity.assessments,
      DataEntity.marks,
      DataEntity.gradeScales,
    });
  }

  final AppDependencies _deps;
  final AppUser _teacher;
  final String classId;

  SchoolClass? _schoolClass;
  ClassPerformance? _performance;
  List<AssessmentSummary> _assessments = const <AssessmentSummary>[];
  List<AttendanceSession> _sessions = const <AttendanceSession>[];

  String _query = '';
  StudentSort _sort = StudentSort.nameAsc;
  StudentFilter _filter = StudentFilter.all;

  SchoolClass? get schoolClass => _schoolClass;
  ClassPerformance? get performance => _performance;
  List<AssessmentSummary> get assessments => _assessments;
  List<AttendanceSession> get sessions => _sessions;
  GradeScale? get gradeScale => _performance?.gradeScale;

  String get query => _query;
  StudentSort get sort => _sort;
  StudentFilter get filter => _filter;
  bool get isFiltering =>
      _query.trim().isNotEmpty || _filter != StudentFilter.all;

  List<StudentPerformance> get allStudents =>
      _performance?.students ?? const <StudentPerformance>[];

  int get studentCount => allStudents.length;

  /// Roster after search, quick-filter and sort.
  List<StudentPerformance> get visibleStudents {
    final String needle = _query.trim().toLowerCase();
    Iterable<StudentPerformance> result = allStudents;

    if (needle.isNotEmpty) {
      result = result.where((StudentPerformance p) {
        final Student s = p.student;
        return s.fullName.toLowerCase().contains(needle) ||
            (s.rollNumber?.toLowerCase().contains(needle) ?? false) ||
            (s.studentPhone?.contains(needle) ?? false) ||
            (s.fatherPhone?.contains(needle) ?? false) ||
            (s.motherPhone?.contains(needle) ?? false);
      });
    }

    result = switch (_filter) {
      StudentFilter.all => result,
      StudentFilter.lowAttendance =>
        result.where((StudentPerformance p) => p.hasLowAttendance),
      StudentFilter.atRisk => result.where((StudentPerformance p) => p.isAtRisk),
      StudentFilter.topPerformers => result.where((StudentPerformance p) =>
          (p.percentage ?? 0) >= 80 && p.hasMarks),
      StudentFilter.ungraded =>
        result.where((StudentPerformance p) => !p.hasMarks),
    };

    final List<StudentPerformance> list = result.toList();
    _applySort(list);
    return list;
  }

  /// Roster grouped under A–Z section headers. Only used when the default
  /// alphabetical sort is active, where the headers actually aid scanning.
  Map<String, List<StudentPerformance>> get groupedStudents {
    final Map<String, List<StudentPerformance>> grouped =
        <String, List<StudentPerformance>>{};
    for (final StudentPerformance performance in visibleStudents) {
      grouped
          .putIfAbsent(performance.student.sectionLetter, () => <StudentPerformance>[])
          .add(performance);
    }
    return grouped;
  }

  bool get showSectionHeaders =>
      _sort == StudentSort.nameAsc && _query.trim().isEmpty;

  /// Students at risk, surfaced as a banner at the top of the roster.
  List<StudentPerformance> get atRiskStudents =>
      allStudents.where((StudentPerformance p) => p.isAtRisk).toList();

  bool get hasAttendanceToday {
    final DateTime today = DateTime.now();
    return _sessions.any((AttendanceSession s) =>
        s.date.year == today.year &&
        s.date.month == today.month &&
        s.date.day == today.day);
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _schoolClass = await _deps.classes.findById(classId);
        if (_schoolClass == null) {
          throw StateError('missing class');
        }
        _performance = await _deps.analytics.classPerformance(classId);
        _sessions = await _deps.attendance.sessionsForClass(classId);
        _assessments = await _loadAssessmentSummaries();
      },
      refreshing: refreshing,
    );
  }

  Future<List<AssessmentSummary>> _loadAssessmentSummaries() async {
    final List<Assessment> assessments =
        await _deps.assessments.listForClass(classId);
    if (assessments.isEmpty) return const <AssessmentSummary>[];

    final Map<String, int> graded = await _deps.assessments.gradedCounts(
      assessments.map((Assessment a) => a.id),
    );
    final List<AssessmentMark> marks =
        await _deps.assessments.marksForClass(classId);
    final int rosterSize = studentCount;

    return <AssessmentSummary>[
      for (final Assessment assessment in assessments)
        AssessmentSummary(
          assessment: assessment,
          className: _schoolClass?.name ?? '',
          gradedCount: graded[assessment.id] ?? 0,
          studentCount: rosterSize,
          averagePercentage: _deps.grading.average(
            marks
                .where((AssessmentMark m) => m.assessmentId == assessment.id)
                .map((AssessmentMark m) => m.percentageOf(assessment.totalMarks)),
          ),
        ),
    ];
  }

  // ---------------------------------------------------------------------------
  // Roster view state
  // ---------------------------------------------------------------------------

  void search(String value) {
    if (_query == value) return;
    _query = value;
    safeNotify();
  }

  void setSort(StudentSort value) {
    if (_sort == value) return;
    _sort = value;
    safeNotify();
  }

  void setFilter(StudentFilter value) {
    if (_filter == value) return;
    _filter = value;
    safeNotify();
  }

  void clearFilters() {
    _query = '';
    _filter = StudentFilter.all;
    _sort = StudentSort.nameAsc;
    safeNotify();
  }

  void _applySort(List<StudentPerformance> list) {
    int byName(StudentPerformance a, StudentPerformance b) =>
        a.student.sortKey.compareTo(b.student.sortKey);

    switch (_sort) {
      case StudentSort.nameAsc:
        list.sort(byName);
      case StudentSort.nameDesc:
        list.sort((StudentPerformance a, StudentPerformance b) => byName(b, a));
      case StudentSort.rollNumber:
        list.sort((StudentPerformance a, StudentPerformance b) {
          final String aRoll = a.student.rollNumber ?? '~';
          final String bRoll = b.student.rollNumber ?? '~';
          final int compare =
              aRoll.toLowerCase().compareTo(bRoll.toLowerCase());
          return compare != 0 ? compare : byName(a, b);
        });
      case StudentSort.attendanceAsc:
        list.sort((StudentPerformance a, StudentPerformance b) =>
            a.attendance.percentageOrZero.compareTo(b.attendance.percentageOrZero));
      case StudentSort.attendanceDesc:
        list.sort((StudentPerformance a, StudentPerformance b) =>
            b.attendance.percentageOrZero.compareTo(a.attendance.percentageOrZero));
      case StudentSort.performanceAsc:
        list.sort((StudentPerformance a, StudentPerformance b) =>
            (a.percentage ?? -1).compareTo(b.percentage ?? -1));
      case StudentSort.performanceDesc:
        list.sort((StudentPerformance a, StudentPerformance b) =>
            (b.percentage ?? -1).compareTo(a.percentage ?? -1));
    }
  }

  // ---------------------------------------------------------------------------
  // Actions
  // ---------------------------------------------------------------------------

  Future<Student?> addStudent(StudentDraft draft) {
    return guardAction<Student>(
      () => _deps.students.create(
        teacherId: _teacher.id,
        draft: draft,
        classId: classId,
        organizationId: _schoolClass?.organizationId ?? _teacher.organizationId,
      ),
    );
  }

  Future<Student?> updateStudent(String studentId, StudentDraft draft) {
    return guardAction<Student>(() => _deps.students.update(studentId, draft));
  }

  Future<bool> deleteStudent(String studentId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.students.delete(studentId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> removeFromClass(String studentId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.students.unenroll(classId: classId, studentId: studentId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> enrollExisting(Iterable<String> studentIds) async {
    final bool? ok = await guardAction<bool>(() async {
      for (final String studentId in studentIds) {
        await _deps.students.enroll(classId: classId, studentId: studentId);
      }
      return true;
    });
    return ok ?? false;
  }

  /// Students owned by this teacher who are not already in this class.
  Future<List<Student>> enrollableStudents() async {
    final List<Student> mine = await _deps.students.listForTeacher(_teacher.id);
    final Set<String> enrolled =
        allStudents.map((StudentPerformance p) => p.student.id).toSet();
    return mine.where((Student s) => !enrolled.contains(s.id)).toList();
  }

  Future<Assessment?> createAssessment(AssessmentDraft draft) {
    return guardAction<Assessment>(
      () => _deps.assessments.create(
        classId: classId,
        userId: _teacher.id,
        draft: draft,
      ),
    );
  }

  Future<Assessment?> updateAssessment(String id, AssessmentDraft draft) {
    return guardAction<Assessment>(() => _deps.assessments.update(id, draft));
  }

  Future<bool> deleteAssessment(String assessmentId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.assessments.delete(assessmentId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> deleteSession(String sessionId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.attendance.deleteSession(sessionId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> deleteClass() async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.classes.delete(classId);
      return true;
    });
    return ok ?? false;
  }

  /// Attendance sessions trimmed for the overview tab.
  List<AttendanceSession> get recentSessions =>
      _sessions.take(AppConstants.recentItemsLimit).toList(growable: false);
}
