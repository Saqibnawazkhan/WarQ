import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/data/local/key_value_store.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/data/repositories/assessment_repository.dart';
import 'package:edu_manager/data/repositories/class_repository.dart';
import 'package:edu_manager/data/repositories/student_repository.dart';
import 'package:edu_manager/domain/services/messaging/messaging_provider.dart';

/// Builds an [AppDependencies] graph backed by in-memory storage.
///
/// Tests get the real repositories and services — only the persistence engine
/// and the messaging gateway are swapped — so they exercise production logic.
Future<AppDependencies> createTestDependencies({
  MessagingProvider? messaging,
  bool seedDemoData = false,
}) {
  return AppDependencies.bootstrap(
    store: InMemoryKeyValueStore(),
    messagingProvider: messaging ?? const QueuedMessagingProvider(),
    seedDemoData: seedDemoData,
  );
}

/// Registers a teacher and returns the created account.
Future<AppUser> registerTestTeacher(
  AppDependencies deps, {
  String fullName = 'Test Teacher',
  String email = 'teacher@test.com',
  String password = 'password123',
}) {
  return deps.auth.registerTeacher(
    fullName: fullName,
    email: email,
    password: password,
  );
}

/// Creates a class owned by [teacher].
Future<SchoolClass> createTestClass(
  AppDependencies deps,
  AppUser teacher, {
  String name = 'Software Engineering',
  String? section = 'A',
}) {
  return deps.classes.create(
    teacherId: teacher.id,
    draft: ClassDraft(name: name, section: section, session: '2026'),
    organizationId: teacher.organizationId,
  );
}

/// Adds a student to [schoolClass].
Future<Student> addTestStudent(
  AppDependencies deps,
  AppUser teacher,
  SchoolClass schoolClass, {
  required String name,
  String? rollNumber,
  String? studentPhone,
  String? fatherPhone,
  String? motherPhone,
}) {
  return deps.students.create(
    teacherId: teacher.id,
    classId: schoolClass.id,
    organizationId: teacher.organizationId,
    draft: StudentDraft(
      fullName: name,
      rollNumber: rollNumber,
      studentPhone: studentPhone,
      fatherPhone: fatherPhone,
      motherPhone: motherPhone,
    ),
  );
}

/// Creates an assessment in [schoolClass].
Future<Assessment> createTestAssessment(
  AppDependencies deps,
  AppUser teacher,
  SchoolClass schoolClass, {
  String name = 'Quiz 1',
  double totalMarks = 20,
  AssessmentType type = AssessmentType.quiz,
  DateTime? date,
}) {
  return deps.assessments.create(
    classId: schoolClass.id,
    userId: teacher.id,
    draft: AssessmentDraft(
      name: name,
      type: type,
      date: date ?? DateTime.now(),
      totalMarks: totalMarks,
    ),
  );
}

/// A messaging provider that records everything it is asked to send.
class RecordingMessagingProvider extends MessagingProvider {
  RecordingMessagingProvider({this.failEveryRequest = false});

  final bool failEveryRequest;
  final List<MessageRequest> sent = <MessageRequest>[];

  @override
  String get id => 'test.recording';

  @override
  String get displayName => 'Recording provider';

  @override
  Set<MessageChannel> get supportedChannels => <MessageChannel>{MessageChannel.sms};

  @override
  bool get isConfigured => true;

  @override
  String get statusDescription => 'Test provider';

  @override
  Future<MessageDispatchResult> send(MessageRequest request) async {
    sent.add(request);
    if (failEveryRequest) {
      return const MessageDispatchResult.failed(
        MessageChannel.sms,
        'Simulated failure',
      );
    }
    return const MessageDispatchResult.sent(MessageChannel.sms, providerId: 'x');
  }
}
