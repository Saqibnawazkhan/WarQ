import '../models/models.dart';

/// In-app notifications and the guardian message outbox.
abstract class NotificationRepository {
  Future<List<AppNotification>> listForUser(String userId);

  Future<int> unreadCount(String userId);

  Future<AppNotification> create({
    required String userId,
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.general,
    String? organizationId,
    String? relatedEntityType,
    String? relatedEntityId,
  });

  Future<void> markRead(String notificationId);

  Future<void> markAllRead(String userId);

  Future<void> delete(String notificationId);

  Future<void> clearForUser(String userId);

  /// Guardian messages queued by the absence pipeline.
  Future<List<OutboundMessage>> outbox({String? userId, String? classId});

  Future<void> saveOutbound(Iterable<OutboundMessage> messages);

  Future<void> updateOutbound(OutboundMessage message);
}
