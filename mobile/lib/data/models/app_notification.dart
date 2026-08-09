import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// An in-app notification addressed to one user.
class AppNotification {
  const AppNotification({
    required this.id,
    required this.userId,
    required this.title,
    required this.body,
    required this.category,
    required this.createdAt,
    this.isRead = false,
    this.organizationId,
    this.relatedEntityType,
    this.relatedEntityId,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    return AppNotification(
      id: Json.string(json, 'id'),
      userId: Json.string(json, 'userId'),
      title: Json.string(json, 'title'),
      body: Json.string(json, 'body'),
      category: Json.enumValue(
        json,
        'category',
        NotificationCategory.values,
        NotificationCategory.general,
      ),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      isRead: Json.boolean(json, 'isRead'),
      organizationId: Json.stringOrNull(json, 'organizationId'),
      relatedEntityType: Json.stringOrNull(json, 'relatedEntityType'),
      relatedEntityId: Json.stringOrNull(json, 'relatedEntityId'),
    );
  }

  final String id;
  final String userId;
  final String title;
  final String body;
  final NotificationCategory category;
  final DateTime createdAt;
  final bool isRead;
  final String? organizationId;

  /// Free-form pointer so a tap can deep-link once routing needs it.
  final String? relatedEntityType;
  final String? relatedEntityId;

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      userId: userId,
      title: title,
      body: body,
      category: category,
      createdAt: createdAt,
      isRead: isRead ?? this.isRead,
      organizationId: organizationId,
      relatedEntityType: relatedEntityType,
      relatedEntityId: relatedEntityId,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'userId': userId,
        'title': title,
        'body': body,
        'category': category.name,
        'createdAt': createdAt.toIso8601String(),
        'isRead': isRead,
        'organizationId': organizationId,
        'relatedEntityType': relatedEntityType,
        'relatedEntityId': relatedEntityId,
      });

  @override
  bool operator ==(Object other) => other is AppNotification && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
