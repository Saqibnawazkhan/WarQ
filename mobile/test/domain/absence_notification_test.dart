import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/utils/date_utils.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/domain/services/absence_notification_service.dart';
import 'package:edu_manager/domain/services/messaging/message_templates.dart';
import 'package:edu_manager/domain/services/messaging/messaging_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late AppDependencies deps;
  late RecordingMessagingProvider provider;
  late AppUser teacher;
  late SchoolClass schoolClass;

  setUp(() async {
    provider = RecordingMessagingProvider();
    deps = await createTestDependencies(messaging: provider);
    teacher = await registerTestTeacher(deps, fullName: 'Ahmed Raza');
    schoolClass = await createTestClass(deps, teacher, name: 'Software Engineering');
  });

  tearDown(() async => deps.dispose());

  test('messages every recorded number for an absent student', () async {
    final Student student = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Ahmed Bilal',
      studentPhone: '+92 300 1111111',
      fatherPhone: '+92 300 2222222',
      motherPhone: '+92 300 3333333',
    );

    final AbsenceDispatchReport report =
        await deps.absenceNotifications.notifyAbsences(
      schoolClass: schoolClass,
      absentStudents: <Student>[student],
      date: AppDate.today(),
      teacher: teacher,
    );

    expect(provider.sent, hasLength(3));
    expect(
      provider.sent.map((MessageRequest r) => r.relation).toSet(),
      <RecipientRelation>{
        RecipientRelation.student,
        RecipientRelation.father,
        RecipientRelation.mother,
      },
    );
    expect(report.sent, 3);
    expect(report.studentsNotified, 1);
    expect(report.studentsWithoutContact, isEmpty);
  });

  test('skips a recipient with no number instead of failing', () async {
    final Student student = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Hira Nawaz',
      fatherPhone: '+92 300 2222222',
    );

    await deps.absenceNotifications.notifyAbsences(
      schoolClass: schoolClass,
      absentStudents: <Student>[student],
      date: AppDate.today(),
      teacher: teacher,
    );

    expect(provider.sent, hasLength(1));
    expect(provider.sent.single.relation, RecipientRelation.father);
  });

  test('reports students who have no contact number at all', () async {
    final Student reachable = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Ahmed Bilal',
      fatherPhone: '+92 300 2222222',
    );
    final Student unreachable = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Zain Abbas',
    );

    final AbsenceDispatchReport report =
        await deps.absenceNotifications.notifyAbsences(
      schoolClass: schoolClass,
      absentStudents: <Student>[reachable, unreachable],
      date: AppDate.today(),
      teacher: teacher,
    );

    expect(provider.sent, hasLength(1));
    expect(report.studentsWithoutContact.single.id, unreachable.id);
    expect(report.studentsNotified, 1);
    expect(report.describe(), contains('without a usable number'));

    // The teacher is told, so a silent skip never goes unnoticed.
    final List<AppNotification> alerts =
        await deps.notifications.listForUser(teacher.id);
    expect(
      alerts.any((AppNotification n) => n.title.contains('could not be notified')),
      isTrue,
    );
  });

  test('writes an outbox row per message', () async {
    final Student student = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Ahmed Bilal',
      fatherPhone: '+92 300 2222222',
      motherPhone: '+92 300 3333333',
    );

    await deps.absenceNotifications.notifyAbsences(
      schoolClass: schoolClass,
      absentStudents: <Student>[student],
      date: AppDate.today(),
      teacher: teacher,
    );

    final List<OutboundMessage> outbox =
        await deps.notifications.outbox(userId: teacher.id);
    expect(outbox, hasLength(2));
    expect(outbox.every((OutboundMessage m) => m.status == MessageStatus.sent),
        isTrue);
    expect(outbox.first.className, 'Software Engineering');
    expect(outbox.first.studentName, 'Ahmed Bilal');
  });

  test('records a failure without losing the message', () async {
    final RecordingMessagingProvider failing =
        RecordingMessagingProvider(failEveryRequest: true);
    deps.absenceNotifications.provider = failing;

    final Student student = await addTestStudent(
      deps,
      teacher,
      schoolClass,
      name: 'Ahmed Bilal',
      fatherPhone: '+92 300 2222222',
    );

    final AbsenceDispatchReport report =
        await deps.absenceNotifications.notifyAbsences(
      schoolClass: schoolClass,
      absentStudents: <Student>[student],
      date: AppDate.today(),
      teacher: teacher,
    );

    expect(report.failed, 1);
    expect(report.studentsNotified, 0);

    final List<OutboundMessage> outbox =
        await deps.notifications.outbox(userId: teacher.id);
    expect(outbox.single.status, MessageStatus.failed);
    expect(outbox.single.failureReason, 'Simulated failure');
  });

  test('does nothing when there are no absences', () async {
    final AbsenceDispatchReport report =
        await deps.absenceNotifications.notifyAbsences(
      schoolClass: schoolClass,
      absentStudents: const <Student>[],
      date: AppDate.today(),
      teacher: teacher,
    );

    expect(report.isEmpty, isTrue);
    expect(provider.sent, isEmpty);
  });

  group('MessageTemplates', () {
    test('addresses parents for guardian numbers', () {
      final String body = MessageTemplates.absence(
        studentName: 'Ahmed',
        className: 'Software Engineering',
        date: AppDate.today(),
        relation: RecipientRelation.father,
      );

      expect(body, startsWith('Dear Parent, your child Ahmed was marked absent'));
      expect(body, contains('Software Engineering'));
      expect(body, contains('today'));
    });

    test('addresses the student directly on their own number', () {
      final String body = MessageTemplates.absence(
        studentName: 'Ahmed',
        className: 'Software Engineering',
        date: AppDate.today(),
        relation: RecipientRelation.student,
      );

      expect(body, startsWith('Dear Ahmed, you were marked absent'));
    });

    test('uses an absolute date for a past session', () {
      final DateTime past = AppDate.today().subtract(const Duration(days: 5));
      final String body = MessageTemplates.absence(
        studentName: 'Ahmed',
        className: 'Software Engineering',
        date: past,
        relation: RecipientRelation.mother,
      );

      expect(body, contains(AppDate.format(past)));
    });
  });
}
