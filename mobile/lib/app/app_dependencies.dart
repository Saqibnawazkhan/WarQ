import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/config/supabase_config.dart';
import '../core/error/failure.dart';
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
import '../data/repositories/supabase/supabase_activity_repository.dart';
import '../data/repositories/supabase/supabase_assessment_repository.dart';
import '../data/repositories/supabase/supabase_attendance_repository.dart';
import '../data/repositories/supabase/supabase_auth_repository.dart';
import '../data/repositories/supabase/supabase_class_repository.dart';
import '../data/repositories/supabase/supabase_grade_scale_repository.dart';
import '../data/repositories/supabase/supabase_notification_repository.dart';
import '../data/repositories/supabase/supabase_organization_repository.dart';
import '../data/repositories/supabase/supabase_student_repository.dart';
import '../data/seed/demo_seeder.dart';
import '../domain/services/absence_notification_service.dart';
import '../domain/services/analytics_service.dart';
import '../domain/services/grading_service.dart';
import '../domain/services/messaging/messaging_provider.dart';
import '../domain/services/messaging/whatsapp_messaging_provider.dart';
import '../domain/services/report_service.dart';

/// Where the app's data actually lives.
enum AppBackend {
  /// The shared Supabase project. What a real install runs on, and the reason
  /// the phone and the web app see the same classes.
  supabase,

  /// On-device storage only. Used by the test suite, which must not depend on a
  /// network or on the state of a live database.
  local,
}

/// Composition root.
///
/// Builds the whole object graph once at startup and hands it to the widget
/// tree via `Provider`. No screen imports an implementation, so which backend
/// is in use is decided here and nowhere else.
class AppDependencies {
  AppDependencies._({
    required this.backend,
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

  /// Wires everything together.
  ///
  /// [store] is injectable so widget tests can pass an in-memory store.
  /// [backend] decides where the data lives; see [AppBackend].
  static Future<AppDependencies> bootstrap({
    KeyValueStore? store,
    MessagingProvider messagingProvider = const WhatsAppMessagingProvider(),
    bool seedDemoData = false,
    AppBackend backend = AppBackend.supabase,
  }) async {
    final KeyValueStore resolvedStore =
        store ?? await SharedPreferencesStore.create();

    // Kept whichever backend is in use: it owns the event bus the controllers
    // listen to, and the settings that belong to the device rather than the
    // account. Only its collections go unused when the data is remote.
    final LocalDatabase database = LocalDatabase(resolvedStore);
    await database.init();

    final DemoSeeder seeder = DemoSeeder(database);
    // Demo data would be indistinguishable from a teacher's real classes once
    // the app is reading a shared database, so it is only ever installed into
    // on-device storage.
    if (seedDemoData && backend == AppBackend.local) {
      await seeder.seedIfEmpty();
    }

    final ActivityRepository activity;
    final NotificationRepository notifications;
    final AuthRepository auth;
    final ClassRepository classes;
    final StudentRepository students;
    final AttendanceRepository attendance;
    final AssessmentRepository assessments;
    final GradeScaleRepository gradeScales;
    final OrganizationRepository organizations;

    switch (backend) {
      case AppBackend.supabase:
        if (!SupabaseConfig.isConfigured) {
          throw const AppFailure.storage(
            'This build has no database configured. Rebuild with '
            '--dart-define=SUPABASE_URL and --dart-define=SUPABASE_ANON_KEY.',
          );
        }

        // Initialised here rather than in main() so the test harness never
        // touches it, and so a second bootstrap (the retry button on the
        // startup error screen) reuses the existing client instead of failing.
        // publishableKey is the current name for the same header; the SDK takes
        // whichever is given and sends it unchanged, so the project's existing
        // anon key still goes in here.
        final Supabase supabase = await Supabase.initialize(
          url: SupabaseConfig.url,
          publishableKey: SupabaseConfig.anonKey,
        );
        final SupabaseClient client = supabase.client;

        activity = SupabaseActivityRepository(client, database.bus);
        notifications = SupabaseNotificationRepository(client, database.bus);
        auth = SupabaseAuthRepository(client);
        classes = SupabaseClassRepository(
          client,
          database.bus,
          activity: activity,
        );
        students = SupabaseStudentRepository(
          client,
          database.bus,
          activity: activity,
        );
        attendance = SupabaseAttendanceRepository(
          client,
          database.bus,
          activity: activity,
        );
        assessments = SupabaseAssessmentRepository(
          client,
          database.bus,
          activity: activity,
        );
        gradeScales = SupabaseGradeScaleRepository(client, database.bus);
        organizations =
            SupabaseOrganizationRepository(client, database.bus);

      case AppBackend.local:
        activity = LocalActivityRepository(database);
        notifications = LocalNotificationRepository(database);
        auth = LocalAuthRepository(
          database,
          activity: activity,
          notifications: notifications,
        );
        classes = LocalClassRepository(database, activity: activity);
        students = LocalStudentRepository(database, activity: activity);
        attendance = LocalAttendanceRepository(database, activity: activity);
        assessments = LocalAssessmentRepository(database, activity: activity);
        gradeScales = LocalGradeScaleRepository(database);
        organizations = LocalOrganizationRepository(
          database,
          activity: activity,
          notifications: notifications,
        );
    }

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
      backend: backend,
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

  final AppBackend backend;
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
  ///
  /// On-device only. Against the shared database this would either do nothing
  /// or, worse, read as an offer to wipe a teacher's real classes.
  Future<void> resetDemoData() async {
    if (backend != AppBackend.local) {
      throw const AppFailure.validation(
        'Demo data is only available in an offline build.',
      );
    }
    await database.wipe();
    await seeder.seed();
  }

  Future<void> dispose() => database.dispose();
}
