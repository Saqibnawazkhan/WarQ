import '../../core/utils/date_utils.dart';
import '../models/models.dart';

/// Translates between Postgres rows and the app's models.
///
/// The database speaks `snake_case`, uses Postgres enums and splits a couple of
/// things the app keeps together (a student's phone numbers live in their own
/// table). Every one of those differences is resolved here, so repositories
/// read as plain data access and no widget ever sees a raw column name.
///
/// Where a model field has no column, the mapper says so explicitly rather than
/// inventing a value.
class Rows {
  const Rows._();

  // ---------------------------------------------------------------------------
  // Primitives
  // ---------------------------------------------------------------------------

  static String str(Map<String, dynamic> row, String key, {String fallback = ''}) {
    final Object? value = row[key];
    return value == null ? fallback : value.toString();
  }

  static String? strOrNull(Map<String, dynamic> row, String key) {
    final Object? value = row[key];
    if (value == null) return null;
    final String text = value.toString().trim();
    return text.isEmpty ? null : text;
  }

  static bool boolean(Map<String, dynamic> row, String key, {bool fallback = false}) {
    final Object? value = row[key];
    if (value is bool) return value;
    if (value is String) return value.toLowerCase() == 'true';
    return fallback;
  }

  static double? numOrNull(Map<String, dynamic> row, String key) {
    final Object? value = row[key];
    if (value == null) return null;
    if (value is num) return value.toDouble();
    return double.tryParse(value.toString());
  }

  static double number(Map<String, dynamic> row, String key, {double fallback = 0}) =>
      numOrNull(row, key) ?? fallback;

  static DateTime? timeOrNull(Map<String, dynamic> row, String key) {
    final Object? value = row[key];
    if (value == null) return null;
    return DateTime.tryParse(value.toString())?.toLocal();
  }

  static DateTime time(Map<String, dynamic> row, String key, {DateTime? fallback}) =>
      timeOrNull(row, key) ?? fallback ?? DateTime.now();

  /// A Postgres `date`, which carries no time zone and must not be shifted.
  static DateTime dateOnly(Map<String, dynamic> row, String key) {
    final Object? value = row[key];
    final DateTime? parsed =
        value == null ? null : DateTime.tryParse(value.toString());
    return parsed == null ? AppDate.today() : AppDate.dateOnly(parsed);
  }

  static Map<String, dynamic> meta(Map<String, dynamic> row, String key) {
    final Object? value = row[key];
    if (value is Map) {
      return value.map((Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  static List<Map<String, dynamic>> children(Map<String, dynamic> row, String key) {
    final Object? value = row[key];
    if (value is List) {
      return value
          .whereType<Map<Object?, Object?>>()
          .map((Map<Object?, Object?> e) =>
              e.map((Object? k, Object? v) => MapEntry<String, dynamic>(k.toString(), v)))
          .toList(growable: false);
    }
    return const <Map<String, dynamic>>[];
  }

  // ---------------------------------------------------------------------------
  // Enums
  // ---------------------------------------------------------------------------

  static UserRole role(String? value) => switch (value) {
        'org_admin' => UserRole.orgAdmin,
        'main_admin' => UserRole.mainAdmin,
        _ => UserRole.teacher,
      };

  static String roleToDb(UserRole value) => switch (value) {
        UserRole.orgAdmin => 'org_admin',
        UserRole.mainAdmin => 'main_admin',
        UserRole.teacher => 'teacher',
      };

  static AccountStatus accountStatus(String? value) => switch (value) {
        'active' => AccountStatus.active,
        'suspended' => AccountStatus.suspended,
        _ => AccountStatus.pending,
      };

  static AttendanceStatus mark(String? value) => switch (value) {
        'absent' => AttendanceStatus.absent,
        'late' => AttendanceStatus.late,
        'short_leave' => AttendanceStatus.shortLeave,
        _ => AttendanceStatus.present,
      };

  static String markToDb(AttendanceStatus value) => switch (value) {
        AttendanceStatus.present => 'present',
        AttendanceStatus.absent => 'absent',
        AttendanceStatus.late => 'late',
        AttendanceStatus.shortLeave => 'short_leave',
      };

  static AssessmentType assessmentType(String? value) => switch (value) {
        'assignment' => AssessmentType.assignment,
        'midterm' => AssessmentType.midterm,
        'final' => AssessmentType.finalExam,
        'presentation' => AssessmentType.presentation,
        'project' => AssessmentType.project,
        'lab' => AssessmentType.lab,
        'custom' => AssessmentType.custom,
        _ => AssessmentType.quiz,
      };

  static String assessmentTypeToDb(AssessmentType value) => switch (value) {
        AssessmentType.quiz => 'quiz',
        AssessmentType.assignment => 'assignment',
        AssessmentType.midterm => 'midterm',
        AssessmentType.finalExam => 'final',
        AssessmentType.presentation => 'presentation',
        AssessmentType.project => 'project',
        AssessmentType.lab => 'lab',
        AssessmentType.custom => 'custom',
      };

  static InvitationStatus invitationStatus(String? value) => switch (value) {
        'accepted' => InvitationStatus.accepted,
        'revoked' => InvitationStatus.revoked,
        'expired' => InvitationStatus.expired,
        _ => InvitationStatus.pending,
      };

  static RecipientRelation contactLabel(String? value) => switch (value) {
        'father' => RecipientRelation.father,
        'mother' => RecipientRelation.mother,
        'student' => RecipientRelation.student,
        _ => RecipientRelation.guardian,
      };

  static String contactLabelToDb(RecipientRelation value) => switch (value) {
        RecipientRelation.father => 'father',
        RecipientRelation.mother => 'mother',
        RecipientRelation.student => 'student',
        RecipientRelation.guardian => 'guardian',
      };

  static MessageChannel channel(String? value) => switch (value) {
        'whatsapp' => MessageChannel.whatsapp,
        'sms' => MessageChannel.sms,
        'email' => MessageChannel.email,
        _ => MessageChannel.none,
      };

  static String channelToDb(MessageChannel value) => switch (value) {
        MessageChannel.sms => 'sms',
        MessageChannel.email => 'email',
        // in_app is the only remaining value the column accepts, and a queued
        // notice with no channel yet is closest to "not sent anywhere".
        MessageChannel.none => 'in_app',
        MessageChannel.whatsapp => 'whatsapp',
      };

  /// The database groups activity into five buckets for its feed filters, while
  /// the app distinguishes two dozen actions. The bucket goes in the column and
  /// the precise action in `meta`, so nothing is lost and both read naturally.
  static String activityBucket(ActivityType value) => switch (value) {
        ActivityType.attendanceMarked ||
        ActivityType.attendanceUpdated =>
          'attendance',
        ActivityType.marksEntered ||
        ActivityType.marksUpdated ||
        ActivityType.assessmentCreated ||
        ActivityType.assessmentUpdated ||
        ActivityType.assessmentDeleted =>
          'marks',
        ActivityType.reportGenerated => 'alerts',
        _ => 'admin',
      };

  static ActivityType activityType(Map<String, dynamic> row) {
    final String? exact = strOrNull(meta(row, 'meta'), 'action');
    if (exact != null) {
      for (final ActivityType value in ActivityType.values) {
        if (value.name == exact) return value;
      }
    }
    // Fallback for rows written by the database's own triggers and RPCs, which
    // only know the five buckets.
    return switch (str(row, 'type')) {
      'attendance' => ActivityType.attendanceMarked,
      'marks' => ActivityType.marksEntered,
      'alerts' => ActivityType.reportGenerated,
      _ => ActivityType.profileUpdated,
    };
  }

  static String notificationBucket(NotificationCategory value) => switch (value) {
        NotificationCategory.attendance => 'attendance',
        NotificationCategory.assessment => 'marks',
        _ => 'admin',
      };

  static NotificationCategory notificationCategory(Map<String, dynamic> row) {
    final String? exact = strOrNull(meta(row, 'meta'), 'category');
    if (exact != null) {
      for (final NotificationCategory value in NotificationCategory.values) {
        if (value.name == exact) return value;
      }
    }
    return switch (str(row, 'type')) {
      'attendance' => NotificationCategory.attendance,
      'marks' => NotificationCategory.assessment,
      'subscription' => NotificationCategory.organization,
      _ => NotificationCategory.general,
    };
  }

  // ---------------------------------------------------------------------------
  // Entities
  // ---------------------------------------------------------------------------

  static AppUser user(Map<String, dynamic> row) => AppUser(
        id: str(row, 'id'),
        fullName: str(row, 'full_name'),
        email: str(row, 'email'),
        role: role(strOrNull(row, 'role')),
        createdAt: time(row, 'created_at'),
        phone: strOrNull(row, 'phone'),
        organizationId: strOrNull(row, 'organization_id'),
        status: accountStatus(strOrNull(row, 'status')),
        title: strOrNull(row, 'title'),
        bio: strOrNull(row, 'bio'),
        updatedAt: timeOrNull(row, 'updated_at'),
      );

  static Organization organization(Map<String, dynamic> row) {
    final String id = str(row, 'id');
    return Organization(
      id: id,
      name: str(row, 'name'),
      city: strOrNull(row, 'city'),
      // Display only. There is no join-by-code flow; teachers arrive through a
      // tokenised invitation.
      joinCode: id.replaceAll('-', '').substring(0, 6).toUpperCase(),
      ownerUserId: str(row, 'owner_profile_id'),
      createdAt: time(row, 'created_at'),
      email: strOrNull(row, 'email'),
      phone: strOrNull(row, 'phone'),
      address: strOrNull(row, 'address'),
      website: strOrNull(row, 'website'),
      updatedAt: timeOrNull(row, 'updated_at'),
    );
  }

  static SchoolClass schoolClass(Map<String, dynamic> row) => SchoolClass(
        id: str(row, 'id'),
        teacherId: str(row, 'teacher_id'),
        name: str(row, 'name'),
        createdAt: time(row, 'created_at'),
        organizationId: strOrNull(row, 'organization_id'),
        subject: strOrNull(row, 'subject'),
        section: strOrNull(row, 'section'),
        session: strOrNull(row, 'session'),
        description: strOrNull(row, 'description'),
        colorSeed: strOrNull(row, 'color_index'),
        archived: row['archived_at'] != null,
        updatedAt: timeOrNull(row, 'updated_at'),
      );

  /// Expects `student_contacts(*)` to be embedded in the select; without it the
  /// student simply comes back with no numbers, which reads as "nobody to call".
  static Student student(Map<String, dynamic> row) {
    String? phoneFor(RecipientRelation relation) {
      for (final Map<String, dynamic> contact in children(row, 'student_contacts')) {
        if (contactLabel(strOrNull(contact, 'label')) == relation &&
            boolean(contact, 'receives_alerts', fallback: true)) {
          return strOrNull(contact, 'phone');
        }
      }
      return null;
    }

    return Student(
      id: str(row, 'id'),
      ownerTeacherId: str(row, 'teacher_id'),
      fullName: str(row, 'full_name'),
      createdAt: time(row, 'created_at'),
      organizationId: strOrNull(row, 'organization_id'),
      rollNumber: strOrNull(row, 'roll_no'),
      studentPhone: phoneFor(RecipientRelation.student),
      fatherPhone: phoneFor(RecipientRelation.father),
      motherPhone: phoneFor(RecipientRelation.mother),
      guardianName: strOrNull(row, 'guardian_name'),
      email: strOrNull(row, 'email'),
      address: strOrNull(row, 'address'),
      notes: strOrNull(row, 'notes'),
      updatedAt: timeOrNull(row, 'updated_at'),
    );
  }

  static ClassEnrollment enrollment(Map<String, dynamic> row) => ClassEnrollment(
        id: str(row, 'id'),
        classId: str(row, 'class_id'),
        studentId: str(row, 'student_id'),
        enrolledAt: time(row, 'enrolled_at'),
        active: row['unenrolled_at'] == null,
        unenrolledAt: timeOrNull(row, 'unenrolled_at'),
      );

  static AttendanceSession session(Map<String, dynamic> row) => AttendanceSession(
        id: str(row, 'id'),
        classId: str(row, 'class_id'),
        date: dateOnly(row, 'date'),
        takenByUserId: str(row, 'taken_by'),
        createdAt: time(row, 'created_at'),
        note: strOrNull(row, 'note'),
        updatedAt: timeOrNull(row, 'updated_at'),
      );

  /// attendance_records has no surrogate key - it is keyed by
  /// (session_id, student_id) - so the model's id is composed from the pair.
  /// [classId] and [markedAt] come from the owning session.
  static AttendanceRecord attendanceRecord(
    Map<String, dynamic> row, {
    required String classId,
    required DateTime markedAt,
    bool notified = false,
  }) {
    final String sessionId = str(row, 'session_id');
    final String studentId = str(row, 'student_id');
    return AttendanceRecord(
      id: '$sessionId:$studentId',
      sessionId: sessionId,
      classId: classId,
      studentId: studentId,
      status: mark(strOrNull(row, 'mark')),
      markedAt: markedAt,
      notified: notified,
    );
  }

  static Assessment assessment(Map<String, dynamic> row) => Assessment(
        id: str(row, 'id'),
        classId: str(row, 'class_id'),
        name: str(row, 'name'),
        type: assessmentType(strOrNull(row, 'type')),
        date: dateOnly(row, 'date'),
        totalMarks: number(row, 'total_marks', fallback: 100),
        // No column: the database attributes activity to the caller itself, so
        // nothing in the app reads this back.
        createdByUserId: '',
        createdAt: time(row, 'created_at'),
        customTypeLabel: strOrNull(row, 'custom_type_label'),
        description: strOrNull(row, 'description'),
        updatedAt: timeOrNull(row, 'updated_at'),
      );

  /// marks is keyed by (assessment_id, student_id), so the id is composed.
  static AssessmentMark assessmentMark(
    Map<String, dynamic> row, {
    required String classId,
  }) {
    final String assessmentId = str(row, 'assessment_id');
    final String studentId = str(row, 'student_id');
    final DateTime at = time(row, 'updated_at');
    return AssessmentMark(
      id: '$assessmentId:$studentId',
      assessmentId: assessmentId,
      classId: classId,
      studentId: studentId,
      recordedAt: at,
      marksObtained: numOrNull(row, 'score'),
      remarks: strOrNull(row, 'remarks'),
      absent: boolean(row, 'absent'),
      updatedAt: at,
    );
  }

  static GradeScale gradeScale(Map<String, dynamic> row) {
    final List<GradeBand> bands = <GradeBand>[
      for (final Map<String, dynamic> band in children(row, 'bands'))
        GradeBand(
          label: str(band, 'grade', fallback: '—'),
          minPercent: number(band, 'min'),
          gpa: numOrNull(band, 'gpa'),
          remark: strOrNull(band, 'remark'),
        ),
    ];
    return GradeScale(
      id: str(row, 'id'),
      name: str(row, 'name', fallback: 'Standard scale'),
      bands: bands.isEmpty ? GradeScale.defaultBands : bands,
      createdAt: time(row, 'created_at'),
      organizationId: strOrNull(row, 'organization_id'),
      isDefault: row['organization_id'] == null,
      passPercent: number(row, 'pass_percent', fallback: 50),
      updatedAt: timeOrNull(row, 'updated_at'),
    );
  }

  static List<Map<String, dynamic>> bandsToDb(List<GradeBand> bands) => <Map<String, dynamic>>[
        for (final GradeBand band in bands)
          <String, dynamic>{
            'grade': band.label,
            'min': band.minPercent,
            if (band.gpa != null) 'gpa': band.gpa,
            if (band.remark != null) 'remark': band.remark,
          },
      ];

  static Invitation invitation(Map<String, dynamic> row) => Invitation(
        id: str(row, 'id'),
        organizationId: str(row, 'organization_id'),
        email: str(row, 'email'),
        token: str(row, 'token'),
        invitedByUserId: str(row, 'invited_by'),
        createdAt: time(row, 'created_at'),
        expiresAt: time(row, 'expires_at'),
        status: invitationStatus(strOrNull(row, 'status')),
        inviteeName: strOrNull(row, 'full_name'),
        acceptedAt: timeOrNull(row, 'accepted_at'),
        acceptedByUserId: strOrNull(row, 'accepted_by'),
      );

  static AppNotification notification(Map<String, dynamic> row) => AppNotification(
        id: str(row, 'id'),
        userId: str(row, 'profile_id'),
        title: str(row, 'title'),
        body: str(row, 'body'),
        category: notificationCategory(row),
        createdAt: time(row, 'created_at'),
        isRead: row['read_at'] != null,
        organizationId: strOrNull(meta(row, 'meta'), 'organization_id'),
        relatedEntityType: strOrNull(meta(row, 'meta'), 'entity_type'),
        relatedEntityId: strOrNull(meta(row, 'meta'), 'entity_id'),
      );

  static ActivityLog activityLog(Map<String, dynamic> row) {
    final Map<String, dynamic> extra = meta(row, 'meta');
    return ActivityLog(
      id: str(row, 'id'),
      actorUserId: str(row, 'actor_id'),
      type: activityType(row),
      summary: str(row, 'message'),
      createdAt: time(row, 'created_at'),
      actorName: strOrNull(row, 'actor_name'),
      organizationId: strOrNull(row, 'organization_id'),
      entityType: strOrNull(extra, 'entity_type'),
      entityId: strOrNull(extra, 'entity_id'),
      classId: strOrNull(extra, 'class_id'),
      detail: strOrNull(extra, 'detail'),
    );
  }

  static MessageStatus messageStatus(String? value) => switch (value) {
        'sent' => MessageStatus.sent,
        'failed' => MessageStatus.failed,
        'skipped' => MessageStatus.skipped,
        _ => MessageStatus.queued,
      };

  static OutboundMessage guardianMessage(Map<String, dynamic> row) => OutboundMessage(
        id: str(row, 'id'),
        recipientPhone: str(row, 'recipient_phone'),
        relation: contactLabel(strOrNull(row, 'recipient_label')),
        body: str(row, 'body'),
        channel: channel(strOrNull(row, 'channel')),
        status: messageStatus(strOrNull(row, 'status')),
        createdAt: time(row, 'created_at'),
        studentId: strOrNull(row, 'student_id'),
        studentName: strOrNull(row, 'student_name'),
        classId: strOrNull(row, 'class_id'),
        className: strOrNull(row, 'class_name'),
        attendanceRecordId: strOrNull(row, 'attendance_session_id'),
        requestedByUserId: strOrNull(row, 'requested_by'),
        organizationId: strOrNull(row, 'organization_id'),
        sentAt: timeOrNull(row, 'sent_at'),
        failureReason: strOrNull(row, 'failure_reason'),
      );

  static String statusToDb(MessageStatus value) => switch (value) {
        MessageStatus.sent => 'sent',
        MessageStatus.failed => 'failed',
        MessageStatus.skipped => 'skipped',
        MessageStatus.queued => 'queued',
      };
}
