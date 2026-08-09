import '../../core/constants/app_constants.dart';
import '../models/models.dart';
import 'collection_store.dart';
import 'data_event_bus.dart';
import 'key_value_store.dart';

/// Owns every persisted collection plus the change bus.
///
/// Repositories read and write through this object; nothing above the data
/// layer touches [CollectionStore] directly. When the backend arrives this
/// class becomes the offline cache rather than the source of truth.
class LocalDatabase {
  LocalDatabase(this.store) : bus = DataEventBus();

  final KeyValueStore store;
  final DataEventBus bus;

  late final CollectionStore<AppUser> users = CollectionStore<AppUser>(
    key: StorageKeys.users,
    store: store,
    fromJson: AppUser.fromJson,
    toJson: (AppUser e) => e.toJson(),
    idOf: (AppUser e) => e.id,
  );

  late final CollectionStore<AuthCredential> credentials =
      CollectionStore<AuthCredential>(
    key: StorageKeys.credentials,
    store: store,
    fromJson: AuthCredential.fromJson,
    toJson: (AuthCredential e) => e.toJson(),
    idOf: (AuthCredential e) => e.userId,
  );

  late final CollectionStore<Organization> organizations =
      CollectionStore<Organization>(
    key: StorageKeys.organizations,
    store: store,
    fromJson: Organization.fromJson,
    toJson: (Organization e) => e.toJson(),
    idOf: (Organization e) => e.id,
  );

  late final CollectionStore<SchoolClass> classes = CollectionStore<SchoolClass>(
    key: StorageKeys.classes,
    store: store,
    fromJson: SchoolClass.fromJson,
    toJson: (SchoolClass e) => e.toJson(),
    idOf: (SchoolClass e) => e.id,
  );

  late final CollectionStore<Student> students = CollectionStore<Student>(
    key: StorageKeys.students,
    store: store,
    fromJson: Student.fromJson,
    toJson: (Student e) => e.toJson(),
    idOf: (Student e) => e.id,
  );

  late final CollectionStore<ClassEnrollment> enrollments =
      CollectionStore<ClassEnrollment>(
    key: StorageKeys.enrollments,
    store: store,
    fromJson: ClassEnrollment.fromJson,
    toJson: (ClassEnrollment e) => e.toJson(),
    idOf: (ClassEnrollment e) => e.id,
  );

  late final CollectionStore<AttendanceSession> attendanceSessions =
      CollectionStore<AttendanceSession>(
    key: StorageKeys.attendanceSessions,
    store: store,
    fromJson: AttendanceSession.fromJson,
    toJson: (AttendanceSession e) => e.toJson(),
    idOf: (AttendanceSession e) => e.id,
  );

  late final CollectionStore<AttendanceRecord> attendanceRecords =
      CollectionStore<AttendanceRecord>(
    key: StorageKeys.attendanceRecords,
    store: store,
    fromJson: AttendanceRecord.fromJson,
    toJson: (AttendanceRecord e) => e.toJson(),
    idOf: (AttendanceRecord e) => e.id,
  );

  late final CollectionStore<Assessment> assessments = CollectionStore<Assessment>(
    key: StorageKeys.assessments,
    store: store,
    fromJson: Assessment.fromJson,
    toJson: (Assessment e) => e.toJson(),
    idOf: (Assessment e) => e.id,
  );

  late final CollectionStore<AssessmentMark> marks = CollectionStore<AssessmentMark>(
    key: StorageKeys.assessmentMarks,
    store: store,
    fromJson: AssessmentMark.fromJson,
    toJson: (AssessmentMark e) => e.toJson(),
    idOf: (AssessmentMark e) => e.id,
  );

  late final CollectionStore<GradeScale> gradeScales = CollectionStore<GradeScale>(
    key: StorageKeys.gradeScales,
    store: store,
    fromJson: GradeScale.fromJson,
    toJson: (GradeScale e) => e.toJson(),
    idOf: (GradeScale e) => e.id,
  );

  late final CollectionStore<AppNotification> notifications =
      CollectionStore<AppNotification>(
    key: StorageKeys.notifications,
    store: store,
    fromJson: AppNotification.fromJson,
    toJson: (AppNotification e) => e.toJson(),
    idOf: (AppNotification e) => e.id,
  );

  late final CollectionStore<Invitation> invitations = CollectionStore<Invitation>(
    key: StorageKeys.invitations,
    store: store,
    fromJson: Invitation.fromJson,
    toJson: (Invitation e) => e.toJson(),
    idOf: (Invitation e) => e.id,
  );

  late final CollectionStore<ActivityLog> activityLogs =
      CollectionStore<ActivityLog>(
    key: StorageKeys.activityLogs,
    store: store,
    fromJson: ActivityLog.fromJson,
    toJson: (ActivityLog e) => e.toJson(),
    idOf: (ActivityLog e) => e.id,
  );

  late final CollectionStore<OutboundMessage> outbox =
      CollectionStore<OutboundMessage>(
    key: StorageKeys.outboundMessages,
    store: store,
    fromJson: OutboundMessage.fromJson,
    toJson: (OutboundMessage e) => e.toJson(),
    idOf: (OutboundMessage e) => e.id,
  );

  bool _initialised = false;
  bool get isInitialised => _initialised;

  /// Loads every collection into memory. Called once during app bootstrap.
  Future<void> init() async {
    if (_initialised) return;
    await Future.wait<void>(<Future<void>>[
      users.load(),
      credentials.load(),
      organizations.load(),
      classes.load(),
      students.load(),
      enrollments.load(),
      attendanceSessions.load(),
      attendanceRecords.load(),
      assessments.load(),
      marks.load(),
      gradeScales.load(),
      notifications.load(),
      invitations.load(),
      activityLogs.load(),
      outbox.load(),
    ]);

    // The platform default scale must always exist so grading never fails.
    if (gradeScales.byId(GradeScale.defaultId) == null) {
      await gradeScales.put(GradeScale.platformDefault());
    }

    await store.write(
      StorageKeys.schemaVersion,
      '${AppConstants.schemaVersion}',
    );
    _initialised = true;
  }

  /// Wipes all application data. Used by the "reset demo data" developer
  /// action and by tests.
  Future<void> wipe() async {
    await Future.wait<void>(<Future<void>>[
      users.clear(),
      credentials.clear(),
      organizations.clear(),
      classes.clear(),
      students.clear(),
      enrollments.clear(),
      attendanceSessions.clear(),
      attendanceRecords.clear(),
      assessments.clear(),
      marks.clear(),
      gradeScales.clear(),
      notifications.clear(),
      invitations.clear(),
      activityLogs.clear(),
      outbox.clear(),
    ]);
    await store.delete(StorageKeys.session);
    await store.delete(StorageKeys.seeded);
    await gradeScales.put(GradeScale.platformDefault());
    bus.emitAll(DataEntity.values);
  }

  Future<void> dispose() => bus.dispose();
}
