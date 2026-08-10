import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// A guardian-facing message queued by the app (currently only absence
/// notices).
///
/// This is the seam between WarQ and whichever SMS/WhatsApp gateway is
/// plugged in later: the app always writes an outbox row, and a
/// `MessagingProvider` decides what actually happens to it. Nothing in the app
/// references a specific vendor.
class OutboundMessage {
  const OutboundMessage({
    required this.id,
    required this.recipientPhone,
    required this.relation,
    required this.body,
    required this.channel,
    required this.status,
    required this.createdAt,
    this.studentId,
    this.studentName,
    this.classId,
    this.className,
    this.attendanceRecordId,
    this.requestedByUserId,
    this.organizationId,
    this.sentAt,
    this.providerId,
    this.failureReason,
  });

  factory OutboundMessage.fromJson(Map<String, dynamic> json) {
    return OutboundMessage(
      id: Json.string(json, 'id'),
      recipientPhone: Json.string(json, 'recipientPhone'),
      relation: Json.enumValue(
        json,
        'relation',
        RecipientRelation.values,
        RecipientRelation.guardian,
      ),
      body: Json.string(json, 'body'),
      channel: Json.enumValue(
        json,
        'channel',
        MessageChannel.values,
        MessageChannel.none,
      ),
      status: Json.enumValue(
        json,
        'status',
        MessageStatus.values,
        MessageStatus.queued,
      ),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      studentId: Json.stringOrNull(json, 'studentId'),
      studentName: Json.stringOrNull(json, 'studentName'),
      classId: Json.stringOrNull(json, 'classId'),
      className: Json.stringOrNull(json, 'className'),
      attendanceRecordId: Json.stringOrNull(json, 'attendanceRecordId'),
      requestedByUserId: Json.stringOrNull(json, 'requestedByUserId'),
      organizationId: Json.stringOrNull(json, 'organizationId'),
      sentAt: Json.dateTimeOrNull(json, 'sentAt'),
      providerId: Json.stringOrNull(json, 'providerId'),
      failureReason: Json.stringOrNull(json, 'failureReason'),
    );
  }

  final String id;
  final String recipientPhone;
  final RecipientRelation relation;
  final String body;
  final MessageChannel channel;
  final MessageStatus status;
  final DateTime createdAt;
  final String? studentId;
  final String? studentName;
  final String? classId;
  final String? className;
  final String? attendanceRecordId;
  final String? requestedByUserId;
  final String? organizationId;
  final DateTime? sentAt;

  /// Identifier returned by the delivery provider, for later reconciliation.
  final String? providerId;
  final String? failureReason;

  OutboundMessage copyWith({
    MessageStatus? status,
    MessageChannel? channel,
    DateTime? sentAt,
    String? providerId,
    String? failureReason,
    bool clearFailureReason = false,
  }) {
    return OutboundMessage(
      id: id,
      recipientPhone: recipientPhone,
      relation: relation,
      body: body,
      channel: channel ?? this.channel,
      status: status ?? this.status,
      createdAt: createdAt,
      studentId: studentId,
      studentName: studentName,
      classId: classId,
      className: className,
      attendanceRecordId: attendanceRecordId,
      requestedByUserId: requestedByUserId,
      organizationId: organizationId,
      sentAt: sentAt ?? this.sentAt,
      providerId: providerId ?? this.providerId,
      failureReason:
          clearFailureReason ? null : (failureReason ?? this.failureReason),
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'recipientPhone': recipientPhone,
        'relation': relation.name,
        'body': body,
        'channel': channel.name,
        'status': status.name,
        'createdAt': createdAt.toIso8601String(),
        'studentId': studentId,
        'studentName': studentName,
        'classId': classId,
        'className': className,
        'attendanceRecordId': attendanceRecordId,
        'requestedByUserId': requestedByUserId,
        'organizationId': organizationId,
        'sentAt': sentAt?.toIso8601String(),
        'providerId': providerId,
        'failureReason': failureReason,
      });

  @override
  bool operator ==(Object other) => other is OutboundMessage && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
