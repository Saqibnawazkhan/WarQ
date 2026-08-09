import '../../core/constants/app_constants.dart';
import '../../core/error/failure.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/assessment_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/grade_scale_repository.dart';
import '../../data/repositories/organization_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../entities/attendance_summary.dart';
import '../entities/dashboard_data.dart';
import '../entities/student_performance.dart';
import 'grading_service.dart';

/// Turns raw records into the aggregates every screen and report displays.
///
/// All arithmetic lives here rather than in widgets, so the dashboard, the
/// performance screen and the PDF reports can never disagree about a number.
class AnalyticsService {
  AnalyticsService({
    required ClassRepository classes,
    required StudentRepository students,
    required AttendanceRepository attendance,
    required AssessmentRepository assessments,
    required GradeScaleRepository gradeScales,
    required ActivityRepository activity,
    required OrganizationRepository organizations,
    GradingService grading = const GradingService(),
  })  : _classes = classes,
        _students = students,
        _attendance = attendance,
        _assessments = assessments,
        _gradeScales = gradeScales,
        _activity = activity,
        _organizations = organizations,
        _grading = grading;

  final ClassRepository _classes;
  final StudentRepository _students;
  final AttendanceRepository _attendance;
  final AssessmentRepository _assessments;
  final GradeScaleRepository _gradeScales;
  final ActivityRepository _activity;
  final OrganizationRepository _organizations;
  final GradingService _grading;

  GradingService get grading => _grading;

  // ---------------------------------------------------------------------------
  // Class level
  // ---------------------------------------------------------------------------

  /// Full class roll-up: one [StudentPerformance] per enrolled student plus the
  /// class averages and grade distribution.
  Future<ClassPerformance> classPerformance(String classId) async {
    final SchoolClass? schoolClass = await _classes.findById(classId);
    if (schoolClass == null) throw const AppFailure.notFound('That class');

    final GradeScale scale = await _gradeScales.resolveFor(
      organizationId: schoolClass.organizationId,
    );
    final List<Student> roster = await _students.listForClass(classId);
    final List<AttendanceSession> sessions =
        await _attendance.sessionsForClass(classId);
    final List<AttendanceRecord> records =
        await _attendance.recordsForClass(classId);
    final List<Assessment> assessments = await _assessments.listForClass(classId);
    final List<AssessmentMark> marks = await _assessments.marksForClass(classId);

    // Oldest first so progression charts and report tables read chronologically.
    final List<Assessment> chronological = List<Assessment>.of(assessments)
      ..sort((Assessment a, Assessment b) => a.date.compareTo(b.date));

    final Map<String, List<AttendanceRecord>> recordsByStudent =
        _groupBy(records, (AttendanceRecord r) => r.studentId);
    final Map<String, Map<String, AssessmentMark>> marksByStudent =
        <String, Map<String, AssessmentMark>>{};
    for (final AssessmentMark mark in marks) {
      marksByStudent
          .putIfAbsent(mark.studentId, () => <String, AssessmentMark>{})[mark.assessmentId] = mark;
    }

    final List<StudentPerformance> performances = <StudentPerformance>[
      for (final Student student in roster)
        _buildPerformance(
          student: student,
          records: recordsByStudent[student.id] ?? const <AttendanceRecord>[],
          assessments: chronological,
          marks: marksByStudent[student.id] ?? const <String, AssessmentMark>{},
          scale: scale,
          classId: classId,
          className: schoolClass.name,
        ),
    ];

    final List<double?> percentages =
        performances.map((StudentPerformance p) => p.percentage).toList();
    final List<double?> attendancePercentages = performances
        .map((StudentPerformance p) => p.attendance.percentage)
        .toList();

    return ClassPerformance(
      schoolClass: schoolClass,
      students: performances,
      gradeScale: scale,
      sessionCount: sessions.length,
      assessmentCount: assessments.length,
      gradeDistribution: _grading.distribution(percentages, scale),
      averagePercentage: _grading.average(percentages),
      averageAttendance: _grading.average(attendancePercentages),
      lastSessionDate: sessions.isEmpty ? null : sessions.first.date,
    );
  }

  /// A single student's performance, optionally scoped to one class.
  ///
  /// With [classId] omitted the result spans every class the student belongs
  /// to, which is what the global student profile shows.
  Future<StudentPerformance> studentPerformance({
    required String studentId,
    String? classId,
  }) async {
    final Student? student = await _students.findById(studentId);
    if (student == null) throw const AppFailure.notFound('That student');

    final SchoolClass? schoolClass =
        classId == null ? null : await _classes.findById(classId);
    final GradeScale scale = await _gradeScales.resolveFor(
      organizationId: schoolClass?.organizationId ?? student.organizationId,
    );

    final List<AttendanceRecord> records =
        await _attendance.recordsForStudent(studentId, classId: classId);
    final List<AssessmentMark> marks =
        await _assessments.marksForStudent(studentId, classId: classId);

    final List<Assessment> assessments;
    if (classId != null) {
      assessments = await _assessments.listForClass(classId);
    } else {
      final List<String> classIds = await _students.classIdsFor(studentId);
      final List<Assessment> collected = <Assessment>[];
      for (final String id in classIds) {
        collected.addAll(await _assessments.listForClass(id));
      }
      assessments = collected;
    }
    assessments.sort((Assessment a, Assessment b) => a.date.compareTo(b.date));

    return _buildPerformance(
      student: student,
      records: records,
      assessments: assessments,
      marks: <String, AssessmentMark>{
        for (final AssessmentMark mark in marks) mark.assessmentId: mark,
      },
      scale: scale,
      classId: classId,
      className: schoolClass?.name,
    );
  }

  /// Lightweight class row for lists and dashboards.
  Future<ClassSummary> classSummary(SchoolClass schoolClass) async {
    final List<Student> roster = await _students.listForClass(schoolClass.id);
    final List<AttendanceSession> sessions =
        await _attendance.sessionsForClass(schoolClass.id);
    final List<AttendanceRecord> records =
        await _attendance.recordsForClass(schoolClass.id);
    final List<Assessment> assessments =
        await _assessments.listForClass(schoolClass.id);
    final List<AssessmentMark> marks =
        await _assessments.marksForClass(schoolClass.id);

    final Map<String, Assessment> byId = <String, Assessment>{
      for (final Assessment a in assessments) a.id: a,
    };
    final List<double?> markPercentages = <double?>[
      for (final AssessmentMark mark in marks)
        if (byId[mark.assessmentId] != null)
          mark.percentageOf(byId[mark.assessmentId]!.totalMarks),
    ];

    final DateTime today = AppDate.today();
    return ClassSummary(
      schoolClass: schoolClass,
      studentCount: roster.length,
      assessmentCount: assessments.length,
      sessionCount: sessions.length,
      attendance: AttendanceSummary.fromStatuses(
        records.map((AttendanceRecord r) => r.status),
      ),
      lastSessionDate: sessions.isEmpty ? null : sessions.first.date,
      averagePercentage: _grading.average(markPercentages),
      markedToday: sessions.any(
        (AttendanceSession s) => AppDate.isSameDay(s.date, today),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Teacher dashboard
  // ---------------------------------------------------------------------------

  Future<TeacherDashboardData> teacherDashboard(AppUser teacher) async {
    final List<SchoolClass> classes = await _classes.listForTeacher(teacher.id);
    if (classes.isEmpty) {
      return TeacherDashboardData(
        totalClasses: 0,
        totalStudents: 0,
        today: const TodayAttendance.empty(),
        recentClasses: const <ClassSummary>[],
        recentAssessments: const <AssessmentSummary>[],
        recentActivity:
            await _activity.listForUser(teacher.id, limit: AppConstants.recentItemsLimit),
        overallAttendance: const AttendanceSummary.empty(),
        assessmentsAwaitingMarks: const <AssessmentSummary>[],
      );
    }

    final List<ClassSummary> summaries = <ClassSummary>[
      for (final SchoolClass schoolClass in classes)
        await classSummary(schoolClass),
    ];

    // Distinct students: one person enrolled in two classes counts once.
    final Set<String> distinctStudents = <String>{};
    for (final SchoolClass schoolClass in classes) {
      final List<Student> roster = await _students.listForClass(schoolClass.id);
      distinctStudents.addAll(roster.map((Student s) => s.id));
    }

    final TodayAttendance today = await _todayAttendance(summaries);

    final AttendanceSummary overall = AttendanceSummary.combine(
      summaries.map((ClassSummary s) => s.attendance),
    );

    final List<AssessmentSummary> assessmentSummaries =
        await _assessmentSummaries(classes);
    assessmentSummaries.sort((AssessmentSummary a, AssessmentSummary b) =>
        b.assessment.date.compareTo(a.assessment.date));

    final List<ClassSummary> recentClasses = List<ClassSummary>.of(summaries)
      ..sort((ClassSummary a, ClassSummary b) {
        final DateTime aAt = a.schoolClass.updatedAt ?? a.schoolClass.createdAt;
        final DateTime bAt = b.schoolClass.updatedAt ?? b.schoolClass.createdAt;
        return bAt.compareTo(aAt);
      });

    return TeacherDashboardData(
      totalClasses: classes.length,
      totalStudents: distinctStudents.length,
      today: today,
      recentClasses:
          recentClasses.take(AppConstants.recentItemsLimit).toList(growable: false),
      recentAssessments: assessmentSummaries
          .take(AppConstants.recentItemsLimit)
          .toList(growable: false),
      recentActivity: await _activity.listForUser(
        teacher.id,
        limit: AppConstants.recentItemsLimit + 3,
      ),
      overallAttendance: overall,
      assessmentsAwaitingMarks: assessmentSummaries
          .where((AssessmentSummary s) => !s.isFullyGraded)
          .take(AppConstants.recentItemsLimit)
          .toList(growable: false),
      overallAveragePercentage: _grading.average(
        summaries.map((ClassSummary s) => s.averagePercentage),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Organization
  // ---------------------------------------------------------------------------

  Future<OrganizationDashboardData> organizationDashboard(
    String organizationId,
  ) async {
    final Organization? organization =
        await _organizations.findById(organizationId);
    final List<AppUser> teachers = await _organizations.teachers(organizationId);
    final List<SchoolClass> classes =
        await _classes.listForOrganization(organizationId);
    final List<Invitation> invitations =
        await _organizations.invitations(organizationId);

    final List<TeacherSnapshot> snapshots = <TeacherSnapshot>[
      for (final AppUser teacher in teachers) await teacherSnapshot(teacher),
    ];

    final Set<String> distinctStudents = <String>{};
    for (final SchoolClass schoolClass in classes) {
      final List<Student> roster = await _students.listForClass(schoolClass.id);
      distinctStudents.addAll(roster.map((Student s) => s.id));
    }

    final DateTime weekStart = AppDate.startOfWeek(DateTime.now());
    int sessionsThisWeek = 0;
    for (final SchoolClass schoolClass in classes) {
      final List<AttendanceSession> sessions =
          await _attendance.sessionsForClass(schoolClass.id);
      sessionsThisWeek += sessions
          .where((AttendanceSession s) => !s.date.isBefore(weekStart))
          .length;
    }

    return OrganizationDashboardData(
      organization: organization,
      teacherCount: teachers.length,
      classCount: classes.length,
      studentCount: distinctStudents.length,
      pendingInvitations:
          invitations.where((Invitation i) => i.isActionable).length,
      attendance: AttendanceSummary.combine(
        snapshots.map((TeacherSnapshot s) => s.attendance),
      ),
      recentActivity: await _activity.listForOrganization(
        organizationId,
        limit: AppConstants.recentItemsLimit + 5,
      ),
      teacherSnapshots: snapshots,
      averagePercentage: _grading.average(
        snapshots.map((TeacherSnapshot s) => s.averagePercentage),
      ),
      sessionsThisWeek: sessionsThisWeek,
    );
  }

  /// Monitoring snapshot for one teacher.
  ///
  /// [detailed] additionally resolves per-class summaries and the grade
  /// distribution, which the list view does not need.
  Future<TeacherSnapshot> teacherSnapshot(
    AppUser teacher, {
    bool detailed = false,
  }) async {
    final List<SchoolClass> classes = await _classes.listForTeacher(teacher.id);

    final Set<String> studentIds = <String>{};
    int assessmentCount = 0;
    int sessionCount = 0;
    int marksRecorded = 0;
    DateTime? lastAttendanceAt;
    final List<AttendanceSummary> attendanceParts = <AttendanceSummary>[];
    final List<double?> classAverages = <double?>[];
    final List<ClassSummary> classSummaries = <ClassSummary>[];
    final List<double?> studentPercentages = <double?>[];

    GradeScale? scale;
    if (detailed) {
      scale = await _gradeScales.resolveFor(
        organizationId: teacher.organizationId,
      );
    }

    for (final SchoolClass schoolClass in classes) {
      final ClassSummary summary = await classSummary(schoolClass);
      classSummaries.add(summary);

      final List<Student> roster = await _students.listForClass(schoolClass.id);
      studentIds.addAll(roster.map((Student s) => s.id));

      assessmentCount += summary.assessmentCount;
      sessionCount += summary.sessionCount;
      attendanceParts.add(summary.attendance);
      classAverages.add(summary.averagePercentage);

      final List<AssessmentMark> marks =
          await _assessments.marksForClass(schoolClass.id);
      marksRecorded += marks.where((AssessmentMark m) => m.isGraded).length;

      final DateTime? last = summary.lastSessionDate;
      if (last != null && (lastAttendanceAt == null || last.isAfter(lastAttendanceAt))) {
        lastAttendanceAt = last;
      }

      if (detailed) {
        final ClassPerformance performance =
            await classPerformance(schoolClass.id);
        studentPercentages.addAll(
          performance.students.map((StudentPerformance p) => p.percentage),
        );
      }
    }

    final ActivityLog? lastActivity = await _activity.lastActivityFor(teacher.id);

    return TeacherSnapshot(
      teacher: teacher,
      classCount: classes.length,
      studentCount: studentIds.length,
      assessmentCount: assessmentCount,
      sessionCount: sessionCount,
      marksRecorded: marksRecorded,
      attendance: AttendanceSummary.combine(attendanceParts),
      lastActivityAt: lastActivity?.createdAt,
      lastAttendanceAt: lastAttendanceAt,
      averagePercentage: _grading.average(classAverages),
      classes: detailed ? classSummaries : const <ClassSummary>[],
      gradeDistribution: detailed && scale != null
          ? _grading.distribution(studentPercentages, scale)
          : const <String, int>{},
    );
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  StudentPerformance _buildPerformance({
    required Student student,
    required List<AttendanceRecord> records,
    required List<Assessment> assessments,
    required Map<String, AssessmentMark> marks,
    required GradeScale scale,
    String? classId,
    String? className,
  }) {
    final AttendanceSummary attendance = AttendanceSummary.fromStatuses(
      records.map((AttendanceRecord r) => r.status),
    );

    final List<AssessmentResult> results = <AssessmentResult>[];
    double obtainedTotal = 0;
    double maxTotal = 0;

    for (final Assessment assessment in assessments) {
      final AssessmentMark? mark = marks[assessment.id];
      final double? obtained = mark?.effectiveMarks;
      final double? percent = _grading.percentage(
        obtained: obtained,
        total: assessment.totalMarks,
      );

      results.add(
        AssessmentResult(
          assessment: assessment,
          mark: mark,
          grade: _grading.gradeFor(percent, scale),
        ),
      );

      // Ungraded assessments are excluded from both sides of the ratio.
      if (obtained != null) {
        obtainedTotal += obtained;
        maxTotal += assessment.totalMarks;
      }
    }

    final double? percentage =
        maxTotal <= 0 ? null : (obtainedTotal / maxTotal) * 100;

    return StudentPerformance(
      student: student,
      attendance: attendance,
      results: results,
      obtainedTotal: obtainedTotal,
      maxTotal: maxTotal,
      percentage: percentage,
      grade: _grading.gradeFor(percentage, scale),
      classId: classId,
      className: className,
    );
  }

  Future<TodayAttendance> _todayAttendance(List<ClassSummary> summaries) async {
    final DateTime today = AppDate.today();
    final List<SchoolClass> pending = <SchoolClass>[];
    final List<AttendanceStatus> statuses = <AttendanceStatus>[];
    int marked = 0;
    int eligible = 0;

    for (final ClassSummary summary in summaries) {
      // A class with no students cannot have attendance taken, so it should
      // not appear as an outstanding task.
      if (summary.studentCount == 0) continue;
      eligible++;

      final AttendanceSession? session = await _attendance.sessionOn(
        classId: summary.id,
        date: today,
      );
      if (session == null) {
        pending.add(summary.schoolClass);
        continue;
      }
      marked++;
      final List<AttendanceRecord> records =
          await _attendance.recordsForSession(session.id);
      statuses.addAll(records.map((AttendanceRecord r) => r.status));
    }

    return TodayAttendance(
      summary: AttendanceSummary.fromStatuses(statuses),
      classesMarked: marked,
      classesTotal: eligible,
      pendingClasses: pending,
    );
  }

  Future<List<AssessmentSummary>> _assessmentSummaries(
    List<SchoolClass> classes,
  ) async {
    final List<AssessmentSummary> summaries = <AssessmentSummary>[];

    for (final SchoolClass schoolClass in classes) {
      final List<Assessment> assessments =
          await _assessments.listForClass(schoolClass.id);
      if (assessments.isEmpty) continue;

      final List<Student> roster = await _students.listForClass(schoolClass.id);
      final Map<String, int> graded = await _assessments.gradedCounts(
        assessments.map((Assessment a) => a.id),
      );
      final List<AssessmentMark> marks =
          await _assessments.marksForClass(schoolClass.id);
      final Map<String, List<AssessmentMark>> marksByAssessment =
          _groupBy(marks, (AssessmentMark m) => m.assessmentId);

      for (final Assessment assessment in assessments) {
        final List<AssessmentMark> theirs =
            marksByAssessment[assessment.id] ?? const <AssessmentMark>[];
        summaries.add(
          AssessmentSummary(
            assessment: assessment,
            className: schoolClass.name,
            gradedCount: graded[assessment.id] ?? 0,
            studentCount: roster.length,
            averagePercentage: _grading.average(
              theirs.map((AssessmentMark m) => m.percentageOf(assessment.totalMarks)),
            ),
          ),
        );
      }
    }
    return summaries;
  }

  Map<String, List<T>> _groupBy<T>(
    Iterable<T> items,
    String Function(T item) keyOf,
  ) {
    final Map<String, List<T>> grouped = <String, List<T>>{};
    for (final T item in items) {
      grouped.putIfAbsent(keyOf(item), () => <T>[]).add(item);
    }
    return grouped;
  }
}
