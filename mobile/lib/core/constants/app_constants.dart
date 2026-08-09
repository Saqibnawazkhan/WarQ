/// Application-wide constants.
///
/// Phase 1 keeps everything local-first, but every key here is namespaced so a
/// future backend sync layer can coexist with cached local data.
class AppConstants {
  const AppConstants._();

  static const String appName = 'EDU Manager';
  static const String appTagline = 'Classroom management, simplified';
  static const String appVersion = '1.0.0';

  /// Bumped whenever the persisted local schema changes in a breaking way.
  static const int schemaVersion = 1;

  /// Prefix for every persisted key so the app never collides with plugins.
  static const String storagePrefix = 'edu_manager';

  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration searchDebounce = Duration(milliseconds: 280);
  static const Duration shortAnimation = Duration(milliseconds: 180);
  static const Duration mediumAnimation = Duration(milliseconds: 300);

  /// Invitations expire after this window.
  static const Duration invitationValidity = Duration(days: 14);

  /// Password reset codes are short-lived.
  static const Duration resetCodeValidity = Duration(minutes: 30);

  static const int minPasswordLength = 6;

  /// Attendance below this percentage is surfaced as "at risk" in the UI.
  static const double attendanceRiskThreshold = 75;

  /// Overall marks below this percentage flag a student as needing attention.
  static const double performanceRiskThreshold = 50;

  static const int recentItemsLimit = 5;
  static const int activityFeedLimit = 50;
}

/// Keys used by the local persistence layer.
class StorageKeys {
  const StorageKeys._();

  static const String schemaVersion = '${AppConstants.storagePrefix}.schema_version';
  static const String session = '${AppConstants.storagePrefix}.session';
  static const String themeMode = '${AppConstants.storagePrefix}.theme_mode';
  static const String countryCode = '${AppConstants.storagePrefix}.country_code';
  static const String seeded = '${AppConstants.storagePrefix}.seeded';

  static const String users = '${AppConstants.storagePrefix}.users';
  static const String credentials = '${AppConstants.storagePrefix}.credentials';
  static const String organizations = '${AppConstants.storagePrefix}.organizations';
  static const String classes = '${AppConstants.storagePrefix}.classes';
  static const String students = '${AppConstants.storagePrefix}.students';
  static const String enrollments = '${AppConstants.storagePrefix}.enrollments';
  static const String attendanceSessions = '${AppConstants.storagePrefix}.attendance_sessions';
  static const String attendanceRecords = '${AppConstants.storagePrefix}.attendance_records';
  static const String assessments = '${AppConstants.storagePrefix}.assessments';
  static const String assessmentMarks = '${AppConstants.storagePrefix}.assessment_marks';
  static const String gradeScales = '${AppConstants.storagePrefix}.grade_scales';
  static const String notifications = '${AppConstants.storagePrefix}.notifications';
  static const String invitations = '${AppConstants.storagePrefix}.invitations';
  static const String activityLogs = '${AppConstants.storagePrefix}.activity_logs';
  static const String outboundMessages = '${AppConstants.storagePrefix}.outbound_messages';
}

/// Credentials created by the seeder so the app is usable on first launch.
class DemoAccounts {
  const DemoAccounts._();

  static const String teacherEmail = 'teacher@edu.com';
  static const String orgAdminEmail = 'admin@edu.com';
  static const String orgTeacherEmail = 'sarah@edu.com';
  static const String password = 'password123';
}
