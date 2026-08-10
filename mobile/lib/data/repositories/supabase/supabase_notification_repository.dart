import 'package:supabase_flutter/supabase_flutter.dart';

import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../notification_repository.dart';
import 'supabase_repository_base.dart';

/// In-app notifications and the guardian outbox, backed by Supabase.
///
/// The outbox is the seam between the app and whatever eventually sends the
/// messages. The app writes a row per recipient and a provider decides what
/// happens to it; today that provider hands off to WhatsApp, which is why most
/// rows start life queued rather than sent.
class SupabaseNotificationRepository extends SupabaseRepositoryBase
    implements NotificationRepository {
  SupabaseNotificationRepository(super.client, super.bus);

  SupabaseQueryBuilder get _table => client.from('notifications');
  SupabaseQueryBuilder get _messages => client.from('guardian_messages');

  @override
  Future<List<AppNotification>> listForUser(String userId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _table
          .select('*')
          .eq('profile_id', userId)
          .order('created_at', ascending: false);
      return rows.map(Rows.notification).toList(growable: false);
    });
  }

  @override
  Future<int> unreadCount(String userId) {
    return read(() async {
      // count only: the badge needs a number, not the rows behind it.
      final PostgrestResponse<List<Map<String, dynamic>>> response = await _table
          .select('id')
          .eq('profile_id', userId)
          .isFilter('read_at', null)
          .count(CountOption.exact);
      return response.count;
    });
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
  }) {
    return write(
      () async {
        final Map<String, dynamic> row = await _table.insert(<String, dynamic>{
          'profile_id': userId,
          'title': title,
          'body': body,
          // The column holds the coarse bucket the feed filters on; the exact
          // category rides along in meta so nothing is lost on the way back.
          'type': Rows.notificationBucket(category),
          'meta': <String, dynamic>{
            'category': category.name,
            if (organizationId != null) 'organization_id': organizationId,
            if (relatedEntityType != null) 'entity_type': relatedEntityType,
            if (relatedEntityId != null) 'entity_id': relatedEntityId,
          },
        }).select('*').single();
        return Rows.notification(row);
      },
      touches: <DataEntity>{DataEntity.notifications},
    );
  }

  @override
  Future<void> markRead(String notificationId) {
    return write(
      () => _table
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('id', notificationId)
          .isFilter('read_at', null),
      touches: <DataEntity>{DataEntity.notifications},
      id: notificationId,
    );
  }

  @override
  Future<void> markAllRead(String userId) {
    return write(
      () => _table
          .update(<String, dynamic>{
            'read_at': DateTime.now().toUtc().toIso8601String(),
          })
          .eq('profile_id', userId)
          .isFilter('read_at', null),
      touches: <DataEntity>{DataEntity.notifications},
    );
  }

  @override
  Future<void> delete(String notificationId) {
    return write(
      () => _table.delete().eq('id', notificationId),
      touches: <DataEntity>{DataEntity.notifications},
      id: notificationId,
    );
  }

  @override
  Future<void> clearForUser(String userId) {
    return write(
      () => _table.delete().eq('profile_id', userId),
      touches: <DataEntity>{DataEntity.notifications},
    );
  }

  @override
  Future<List<OutboundMessage>> outbox({String? userId, String? classId}) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query =
          _messages.select('*');
      if (userId != null) {
        query = query.eq('requested_by', userId);
      }
      if (classId != null) {
        query = query.eq('class_id', classId);
      }

      final List<Map<String, dynamic>> rows =
          await query.order('created_at', ascending: false);
      return rows.map(Rows.guardianMessage).toList(growable: false);
    });
  }

  @override
  Future<void> saveOutbound(Iterable<OutboundMessage> messages) {
    final List<OutboundMessage> batch = messages.toList(growable: false);
    if (batch.isEmpty) return Future<void>.value();

    // The ids on these objects were generated on the device and are deliberately
    // dropped: the column is a uuid with its own default. Nothing depends on
    // keeping them, because the only code that updates a message afterwards
    // (retrying a failed send) works from a row read back out of the outbox.
    return write(
      () => _messages.insert(<Map<String, dynamic>>[
        for (final OutboundMessage message in batch)
          <String, dynamic>{
            'requested_by': message.requestedByUserId ?? requireUserId,
            'organization_id': message.organizationId,
            'student_id': message.studentId,
            'class_id': message.classId,
            'attendance_session_id': _sessionIdOf(message.attendanceRecordId),
            // Snapshotted, so the outbox still reads correctly after a student
            // is renamed or removed.
            'student_name': message.studentName ?? 'Student',
            'class_name': message.className,
            'recipient_label': Rows.contactLabelToDb(message.relation),
            'recipient_phone': message.recipientPhone,
            'channel': Rows.channelToDb(message.channel),
            'body': message.body,
            'status': Rows.statusToDb(message.status),
            'failure_reason': message.failureReason,
            'sent_at': message.sentAt?.toUtc().toIso8601String(),
          },
      ]),
      touches: <DataEntity>{DataEntity.messages},
    );
  }

  @override
  Future<void> updateOutbound(OutboundMessage message) {
    return write(
      () => _messages.update(<String, dynamic>{
        'status': Rows.statusToDb(message.status),
        'channel': Rows.channelToDb(message.channel),
        'failure_reason': message.failureReason,
        'sent_at': message.sentAt?.toUtc().toIso8601String(),
      }).eq('id', message.id),
      touches: <DataEntity>{DataEntity.messages},
      id: message.id,
    );
  }

  /// The app identifies an attendance record as 'sessionId:studentId', while
  /// the outbox links to the session alone — the record has no id of its own to
  /// point at, and the student is already a column here.
  String? _sessionIdOf(String? attendanceRecordId) {
    if (attendanceRecordId == null) return null;
    final int split = attendanceRecordId.indexOf(':');
    return split <= 0 ? null : attendanceRecordId.substring(0, split);
  }
}
