import '../../../core/utils/date_utils.dart';
import '../../../data/models/enums.dart';

/// Text used for guardian-facing messages.
///
/// Kept separate from the dispatch logic so wording (and, later, per-language
/// or per-organization variants) can change without touching the pipeline.
class MessageTemplates {
  const MessageTemplates._();

  /// Absence notice.
  ///
  /// Addressed to the parent for father/mother recipients, and to the student
  /// directly when the message goes to their own number.
  static String absence({
    required String studentName,
    required String className,
    required DateTime date,
    required RecipientRelation relation,
    String? teacherName,
  }) {
    final String when = AppDate.isToday(date)
        ? 'today'
        : 'on ${AppDate.format(date)}';
    final String signature =
        teacherName == null ? '' : '\n\n— $teacherName';

    if (relation == RecipientRelation.student) {
      return 'Dear $studentName, you were marked absent from the $className '
          'class $when. Please contact your teacher if this is incorrect.'
          '$signature';
    }
    return 'Dear Parent, your child $studentName was marked absent from the '
        '$className class $when.$signature';
  }

  /// Preview line shown to the teacher before messages are queued.
  static String absencePreview({
    required String studentName,
    required String className,
    required DateTime date,
  }) {
    return absence(
      studentName: studentName,
      className: className,
      date: date,
      relation: RecipientRelation.father,
    );
  }

  /// Invitation text an organization admin can copy and send manually while no
  /// delivery provider is connected.
  static String invitation({
    required String organizationName,
    required String inviterName,
    required String token,
    String? inviteeName,
  }) {
    final String greeting = inviteeName == null ? 'Hello' : 'Hello $inviteeName';
    return '$greeting,\n\n$inviterName has invited you to join '
        '$organizationName on EDU Manager.\n\n'
        'Create your account with this email address and you will join the '
        'organization automatically.\n\nInvitation code: $token';
  }
}
