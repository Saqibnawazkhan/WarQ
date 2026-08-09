import 'dart:math';

import '../../core/constants/app_constants.dart';
import '../../core/utils/date_utils.dart';
import '../../core/utils/id_generator.dart';
import '../local/local_database.dart';
import '../local/password_hasher.dart';
import '../models/models.dart';

/// Populates the database with a realistic demo dataset on first launch.
///
/// Without a backend there is nothing to sign in to, so Phase 1 ships two ready
/// accounts (an individual teacher and an organization) with enough history for
/// every screen — dashboard, attendance trends, grade distribution, reports —
/// to render meaningfully.
///
/// The random generator is seeded, so the dataset is identical on every device.
class DemoSeeder {
  DemoSeeder(this._db);

  final LocalDatabase _db;
  final Random _random = Random(20260209);

  /// Runs once; subsequent launches are a no-op.
  Future<void> seedIfEmpty() async {
    final String? flag = await _db.store.read(StorageKeys.seeded);
    if (flag == 'true' || _db.users.length > 0) return;
    await seed();
  }

  /// Wipes and rebuilds the demo dataset.
  Future<void> seed() async {
    final DateTime now = DateTime.now();

    // ---------------------------------------------------------------- users
    final String individualTeacherId = IdGenerator.generate('usr');
    final String orgAdminId = IdGenerator.generate('usr');
    final String orgTeacherId = IdGenerator.generate('usr');
    final String organizationId = IdGenerator.generate('org');

    final Organization organization = Organization(
      id: organizationId,
      name: 'Bright Future Academy',
      joinCode: 'BFA2026',
      ownerUserId: orgAdminId,
      createdAt: now.subtract(const Duration(days: 210)),
      email: 'office@brightfuture.edu',
      phone: '+92 300 1234567',
      address: '14 College Road, Lahore',
      website: 'brightfuture.edu',
    );

    final AppUser individualTeacher = AppUser(
      id: individualTeacherId,
      fullName: 'Ahmed Raza',
      email: DemoAccounts.teacherEmail,
      username: 'ahmed',
      role: UserRole.teacher,
      createdAt: now.subtract(const Duration(days: 120)),
      phone: '+92 301 5550101',
      title: 'Lecturer, Computer Science',
      bio: 'Teaching software engineering and databases since 2018.',
      lastLoginAt: now.subtract(const Duration(hours: 6)),
    );

    final AppUser orgAdmin = AppUser(
      id: orgAdminId,
      fullName: 'Fatima Khan',
      email: DemoAccounts.orgAdminEmail,
      username: 'fatima',
      role: UserRole.orgAdmin,
      createdAt: now.subtract(const Duration(days: 210)),
      phone: '+92 302 5550202',
      title: 'Academic Director',
      organizationId: organizationId,
      lastLoginAt: now.subtract(const Duration(days: 1)),
    );

    final AppUser orgTeacher = AppUser(
      id: orgTeacherId,
      fullName: 'Sarah Malik',
      email: DemoAccounts.orgTeacherEmail,
      username: 'sarah',
      role: UserRole.teacher,
      createdAt: now.subtract(const Duration(days: 95)),
      phone: '+92 303 5550303',
      title: 'Physics Teacher',
      organizationId: organizationId,
      lastLoginAt: now.subtract(const Duration(days: 2)),
    );

    await _db.organizations.put(organization);
    await _db.users.putAll(<AppUser>[individualTeacher, orgAdmin, orgTeacher]);
    for (final AppUser user in <AppUser>[individualTeacher, orgAdmin, orgTeacher]) {
      await _writeCredential(user);
    }

    // -------------------------------------------------------------- classes
    final SchoolClass softwareEngineering = _buildClass(
      teacherId: individualTeacherId,
      name: 'Software Engineering',
      subject: 'Software Engineering',
      section: 'A',
      session: '2026',
      description: 'Requirements, design patterns, testing and delivery.',
      createdDaysAgo: 100,
    );

    final SchoolClass databaseSystems = _buildClass(
      teacherId: individualTeacherId,
      name: 'Database Systems',
      subject: 'Databases',
      section: 'B',
      session: '2026',
      description: 'Relational modelling, SQL and transactions.',
      createdDaysAgo: 85,
    );

    final SchoolClass physics = _buildClass(
      teacherId: orgTeacherId,
      organizationId: organizationId,
      name: 'Physics 101',
      subject: 'Physics',
      section: 'A',
      session: '2026',
      description: 'Mechanics and thermodynamics fundamentals.',
      createdDaysAgo: 80,
    );

    await _db.classes
        .putAll(<SchoolClass>[softwareEngineering, databaseSystems, physics]);

    // ------------------------------------------------------------- students
    final List<Student> seClassStudents = await _createStudents(
      teacherId: individualTeacherId,
      names: const <String>[
        'Ahmed Bilal',
        'Ayesha Siddiqui',
        'Bilal Hussain',
        'Danish Iqbal',
        'Emaan Tariq',
        'Fahad Sheikh',
        'Hira Nawaz',
        'Imran Yousaf',
        'Kiran Aslam',
        'Musa Rehman',
        'Noor Fatima',
        'Zain Abbas',
      ],
      classId: softwareEngineering.id,
      rollPrefix: 'SE-26-',
    );

    final List<Student> dbClassStudents = await _createStudents(
      teacherId: individualTeacherId,
      names: const <String>[
        'Adeel Qureshi',
        'Farah Javed',
        'Hamza Riaz',
        'Laiba Anwar',
        'Owais Sultan',
        'Rida Kamal',
        'Talha Mehmood',
        'Zoya Hameed',
      ],
      classId: databaseSystems.id,
      rollPrefix: 'DB-26-',
    );

    // A shared student demonstrates that enrollment is a join, not ownership.
    await _db.enrollments.put(
      ClassEnrollment(
        id: IdGenerator.generate('enr'),
        classId: databaseSystems.id,
        studentId: seClassStudents.first.id,
        enrolledAt: now.subtract(const Duration(days: 70)),
      ),
    );

    final List<Student> physicsStudents = await _createStudents(
      teacherId: orgTeacherId,
      organizationId: organizationId,
      names: const <String>[
        'Areeba Shah',
        'Basit Ali',
        'Hassan Raza',
        'Iqra Baig',
        'Junaid Akhtar',
        'Mahnoor Zafar',
        'Saad Nadeem',
        'Sana Ashraf',
        'Usman Ghani',
        'Warda Latif',
      ],
      classId: physics.id,
      rollPrefix: 'PH-26-',
    );

    // ------------------------------------------------------------ attendance
    await _seedAttendance(
      schoolClass: softwareEngineering,
      students: <Student>[...seClassStudents],
      userId: individualTeacherId,
      weeks: 6,
      presentBias: 0.88,
    );
    await _seedAttendance(
      schoolClass: databaseSystems,
      students: <Student>[...dbClassStudents, seClassStudents.first],
      userId: individualTeacherId,
      weeks: 5,
      presentBias: 0.82,
    );
    await _seedAttendance(
      schoolClass: physics,
      students: physicsStudents,
      userId: orgTeacherId,
      weeks: 5,
      presentBias: 0.9,
    );

    // ----------------------------------------------------------- assessments
    await _seedAssessments(
      schoolClass: softwareEngineering,
      students: seClassStudents,
      userId: individualTeacherId,
      specs: <_AssessmentSpec>[
        _AssessmentSpec('Quiz 1', AssessmentType.quiz, 20, 42, 1.0),
        _AssessmentSpec('Assignment 1', AssessmentType.assignment, 25, 32, 0.95),
        _AssessmentSpec('Midterm Exam', AssessmentType.midterm, 50, 20, 1.0),
        _AssessmentSpec('Quiz 2', AssessmentType.quiz, 20, 8, 0.75),
      ],
    );

    await _seedAssessments(
      schoolClass: databaseSystems,
      students: <Student>[...dbClassStudents, seClassStudents.first],
      userId: individualTeacherId,
      specs: <_AssessmentSpec>[
        _AssessmentSpec('Quiz 1', AssessmentType.quiz, 20, 35, 1.0),
        _AssessmentSpec('ER Modelling Project', AssessmentType.project, 40, 14, 0.9),
      ],
    );

    await _seedAssessments(
      schoolClass: physics,
      students: physicsStudents,
      userId: orgTeacherId,
      specs: <_AssessmentSpec>[
        _AssessmentSpec('Quiz 1', AssessmentType.quiz, 20, 30, 1.0),
        _AssessmentSpec('Lab Presentation', AssessmentType.presentation, 15, 12, 1.0),
        _AssessmentSpec('Midterm Exam', AssessmentType.midterm, 50, 5, 0.8),
      ],
    );

    // ----------------------------------------------------------- invitations
    await _db.invitations.put(
      Invitation(
        id: IdGenerator.generate('inv'),
        organizationId: organizationId,
        email: 'omar.hashmi@brightfuture.edu',
        token: IdGenerator.code(length: 10),
        invitedByUserId: orgAdminId,
        createdAt: now.subtract(const Duration(days: 3)),
        expiresAt: now.add(const Duration(days: 11)),
        inviteeName: 'Omar Hashmi',
        message: 'Looking forward to having you on the maths team.',
      ),
    );
    await _db.invitations.put(
      Invitation(
        id: IdGenerator.generate('inv'),
        organizationId: organizationId,
        email: DemoAccounts.orgTeacherEmail,
        token: IdGenerator.code(length: 10),
        invitedByUserId: orgAdminId,
        createdAt: now.subtract(const Duration(days: 95)),
        expiresAt: now.subtract(const Duration(days: 81)),
        status: InvitationStatus.accepted,
        acceptedAt: now.subtract(const Duration(days: 94)),
        acceptedByUserId: orgTeacherId,
      ),
    );

    // --------------------------------------------------------- notifications
    await _db.notifications.putAll(<AppNotification>[
      AppNotification(
        id: IdGenerator.generate('ntf'),
        userId: individualTeacherId,
        title: 'Attendance reminder',
        body: 'You have not marked attendance for Database Systems today.',
        category: NotificationCategory.attendance,
        createdAt: now.subtract(const Duration(hours: 3)),
      ),
      AppNotification(
        id: IdGenerator.generate('ntf'),
        userId: individualTeacherId,
        title: 'Marks pending',
        body: 'Quiz 2 in Software Engineering still has ungraded students.',
        category: NotificationCategory.assessment,
        createdAt: now.subtract(const Duration(days: 1)),
      ),
      AppNotification(
        id: IdGenerator.generate('ntf'),
        userId: orgAdminId,
        title: 'Invitation pending',
        body: 'Omar Hashmi has not accepted the invitation yet.',
        category: NotificationCategory.invitation,
        organizationId: organizationId,
        createdAt: now.subtract(const Duration(days: 2)),
      ),
      AppNotification(
        id: IdGenerator.generate('ntf'),
        userId: orgAdminId,
        title: 'Weekly summary',
        body: 'Sarah Malik marked 5 attendance sessions this week.',
        category: NotificationCategory.organization,
        organizationId: organizationId,
        isRead: true,
        createdAt: now.subtract(const Duration(days: 4)),
      ),
    ]);

    // ------------------------------------------------------------- activity
    await _db.activityLogs.putAll(<ActivityLog>[
      _log(
        actor: individualTeacher,
        type: ActivityType.classCreated,
        summary: 'Created class Software Engineering',
        daysAgo: 100,
        classId: softwareEngineering.id,
      ),
      _log(
        actor: individualTeacher,
        type: ActivityType.classCreated,
        summary: 'Created class Database Systems',
        daysAgo: 85,
        classId: databaseSystems.id,
      ),
      _log(
        actor: orgTeacher,
        type: ActivityType.classCreated,
        summary: 'Created class Physics 101',
        daysAgo: 80,
        organizationId: organizationId,
        classId: physics.id,
      ),
      _log(
        actor: orgAdmin,
        type: ActivityType.teacherInvited,
        summary: 'Invited omar.hashmi@brightfuture.edu to Bright Future Academy',
        daysAgo: 3,
        organizationId: organizationId,
      ),
    ]);

    await _db.store.write(StorageKeys.seeded, 'true');
  }

  // ---------------------------------------------------------------------------
  // Builders
  // ---------------------------------------------------------------------------

  Future<void> _writeCredential(AppUser user) async {
    final String salt = PasswordHasher.generateSalt();
    await _db.credentials.put(
      AuthCredential(
        userId: user.id,
        email: user.email,
        username: user.username,
        salt: salt,
        passwordHash: PasswordHasher.hash(DemoAccounts.password, salt),
        updatedAt: DateTime.now(),
      ),
    );
  }

  SchoolClass _buildClass({
    required String teacherId,
    required String name,
    required int createdDaysAgo,
    String? organizationId,
    String? subject,
    String? section,
    String? session,
    String? description,
  }) {
    return SchoolClass(
      id: IdGenerator.generate('cls'),
      teacherId: teacherId,
      name: name,
      createdAt: DateTime.now().subtract(Duration(days: createdDaysAgo)),
      organizationId: organizationId,
      subject: subject,
      section: section,
      session: session,
      description: description,
      colorSeed: name,
    );
  }

  Future<List<Student>> _createStudents({
    required String teacherId,
    required List<String> names,
    required String classId,
    required String rollPrefix,
    String? organizationId,
  }) async {
    final List<Student> students = <Student>[];
    final List<ClassEnrollment> enrollments = <ClassEnrollment>[];

    for (int i = 0; i < names.length; i++) {
      final String name = names[i];
      // Deliberately leave some contact fields blank: the app must handle
      // students with no reachable guardian.
      final bool hasStudentPhone = i % 3 != 0;
      final bool hasFatherPhone = i % 4 != 3;
      final bool hasMotherPhone = i % 5 == 0 || i % 3 == 1;

      final Student student = Student(
        id: IdGenerator.generate('stu'),
        ownerTeacherId: teacherId,
        organizationId: organizationId,
        fullName: name,
        createdAt: DateTime.now().subtract(Duration(days: 90 - i)),
        rollNumber: '$rollPrefix${(i + 1).toString().padLeft(3, '0')}',
        studentPhone: hasStudentPhone ? _phone(3, i) : null,
        fatherPhone: hasFatherPhone ? _phone(4, i) : null,
        motherPhone: hasMotherPhone ? _phone(5, i) : null,
        guardianName: hasFatherPhone ? null : 'Guardian of ${name.split(' ').first}',
      );
      students.add(student);
      enrollments.add(
        ClassEnrollment(
          id: IdGenerator.generate('enr'),
          classId: classId,
          studentId: student.id,
          enrolledAt: DateTime.now().subtract(Duration(days: 80 - i)),
        ),
      );
    }

    await _db.students.putAll(students);
    await _db.enrollments.putAll(enrollments);
    return students;
  }

  String _phone(int seed, int index) {
    final int suffix = 1000000 + ((seed * 7919 + index * 131) % 8999999);
    return '+92 3${seed}0 $suffix';
  }

  /// Creates one session per weekday for the past [weeks] weeks.
  Future<void> _seedAttendance({
    required SchoolClass schoolClass,
    required List<Student> students,
    required String userId,
    required int weeks,
    required double presentBias,
  }) async {
    if (students.isEmpty) return;

    final List<AttendanceSession> sessions = <AttendanceSession>[];
    final List<AttendanceRecord> records = <AttendanceRecord>[];
    final DateTime today = AppDate.today();

    for (int dayOffset = weeks * 7; dayOffset >= 0; dayOffset--) {
      final DateTime day = today.subtract(Duration(days: dayOffset));
      // Classes meet Monday, Wednesday and Friday.
      if (day.weekday != DateTime.monday &&
          day.weekday != DateTime.wednesday &&
          day.weekday != DateTime.friday) {
        continue;
      }
      // Leave today unmarked so the dashboard has a pending action to show.
      if (AppDate.isSameDay(day, today)) continue;

      final AttendanceSession session = AttendanceSession(
        id: IdGenerator.generate('ses'),
        classId: schoolClass.id,
        date: day,
        takenByUserId: userId,
        createdAt: day.add(const Duration(hours: 9)),
      );
      sessions.add(session);

      for (int i = 0; i < students.length; i++) {
        // Give a couple of students a visibly weaker record so the "low
        // attendance" filter and the at-risk badges have something to show.
        final double bias = i == 2 ? presentBias - 0.28 : presentBias;
        final double roll = _random.nextDouble();
        final AttendanceStatus status;
        if (roll < bias) {
          status = AttendanceStatus.present;
        } else if (roll < bias + 0.06) {
          status = AttendanceStatus.late;
        } else if (roll < bias + 0.09) {
          status = AttendanceStatus.shortLeave;
        } else {
          status = AttendanceStatus.absent;
        }

        records.add(
          AttendanceRecord(
            id: IdGenerator.generate('atr'),
            sessionId: session.id,
            classId: schoolClass.id,
            studentId: students[i].id,
            status: status,
            markedAt: session.createdAt,
            notified: status.notifiesGuardians,
          ),
        );
      }
    }

    await _db.attendanceSessions.putAll(sessions);
    await _db.attendanceRecords.putAll(records);
  }

  Future<void> _seedAssessments({
    required SchoolClass schoolClass,
    required List<Student> students,
    required String userId,
    required List<_AssessmentSpec> specs,
  }) async {
    final List<Assessment> assessments = <Assessment>[];
    final List<AssessmentMark> marks = <AssessmentMark>[];
    final DateTime today = AppDate.today();

    for (final _AssessmentSpec spec in specs) {
      final Assessment assessment = Assessment(
        id: IdGenerator.generate('asm'),
        classId: schoolClass.id,
        name: spec.name,
        type: spec.type,
        date: today.subtract(Duration(days: spec.daysAgo)),
        totalMarks: spec.totalMarks,
        createdByUserId: userId,
        createdAt: today.subtract(Duration(days: spec.daysAgo + 2)),
      );
      assessments.add(assessment);

      for (int i = 0; i < students.length; i++) {
        // `gradedRatio < 1` leaves some students ungraded, which the UI must
        // render as "—" rather than zero.
        if (_random.nextDouble() > spec.gradedRatio) continue;

        // Each student keeps a consistent ability level across assessments so
        // the progression chart is not pure noise.
        final double ability = 0.55 + ((i * 37) % 40) / 100;
        final double noise = (_random.nextDouble() - 0.5) * 0.18;
        final double ratio = (ability + noise).clamp(0.15, 1.0);
        final double score = (spec.totalMarks * ratio);
        final double rounded = (score * 2).roundToDouble() / 2;

        marks.add(
          AssessmentMark(
            id: IdGenerator.generate('mrk'),
            assessmentId: assessment.id,
            classId: schoolClass.id,
            studentId: students[i].id,
            recordedAt: assessment.date.add(const Duration(days: 1)),
            marksObtained: rounded,
          ),
        );
      }
    }

    await _db.assessments.putAll(assessments);
    await _db.marks.putAll(marks);
  }

  ActivityLog _log({
    required AppUser actor,
    required ActivityType type,
    required String summary,
    required int daysAgo,
    String? organizationId,
    String? classId,
  }) {
    return ActivityLog(
      id: IdGenerator.generate('act'),
      actorUserId: actor.id,
      actorName: actor.displayName,
      type: type,
      summary: summary,
      createdAt: DateTime.now().subtract(Duration(days: daysAgo)),
      organizationId: organizationId,
      classId: classId,
    );
  }
}

class _AssessmentSpec {
  const _AssessmentSpec(
    this.name,
    this.type,
    this.totalMarks,
    this.daysAgo,
    this.gradedRatio,
  );

  final String name;
  final AssessmentType type;
  final double totalMarks;
  final int daysAgo;

  /// Fraction of students that have a recorded score.
  final double gradedRatio;
}
