import '../data/local/key_value_store.dart';
import '../data/local/local_database.dart';
import '../data/repositories/activity_repository.dart';
import '../data/repositories/assessment_repository.dart';
import '../data/repositories/attendance_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/class_repository.dart';
import '../data/repositories/grade_scale_repository.dart';
import '../data/repositories/local/local_activity_repository.dart';
import '../data/repositories/local/local_assessment_repository.dart';
import '../data/repositories/local/local_attendance_repository.dart';
import '../data/repositories/local/local_auth_repository.dart';
import '../data/repositories/local/local_class_repository.dart';
import '../data/repositories/local/local_grade_scale_repository.dart';
import '../data/repositories/local/local_notification_repository.dart';
import '../data/repositories/local/local_organization_repository.dart';
import '../data/repositories/local/local_student_repository.dart';
import '../data/repositories/notification_repository.dart';
import '../data/repositories/organization_repository.dart';
import '../data/repositories/student_repository.dart';
import '../data/seed/demo_seeder.dart';
import '../domain/services/absence_notification_service.dart';
import '../domain/services/analytics_service.dart';
import '../domain/services/grading_service.dart';
import '../domain/services/messaging/messaging_provider.dart';
import '../domain/services/messaging/whatsapp_messaging_provider.dart';
import '../domain/services/report_service.dart';

/// Composition root.
///
/// Builds the whole object graph once at startup and hands it to the widget
/// tree via `Provider`. Swapping the local repositories for HTTP-backed ones in
/// Phase 2 is a change to this file only — no screen imports an implementation.
class AppDependencies {
  AppDependencies._({
    required this.database,
    required this.auth,
    required this.classes,
    required this.students,
    required this.attendance,
    required this.assessments,
    required this.organizations,
    required this.notifications,
    required this.activity,
    required this.gradeScales,
    required this.analytics,
    required this.reports,
    required this.absenceNotifications,
    required this.grading,
    required this.seeder,
  });

  /// Wires everything together against a key-value store.
  ///
  /// [store] is injectable so widget tests can pass an in-memory store.
  static Future<AppDependencies> bootstrap({
    KeyValueStore? store,
    MessagingProvider messagingProvider = const WhatsAppMessagingProvider(),
    bool seedDemoData = true,
  }) async {
    final KeyValueStore resolvedStore =
        store ?? await SharedPreferencesStore.create();
    final LocalDatabase database = LocalDatabase(resolvedStore);
    await database.init();

    final DemoSeeder seeder = DemoSeeder(database);
    if (seedDemoData) {
      await seeder.seedIfEmpty();
    }

    final ActivityRepository activity = LocalActivityRepository(database);
    final NotificationRepository notifications =
        LocalNotificationRepository(database);
    final AuthRepository auth = LocalAuthRepository(
      database,
      activity: activity,
      notifications: notifications,
    );
    final ClassRepository classes =
        LocalClassRepository(database, activity: activity);
    final StudentRepository students =
        LocalStudentRepository(database, activity: activity);
    final AttendanceRepository attendance =
        LocalAttendanceRepository(database, activity: activity);
    final AssessmentRepository assessments =
        LocalAssessmentRepository(database, activity: activity);
    final GradeScaleRepository gradeScales = LocalGradeScaleRepository(database);
    final OrganizationRepository organizations = LocalOrganizationRepository(
      database,
      activity: activity,
      notifications: notifications,
    );

    const GradingService grading = GradingService();
    final AnalyticsService analytics = AnalyticsService(
      classes: classes,
      students: students,
      attendance: attendance,
      assessments: assessments,
      gradeScales: gradeScales,
      activity: activity,
      organizations: organizations,
      grading: grading,
    );
    final ReportService reports = ReportService(
      analytics: analytics,
      classes: classes,
      students: students,
      attendance: attendance,
      gradeScales: gradeScales,
      organizations: organizations,
      activity: activity,
    );
    final AbsenceNotificationService absenceNotifications =
        AbsenceNotificationService(
      notifications: notifications,
      attendance: attendance,
      provider: messagingProvider,
    );

    return AppDependencies._(
      database: database,
      auth: auth,
      classes: classes,
      students: students,
      attendance: attendance,
      assessments: assessments,
      organizations: organizations,
      notifications: notifications,
      activity: activity,
      gradeScales: gradeScales,
      analytics: analytics,
      reports: reports,
      absenceNotifications: absenceNotifications,
      grading: grading,
      seeder: seeder,
    );
  }

  final LocalDatabase database;
  final AuthRepository auth;
  final ClassRepository classes;
  final StudentRepository students;
  final AttendanceRepository attendance;
  final AssessmentRepository assessments;
  final OrganizationRepository organizations;
  final NotificationRepository notifications;
  final ActivityRepository activity;
  final GradeScaleRepository gradeScales;
  final AnalyticsService analytics;
  final ReportService reports;
  final AbsenceNotificationService absenceNotifications;
  final GradingService grading;
  final DemoSeeder seeder;

  /// Rebuilds the WhatsApp provider with a new default dialling code.
  ///
  /// Numbers stored in national format (`03001112222`) cannot be addressed
  /// without one. Left alone when a different provider is active, so tests and
  /// a future server-side gateway are not clobbered.
  void setDefaultCountryCode(String? code) {
    final MessagingProvider current = absenceNotifications.provider;
    if (current is! WhatsAppMessagingProvider) return;
    if (current.defaultCountryCode == code) return;
    absenceNotifications.provider =
        WhatsAppMessagingProvider(defaultCountryCode: code);
  }

  /// Clears every collection and reinstalls the demo dataset.
  Future<void> resetDemoData() async {
    await database.wipe();
    await seeder.seed();
  }

  Future<void> dispose() => database.dispose();
}
