/// Shared enumerations.
///
/// Every value is persisted by its `name`, which is also the wire format the
/// Phase 2 backend will use, so renaming a value is a breaking schema change.
library;

/// Who the signed-in user is. `mainAdmin` is reserved for the Phase 2 React
/// dashboard and is intentionally not reachable from the mobile app.
enum UserRole {
  teacher,
  orgAdmin,
  mainAdmin;

  String get label => switch (this) {
        UserRole.teacher => 'Teacher',
        UserRole.orgAdmin => 'Organization Admin',
        UserRole.mainAdmin => 'Platform Admin',
      };

  String get description => switch (this) {
        UserRole.teacher => 'Manage your classes, students, attendance and marks',
        UserRole.orgAdmin => 'Oversee teachers and monitor organization activity',
        UserRole.mainAdmin => 'Platform level administration (web only)',
      };

  bool get canUseMobileApp => this != UserRole.mainAdmin;
}

/// Lifecycle of an account. Phase 1 only ever creates `active` accounts; the
/// other states exist so the Phase 2 approval flow slots in without a
/// migration.
enum AccountStatus {
  active,
  pending,
  suspended,
  removed;

  String get label => switch (this) {
        AccountStatus.active => 'Active',
        AccountStatus.pending => 'Pending approval',
        AccountStatus.suspended => 'Suspended',
        AccountStatus.removed => 'Removed',
      };

  bool get canSignIn => this == AccountStatus.active;
}

/// Attendance outcome for one student on one day.
///
/// The spec requires Present/Absent; Late and Short leave are supported so schools
/// that need them do not have to fall back to notes.
enum AttendanceStatus {
  present,
  absent,
  late,
  shortLeave;

  String get label => switch (this) {
        AttendanceStatus.present => 'Present',
        AttendanceStatus.absent => 'Absent',
        AttendanceStatus.late => 'Late',
        AttendanceStatus.shortLeave => 'Short leave',
      };

  String get shortLabel => switch (this) {
        AttendanceStatus.present => 'P',
        AttendanceStatus.absent => 'A',
        AttendanceStatus.late => 'L',
        AttendanceStatus.shortLeave => 'S',
      };

  /// Counts towards the "attended" numerator of the attendance percentage.
  bool get countsAsAttended =>
      this == AttendanceStatus.present || this == AttendanceStatus.late;

  /// Short leave sessions are removed from the denominator entirely.
  bool get countsTowardsTotal => this != AttendanceStatus.shortLeave;

  /// Triggers the absence notification pipeline.
  bool get notifiesGuardians => this == AttendanceStatus.absent;
}

/// Kinds of graded work a teacher can create.
enum AssessmentType {
  quiz,
  assignment,
  midterm,
  finalExam,
  presentation,
  project,
  lab,
  custom;

  String get label => switch (this) {
        AssessmentType.quiz => 'Quiz',
        AssessmentType.assignment => 'Assignment',
        AssessmentType.midterm => 'Midterm',
        AssessmentType.finalExam => 'Final Exam',
        AssessmentType.presentation => 'Presentation',
        AssessmentType.project => 'Project',
        AssessmentType.lab => 'Lab',
        AssessmentType.custom => 'Custom',
      };

  /// Default total marks offered when the teacher picks this type.
  double get suggestedTotalMarks => switch (this) {
        AssessmentType.quiz => 20,
        AssessmentType.assignment => 25,
        AssessmentType.midterm => 50,
        AssessmentType.finalExam => 100,
        AssessmentType.presentation => 20,
        AssessmentType.project => 50,
        AssessmentType.lab => 25,
        AssessmentType.custom => 100,
      };
}

/// Lifecycle of a teacher invitation issued by an organization admin.
enum InvitationStatus {
  pending,
  accepted,
  revoked,
  expired;

  String get label => switch (this) {
        InvitationStatus.pending => 'Pending',
        InvitationStatus.accepted => 'Accepted',
        InvitationStatus.revoked => 'Revoked',
        InvitationStatus.expired => 'Expired',
      };

  bool get isOpen => this == InvitationStatus.pending;
}

/// Delivery channel for an outbound guardian message.
///
/// Phase 1 ships a no-op provider; the enum exists so plugging in a real
/// WhatsApp/SMS gateway later is a provider swap, not a data migration.
enum MessageChannel {
  sms,
  whatsapp,
  email,
  none;

  String get label => switch (this) {
        MessageChannel.sms => 'SMS',
        MessageChannel.whatsapp => 'WhatsApp',
        MessageChannel.email => 'Email',
        MessageChannel.none => 'Not configured',
      };
}

/// Delivery state of a queued guardian message.
enum MessageStatus {
  queued,
  sent,
  failed,
  skipped;

  String get label => switch (this) {
        MessageStatus.queued => 'Queued',
        MessageStatus.sent => 'Sent',
        MessageStatus.failed => 'Failed',
        MessageStatus.skipped => 'Skipped',
      };
}

/// Who an absence message is addressed to.
enum RecipientRelation {
  student,
  father,
  mother,
  guardian;

  String get label => switch (this) {
        RecipientRelation.student => 'Student',
        RecipientRelation.father => 'Father',
        RecipientRelation.mother => 'Mother',
        RecipientRelation.guardian => 'Guardian',
      };
}

/// Grouping used to pick an icon/colour for in-app notifications.
enum NotificationCategory {
  general,
  attendance,
  assessment,
  invitation,
  organization,
  system;

  String get label => switch (this) {
        NotificationCategory.general => 'General',
        NotificationCategory.attendance => 'Attendance',
        NotificationCategory.assessment => 'Assessment',
        NotificationCategory.invitation => 'Invitation',
        NotificationCategory.organization => 'Organization',
        NotificationCategory.system => 'System',
      };
}

/// Audit trail verbs. Organization admins read these as the activity feed.
enum ActivityType {
  signedIn,
  signedOut,
  classCreated,
  classUpdated,
  classDeleted,
  studentAdded,
  studentUpdated,
  studentRemoved,
  studentEnrolled,
  studentUnenrolled,
  attendanceMarked,
  attendanceUpdated,
  assessmentCreated,
  assessmentUpdated,
  assessmentDeleted,
  marksEntered,
  marksUpdated,
  reportGenerated,
  teacherInvited,
  invitationRevoked,
  teacherJoined,
  teacherRemoved,
  profileUpdated,
  gradeScaleUpdated;

  String get label => switch (this) {
        ActivityType.signedIn => 'Signed in',
        ActivityType.signedOut => 'Signed out',
        ActivityType.classCreated => 'Created a class',
        ActivityType.classUpdated => 'Updated a class',
        ActivityType.classDeleted => 'Deleted a class',
        ActivityType.studentAdded => 'Added a student',
        ActivityType.studentUpdated => 'Updated a student',
        ActivityType.studentRemoved => 'Deleted a student',
        ActivityType.studentEnrolled => 'Enrolled a student',
        ActivityType.studentUnenrolled => 'Removed a student from a class',
        ActivityType.attendanceMarked => 'Marked attendance',
        ActivityType.attendanceUpdated => 'Updated attendance',
        ActivityType.assessmentCreated => 'Created an assessment',
        ActivityType.assessmentUpdated => 'Updated an assessment',
        ActivityType.assessmentDeleted => 'Deleted an assessment',
        ActivityType.marksEntered => 'Entered marks',
        ActivityType.marksUpdated => 'Updated marks',
        ActivityType.reportGenerated => 'Generated a report',
        ActivityType.teacherInvited => 'Invited a teacher',
        ActivityType.invitationRevoked => 'Revoked an invitation',
        ActivityType.teacherJoined => 'Joined the organization',
        ActivityType.teacherRemoved => 'Removed a teacher',
        ActivityType.profileUpdated => 'Updated profile',
        ActivityType.gradeScaleUpdated => 'Updated the grading scale',
      };
}

/// Sort options for the student list.
enum StudentSort {
  nameAsc,
  nameDesc,
  rollNumber,
  attendanceAsc,
  attendanceDesc,
  performanceAsc,
  performanceDesc;

  String get label => switch (this) {
        StudentSort.nameAsc => 'Name (A–Z)',
        StudentSort.nameDesc => 'Name (Z–A)',
        StudentSort.rollNumber => 'Roll number',
        StudentSort.attendanceAsc => 'Attendance (low first)',
        StudentSort.attendanceDesc => 'Attendance (high first)',
        StudentSort.performanceAsc => 'Performance (low first)',
        StudentSort.performanceDesc => 'Performance (high first)',
      };
}

/// Quick filters available on the student list.
enum StudentFilter {
  all,
  lowAttendance,
  atRisk,
  topPerformers,
  ungraded;

  String get label => switch (this) {
        StudentFilter.all => 'All students',
        StudentFilter.lowAttendance => 'Low attendance',
        StudentFilter.atRisk => 'At risk',
        StudentFilter.topPerformers => 'Top performers',
        StudentFilter.ungraded => 'Not graded yet',
      };
}
