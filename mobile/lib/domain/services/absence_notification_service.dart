import '../../core/utils/id_generator.dart';
import '../../data/models/models.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/notification_repository.dart';
import 'messaging/message_templates.dart';
import 'messaging/messaging_provider.dart';

/// What happened when absences were processed.
class AbsenceDispatchReport {
  const AbsenceDispatchReport({
    required this.messages,
    required this.studentsWithoutContact,
    required this.studentsNotified,
  });

  const AbsenceDispatchReport.empty()
      : messages = const <OutboundMessage>[],
        studentsWithoutContact = const <Student>[],
        studentsNotified = 0;

  final List<OutboundMessage> messages;

  /// Absent students the active provider could not address — either no phone
  /// number is on file, or none of them can be dialled internationally.
  /// Skipping them is the required behaviour, not an error.
  final List<Student> studentsWithoutContact;

  /// Students with at least one notice prepared or delivered.
  final int studentsNotified;

  /// Messages still waiting for the teacher to hand them to WhatsApp.
  List<OutboundMessage> get pending => messages
      .where((OutboundMessage m) => m.status != MessageStatus.sent)
      .toList(growable: false);

  int get queued =>
      messages.where((OutboundMessage m) => m.status == MessageStatus.queued).length;

  int get sent =>
      messages.where((OutboundMessage m) => m.status == MessageStatus.sent).length;

  int get failed =>
      messages.where((OutboundMessage m) => m.status == MessageStatus.failed).length;

  bool get isEmpty => messages.isEmpty && studentsWithoutContact.isEmpty;

  /// One-line summary for the snackbar shown after saving attendance.
  String describe() {
    if (isEmpty) return 'No absences to notify.';
    final List<String> parts = <String>[];
    if (sent > 0) parts.add('$sent sent');
    if (queued > 0) parts.add('$queued ready to send');
    if (failed > 0) parts.add('$failed failed');
    if (studentsWithoutContact.isNotEmpty) {
      parts.add('${studentsWithoutContact.length} without a usable number');
    }
    return 'Absence notices: ${parts.join(', ')}.';
  }
}

/// Turns "student marked absent" into guardian messages.
///
/// The rules the product spec asks for live here:
///  * every recorded number for the student, father and mother is messaged;
///  * a recipient with no number is silently skipped;
///  * a student already notified for that session is not messaged twice.
class AbsenceNotificationService {
  AbsenceNotificationService({
    required NotificationRepository notifications,
    required AttendanceRepository attendance,
    required this.provider,
  })  : _notifications = notifications,
        _attendance = attendance;

  final NotificationRepository _notifications;
  final AttendanceRepository _attendance;

  /// The delivery gateway. Reassignable so a real SMS/WhatsApp provider can be
  /// swapped in at runtime (settings screen, tests) without rebuilding the
  /// object graph.
  MessagingProvider provider;

  /// Queues absence notices for [absentStudents].
  Future<AbsenceDispatchReport> notifyAbsences({
    required SchoolClass schoolClass,
    required List<Student> absentStudents,
    required DateTime date,
    required AppUser teacher,
    List<AttendanceRecord> records = const <AttendanceRecord>[],
  }) async {
    if (absentStudents.isEmpty) return const AbsenceDispatchReport.empty();

    final List<OutboundMessage> created = <OutboundMessage>[];
    final List<Student> withoutContact = <Student>[];
    int notifiedStudents = 0;

    for (final Student student in absentStudents) {
      // Only numbers the active provider can actually address. A number stored
      // in a format the gateway cannot dial is no more useful than a blank
      // field, so it is reported the same way rather than queued forever.
      final List<({RecipientRelation relation, String phone})> contacts = student
          .contactNumbers
          .where((({RecipientRelation relation, String phone}) c) =>
              provider.canReach(c.phone))
          .toList();
      if (contacts.isEmpty) {
        withoutContact.add(student);
        continue;
      }

      bool reached = false;
      for (final ({RecipientRelation relation, String phone}) contact in contacts) {
        final String body = MessageTemplates.absence(
          studentName: student.fullName,
          className: schoolClass.name,
          date: date,
          relation: contact.relation,
          teacherName: teacher.displayName,
        );

        // A hand-off provider (WhatsApp) opens another app and can only handle
        // one message at a time, so the notice is queued here and dispatched
        // from the send list. Server-side gateways go out immediately.
        final MessageDispatchResult result = provider.requiresUserAction
            ? MessageDispatchResult.queued(provider.primaryChannel)
            : await provider.send(
                MessageRequest(
                  recipientPhone: contact.phone,
                  relation: contact.relation,
                  body: body,
                  metadata: <String, String>{
                    'studentId': student.id,
                    'classId': schoolClass.id,
                  },
                ),
              );

        created.add(
          OutboundMessage(
            id: IdGenerator.generate('msg'),
            recipientPhone: contact.phone,
            relation: contact.relation,
            body: body,
            channel: result.channel,
            status: result.status,
            createdAt: DateTime.now(),
            studentId: student.id,
            studentName: student.fullName,
            classId: schoolClass.id,
            className: schoolClass.name,
            attendanceRecordId: _recordIdFor(records, student.id),
            requestedByUserId: teacher.id,
            organizationId: schoolClass.organizationId,
            sentAt: result.status == MessageStatus.sent ? DateTime.now() : null,
            providerId: result.providerId,
            failureReason: result.failureReason,
          ),
        );
        if (result.status != MessageStatus.failed) reached = true;
      }
      if (reached) notifiedStudents++;
    }

    if (created.isNotEmpty) {
      await _notifications.saveOutbound(created);
    }

    // Flag the records so editing the same session later does not re-notify.
    final Set<String> studentIds =
        absentStudents.map((Student s) => s.id).toSet();
    final Iterable<String> recordIds = records
        .where((AttendanceRecord r) => studentIds.contains(r.studentId))
        .map((AttendanceRecord r) => r.id);
    await _attendance.markNotified(recordIds);

    if (withoutContact.isNotEmpty) {
      await _notifications.create(
        userId: teacher.id,
        title: 'Some guardians could not be notified',
        body: '${withoutContact.length} absent '
            '${withoutContact.length == 1 ? 'student has' : 'students have'} no '
            'usable phone number in ${schoolClass.name}.',
        category: NotificationCategory.attendance,
        organizationId: schoolClass.organizationId,
        relatedEntityType: 'class',
        relatedEntityId: schoolClass.id,
      );
    }

    return AbsenceDispatchReport(
      messages: created,
      studentsWithoutContact: withoutContact,
      studentsNotified: notifiedStudents,
    );
  }

  /// Retries a single failed or queued message.
  Future<OutboundMessage> retry(OutboundMessage message) async {
    final MessageDispatchResult result = await provider.send(
      MessageRequest(
        recipientPhone: message.recipientPhone,
        relation: message.relation,
        body: message.body,
        metadata: <String, String>{
          if (message.studentId != null) 'studentId': message.studentId!,
          if (message.classId != null) 'classId': message.classId!,
        },
      ),
    );
    final OutboundMessage updated = message.copyWith(
      status: result.status,
      channel: result.channel,
      providerId: result.providerId,
      failureReason: result.failureReason,
      clearFailureReason: result.failureReason == null,
      sentAt: result.status == MessageStatus.sent ? DateTime.now() : null,
    );
    await _notifications.updateOutbound(updated);
    return updated;
  }

  String? _recordIdFor(List<AttendanceRecord> records, String studentId) {
    for (final AttendanceRecord record in records) {
      if (record.studentId == studentId) return record.id;
    }
    return null;
  }
}
