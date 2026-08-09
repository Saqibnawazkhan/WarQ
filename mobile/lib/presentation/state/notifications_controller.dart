import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import 'base_controller.dart';

/// Backs the notification centre and the guardian message outbox.
class NotificationsController extends BaseController {
  NotificationsController(this._deps, this._user) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.notifications,
      DataEntity.messages,
    });
  }

  final AppDependencies _deps;
  final AppUser _user;

  List<AppNotification> _notifications = const <AppNotification>[];
  List<OutboundMessage> _outbox = const <OutboundMessage>[];
  bool _unreadOnly = false;

  List<AppNotification> get all => _notifications;
  List<OutboundMessage> get outbox => _outbox;
  bool get unreadOnly => _unreadOnly;

  List<AppNotification> get visible => _unreadOnly
      ? _notifications.where((AppNotification n) => !n.isRead).toList()
      : _notifications;

  int get unreadCount =>
      _notifications.where((AppNotification n) => !n.isRead).length;

  bool get hasUnread => unreadCount > 0;

  String get messagingStatus =>
      _deps.absenceNotifications.provider.statusDescription;

  String get messagingProviderName =>
      _deps.absenceNotifications.provider.displayName;

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _notifications = await _deps.notifications.listForUser(_user.id);
        _outbox = await _deps.notifications.outbox(userId: _user.id);
      },
      refreshing: refreshing,
      isEmptyResult: () => _notifications.isEmpty,
    );
  }

  void setUnreadOnly(bool value) {
    if (_unreadOnly == value) return;
    _unreadOnly = value;
    safeNotify();
  }

  Future<void> markRead(String id) async {
    await guardAction<bool>(() async {
      await _deps.notifications.markRead(id);
      return true;
    });
  }

  Future<void> markAllRead() async {
    await guardAction<bool>(() async {
      await _deps.notifications.markAllRead(_user.id);
      return true;
    });
  }

  Future<void> delete(String id) async {
    await guardAction<bool>(() async {
      await _deps.notifications.delete(id);
      return true;
    });
  }

  Future<void> clearAll() async {
    await guardAction<bool>(() async {
      await _deps.notifications.clearForUser(_user.id);
      return true;
    });
  }

  Future<void> retryMessage(OutboundMessage message) async {
    await guardAction<OutboundMessage>(
      () => _deps.absenceNotifications.retry(message),
    );
  }
}
