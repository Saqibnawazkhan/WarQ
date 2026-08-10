import 'package:flutter/foundation.dart';

import '../../../data/models/enums.dart';

/// A single message the app wants delivered.
class MessageRequest {
  const MessageRequest({
    required this.recipientPhone,
    required this.relation,
    required this.body,
    this.preferredChannel,
    this.metadata = const <String, String>{},
  });

  final String recipientPhone;
  final RecipientRelation relation;
  final String body;

  /// The app's suggestion; a provider may fall back to what it supports.
  final MessageChannel? preferredChannel;

  /// Free-form context (student id, class id, …) for provider-side logging.
  final Map<String, String> metadata;
}

/// What the provider did with a [MessageRequest].
class MessageDispatchResult {
  const MessageDispatchResult({
    required this.status,
    required this.channel,
    this.providerId,
    this.failureReason,
  });

  const MessageDispatchResult.queued(this.channel)
      : status = MessageStatus.queued,
        providerId = null,
        failureReason = null;

  const MessageDispatchResult.sent(this.channel, {this.providerId})
      : status = MessageStatus.sent,
        failureReason = null;

  const MessageDispatchResult.failed(this.channel, this.failureReason)
      : status = MessageStatus.failed,
        providerId = null;

  final MessageStatus status;
  final MessageChannel channel;
  final String? providerId;
  final String? failureReason;
}

/// The seam between WarQ and an outbound messaging gateway.
///
/// Phase 1 ships [QueuedMessagingProvider], which records messages without
/// sending them. Connecting WhatsApp, an SMS gateway or a push service later
/// means writing one more implementation and registering it — no screen, model
/// or repository changes. Nothing else in the codebase names a vendor.
abstract class MessagingProvider {
  /// Subclasses `extend` rather than `implement` this so they inherit the
  /// defaults below; `implements` would force every provider to restate them.
  const MessagingProvider();

  /// Stable identifier persisted alongside dispatched messages.
  String get id;

  /// Shown in settings so a teacher can see how messages will be delivered.
  String get displayName;

  Set<MessageChannel> get supportedChannels;

  /// False until credentials are supplied; the app then records messages as
  /// queued rather than pretending they were delivered.
  bool get isConfigured;

  /// A one-line explanation shown in the UI.
  String get statusDescription;

  /// Whether [send] needs the teacher present.
  ///
  /// A hand-off provider (WhatsApp via a deep link) opens another app and can
  /// only process one message at a time, so saving attendance must *queue* the
  /// notices and let the teacher dispatch them from a list. A server-side
  /// gateway sends unattended and returns `false`, letting the absence pipeline
  /// fire everything immediately.
  bool get requiresUserAction => false;

  /// True when this provider can address [phone]. Recipients it cannot reach
  /// are skipped rather than queued for a delivery that would never succeed.
  bool canReach(String phone) => phone.trim().isNotEmpty;

  /// Channel recorded against a message this provider queues.
  MessageChannel get primaryChannel => supportedChannels.isEmpty
      ? MessageChannel.none
      : supportedChannels.first;

  Future<MessageDispatchResult> send(MessageRequest request);
}

/// Default Phase 1 provider: every message is stored as `queued` and logged in
/// debug builds. Nothing leaves the device.
class QueuedMessagingProvider extends MessagingProvider {
  const QueuedMessagingProvider();

  @override
  String get id => 'local.queued';

  @override
  String get displayName => 'On-device queue';

  @override
  Set<MessageChannel> get supportedChannels => const <MessageChannel>{
        MessageChannel.sms,
        MessageChannel.whatsapp,
      };

  @override
  bool get isConfigured => false;

  @override
  MessageChannel get primaryChannel => MessageChannel.none;

  @override
  String get statusDescription =>
      'Messages are recorded in the outbox. Connect an SMS or WhatsApp provider '
      'to deliver them automatically.';

  @override
  Future<MessageDispatchResult> send(MessageRequest request) async {
    assert(() {
      debugPrint(
        '[messaging] queued → ${request.relation.name} '
        '${request.recipientPhone}: ${request.body}',
      );
      return true;
    }());
    return const MessageDispatchResult.queued(MessageChannel.none);
  }
}
