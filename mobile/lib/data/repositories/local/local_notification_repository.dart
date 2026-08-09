import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../notification_repository.dart';

/// On-device notifications and guardian message outbox.
class LocalNotificationRepository implements NotificationRepository {
  LocalNotificationRepository(this._db);

  final LocalDatabase _db;

  @override
  Future<List<AppNotification>> listForUser(String userId) async {
    final List<AppNotification> items = _db.notifications
        .where((AppNotification n) => n.userId == userId)
        .toList()
      ..sort((AppNotification a, AppNotification b) =>
          b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<int> unreadCount(String userId) async {
    return _db.notifications.countWhere(
      (AppNotification n) => n.userId == userId && !n.isRead,
    );
  }

  @override
  Future<AppNotification> create({
    required String userId,
    required String title,
    required String body,
    NotificationCategory category = NotificationCategory.general,
    String? organizationId,
    String? relatedEntityType,
    String? relatedEntityId,
  }) async {
    final AppNotification notification = AppNotification(
      id: IdGenerator.generate('ntf'),
      userId: userId,
      title: title,
      body: body,
      category: category,
      createdAt: DateTime.now(),
      organizationId: organizationId,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
    );
    await _db.notifications.put(notification);
    _db.bus.emit(DataEntity.notifications, id: notification.id);
    return notification;
  }

  @override
  Future<void> markRead(String notificationId) async {
    final AppNotification? existing = _db.notifications.byId(notificationId);
    if (existing == null || existing.isRead) return;
    await _db.notifications.put(existing.copyWith(isRead: true));
    _db.bus.emit(DataEntity.notifications, id: notificationId);
  }

  @override
  Future<void> markAllRead(String userId) async {
    final List<AppNotification> unread = _db.notifications
        .where((AppNotification n) => n.userId == userId && !n.isRead)
        .toList(growable: false);
    if (unread.isEmpty) return;
    await _db.notifications.putAll(
      unread.map((AppNotification n) => n.copyWith(isRead: true)),
    );
    _db.bus.emit(DataEntity.notifications);
  }

  @override
  Future<void> delete(String notificationId) async {
    await _db.notifications.delete(notificationId);
    _db.bus.emit(DataEntity.notifications, id: notificationId);
  }

  @override
  Future<void> clearForUser(String userId) async {
    final int removed = await _db.notifications
        .deleteWhere((AppNotification n) => n.userId == userId);
    if (removed > 0) _db.bus.emit(DataEntity.notifications);
  }

  @override
  Future<List<OutboundMessage>> outbox({String? userId, String? classId}) async {
    final List<OutboundMessage> items = _db.outbox
        .where((OutboundMessage m) =>
            (userId == null || m.requestedByUserId == userId) &&
            (classId == null || m.classId == classId))
        .toList()
      ..sort((OutboundMessage a, OutboundMessage b) =>
          b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<void> saveOutbound(Iterable<OutboundMessage> messages) async {
    final List<OutboundMessage> list = messages.toList(growable: false);
    if (list.isEmpty) return;
    await _db.outbox.putAll(list);
    _db.bus.emit(DataEntity.messages);
  }

  @override
  Future<void> updateOutbound(OutboundMessage message) async {
    await _db.outbox.put(message);
    _db.bus.emit(DataEntity.messages, id: message.id);
  }
}
