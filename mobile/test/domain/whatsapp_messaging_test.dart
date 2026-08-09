import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/utils/phone_number.dart';
import 'package:edu_manager/core/utils/date_utils.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/domain/services/absence_notification_service.dart';
import 'package:edu_manager/domain/services/messaging/messaging_provider.dart';
import 'package:edu_manager/domain/services/messaging/whatsapp_messaging_provider.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  group('PhoneNumber.toWhatsAppNumber', () {
    test('strips punctuation from an international number', () {
      expect(
        PhoneNumber.toWhatsAppNumber('+92 300 111 2222'),
        '923001112222',
      );
      expect(PhoneNumber.toWhatsAppNumber('+92-300-1112222'), '923001112222');
      expect(PhoneNumber.toWhatsAppNumber('(+92) 3001112222'), '923001112222');
    });

    test('handles the 00 international prefix', () {
      expect(PhoneNumber.toWhatsAppNumber('0092 3001112222'), '923001112222');
    });

    test('swaps a national trunk zero for the default dialling code', () {
      expect(
        PhoneNumber.toWhatsAppNumber('03001112222', defaultCountryCode: '92'),
        '923001112222',
      );
    });

    test('prefixes a bare national number with the dialling code', () {
      expect(
        PhoneNumber.toWhatsAppNumber('3001112222', defaultCountryCode: '92'),
        '923001112222',
      );
    });

    test('refuses a national number when no dialling code is configured', () {
      // Guessing a country would silently message a stranger.
      expect(PhoneNumber.toWhatsAppNumber('03001112222'), isNull);
    });

    test('rejects blanks and values that cannot be a number', () {
      expect(PhoneNumber.toWhatsAppNumber(null), isNull);
      expect(PhoneNumber.toWhatsAppNumber('   '), isNull);
      expect(PhoneNumber.toWhatsAppNumber('not a phone'), isNull);
      expect(PhoneNumber.toWhatsAppNumber('12345'), isNull, reason: 'too short');
      expect(
        PhoneNumber.toWhatsAppNumber('+1234567890123456'),
        isNull,
        reason: 'beyond E.164 length',
      );
    });

    test('does not double-apply a dialling code already present', () {
      expect(
        PhoneNumber.toWhatsAppNumber('923001112222', defaultCountryCode: '92'),
        '923001112222',
      );
    });

    test('accepts a dialling code written as +92 or 0092', () {
      expect(
        PhoneNumber.toWhatsAppNumber('03001112222', defaultCountryCode: '+92'),
        '923001112222',
      );
      expect(
        PhoneNumber.toWhatsAppNumber('03001112222', defaultCountryCode: '0092'),
        '923001112222',
      );
    });

    test('toE164 adds the plus back for display and sms links', () {
      expect(PhoneNumber.toE164('+92 300 111 2222'), '+923001112222');
      expect(PhoneNumber.toE164('nonsense'), isNull);
    });
  });

  group('WhatsAppMessagingProvider', () {
    test('builds a wa.me link with the message pre-filled', () {
      const WhatsAppMessagingProvider provider = WhatsAppMessagingProvider();
      final Uri? link = provider.linkFor(
        phone: '+92 300 111 2222',
        body: 'Dear Parent, your child Ahmed was marked absent.',
      );

      expect(link, isNotNull);
      expect(link!.host, 'wa.me');
      expect(link.path, '/923001112222');
      expect(
        link.queryParameters['text'],
        'Dear Parent, your child Ahmed was marked absent.',
      );
    });

    test('reports numbers it cannot address', () {
      const WhatsAppMessagingProvider provider = WhatsAppMessagingProvider();
      expect(provider.canReach('+923001112222'), isTrue);
      expect(provider.canReach('03001112222'), isFalse);

      const WhatsAppMessagingProvider withCode =
          WhatsAppMessagingProvider(defaultCountryCode: '92');
      expect(withCode.canReach('03001112222'), isTrue);
    });

    test('launches the link and reports it sent', () async {
      final List<Uri> launched = <Uri>[];
      final WhatsAppMessagingProvider provider = WhatsAppMessagingProvider(
        launcher: (Uri uri) async {
          launched.add(uri);
          return true;
        },
      );

      final MessageDispatchResult result = await provider.send(
        const MessageRequest(
          recipientPhone: '+923001112222',
          relation: RecipientRelation.father,
          body: 'Absent today',
        ),
      );

      expect(result.status, MessageStatus.sent);
      expect(result.channel, MessageChannel.whatsapp);
      expect(launched.single.host, 'wa.me');
    });

    test('falls back to SMS when WhatsApp cannot be opened', () async {
      final List<Uri> launched = <Uri>[];
      final WhatsAppMessagingProvider provider = WhatsAppMessagingProvider(
        launcher: (Uri uri) async {
          launched.add(uri);
          return uri.scheme == 'sms';
        },
      );

      final MessageDispatchResult result = await provider.send(
        const MessageRequest(
          recipientPhone: '+923001112222',
          relation: RecipientRelation.mother,
          body: 'Absent today',
        ),
      );

      expect(result.status, MessageStatus.sent);
      expect(result.channel, MessageChannel.sms);
      expect(launched.map((Uri u) => u.scheme), <String>['https', 'sms']);
    });

    test('fails with an actionable message for an unusable number', () async {
      final WhatsAppMessagingProvider provider = WhatsAppMessagingProvider(
        launcher: (Uri uri) async => true,
      );

      final MessageDispatchResult result = await provider.send(
        const MessageRequest(
          recipientPhone: '03001112222',
          relation: RecipientRelation.father,
          body: 'Absent today',
        ),
      );

      expect(result.status, MessageStatus.failed);
      expect(result.failureReason, contains('country code'));
    });

    test('needs the teacher present, so absences are queued not auto-sent', () {
      const WhatsAppMessagingProvider provider = WhatsAppMessagingProvider();
      expect(provider.requiresUserAction, isTrue);
      expect(provider.primaryChannel, MessageChannel.whatsapp);
    });
  });

  group('absence pipeline with a hand-off provider', () {
    late AppDependencies deps;
    late AppUser teacher;
    late SchoolClass schoolClass;

    setUp(() async {
      deps = await createTestDependencies(
        messaging: WhatsAppMessagingProvider(
          defaultCountryCode: '92',
          launcher: (Uri uri) async => true,
        ),
      );
      teacher = await registerTestTeacher(deps);
      schoolClass = await createTestClass(deps, teacher);
    });

    tearDown(() async => deps.dispose());

    test('queues one message per number instead of opening WhatsApp N times',
        () async {
      final Student student = await addTestStudent(
        deps,
        teacher,
        schoolClass,
        name: 'Ahmed Bilal',
        fatherPhone: '+92 300 1112222',
        motherPhone: '03001113333',
      );

      final AbsenceDispatchReport report =
          await deps.absenceNotifications.notifyAbsences(
        schoolClass: schoolClass,
        absentStudents: <Student>[student],
        date: AppDate.today(),
        teacher: teacher,
      );

      expect(report.messages, hasLength(2));
      expect(report.queued, 2);
      expect(report.sent, 0, reason: 'nothing is sent until the teacher taps');
      expect(report.pending, hasLength(2));
      expect(
        report.messages.every((OutboundMessage m) =>
            m.channel == MessageChannel.whatsapp),
        isTrue,
      );
    });

    test('skips a number that cannot be dialled internationally', () async {
      // No country code on file and the number is national-format only.
      final AppDependencies strict = await createTestDependencies(
        messaging: WhatsAppMessagingProvider(launcher: (Uri uri) async => true),
      );
      final AppUser owner = await registerTestTeacher(strict);
      final SchoolClass klass = await createTestClass(strict, owner);
      final Student student = await addTestStudent(
        strict,
        owner,
        klass,
        name: 'Zain Abbas',
        fatherPhone: '03001112222',
      );

      final AbsenceDispatchReport report =
          await strict.absenceNotifications.notifyAbsences(
        schoolClass: klass,
        absentStudents: <Student>[student],
        date: AppDate.today(),
        teacher: owner,
      );

      expect(report.messages, isEmpty);
      expect(report.studentsWithoutContact.single.id, student.id);
      expect(report.describe(), contains('without a usable number'));

      await strict.dispose();
    });

    test('sending a queued message marks it sent in the outbox', () async {
      final Student student = await addTestStudent(
        deps,
        teacher,
        schoolClass,
        name: 'Ahmed Bilal',
        fatherPhone: '+92 300 1112222',
      );

      final AbsenceDispatchReport report =
          await deps.absenceNotifications.notifyAbsences(
        schoolClass: schoolClass,
        absentStudents: <Student>[student],
        date: AppDate.today(),
        teacher: teacher,
      );

      final OutboundMessage sent =
          await deps.absenceNotifications.retry(report.messages.single);

      expect(sent.status, MessageStatus.sent);
      expect(sent.sentAt, isNotNull);

      final List<OutboundMessage> outbox =
          await deps.notifications.outbox(userId: teacher.id);
      expect(outbox.single.status, MessageStatus.sent);
    });
  });
}
