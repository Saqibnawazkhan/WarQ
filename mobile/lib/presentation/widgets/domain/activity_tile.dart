import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/models.dart';

/// Timeline row for the activity feed.
class ActivityTile extends StatelessWidget {
  const ActivityTile({
    super.key,
    required this.log,
    this.showActor = false,
    this.isLast = false,
  });

  final ActivityLog log;

  /// Organization admins need to know who did it; a teacher's own feed does not.
  final bool showActor;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final Color color = colorFor(context, log.type);

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Column(
            children: <Widget>[
              Container(
                width: 30,
                height: 30,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(iconFor(log.type), size: 15, color: color),
              ),
              if (!isLast)
                Expanded(
                  child: Container(
                    width: 1.5,
                    margin: const EdgeInsets.symmetric(vertical: 4),
                    color: context.semantic.subtleBorder,
                  ),
                ),
            ],
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(bottom: isLast ? 0 : AppSpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(log.summary, style: context.text.bodyMedium),
                  const SizedBox(height: 2),
                  Text(
                    <String>[
                      if (showActor && log.actorName != null) log.actorName!,
                      AppDate.relativeTime(log.createdAt),
                      if (log.detail != null) log.detail!,
                    ].join(' · '),
                    style: context.text.labelSmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static IconData iconFor(ActivityType type) => switch (type) {
        ActivityType.signedIn || ActivityType.signedOut => Icons.login_rounded,
        ActivityType.classCreated ||
        ActivityType.classUpdated =>
          Icons.class_outlined,
        ActivityType.classDeleted => Icons.delete_outline_rounded,
        ActivityType.studentAdded ||
        ActivityType.studentEnrolled =>
          Icons.person_add_alt_1_rounded,
        ActivityType.studentUpdated => Icons.edit_outlined,
        ActivityType.studentRemoved ||
        ActivityType.studentUnenrolled =>
          Icons.person_remove_alt_1_rounded,
        ActivityType.attendanceMarked ||
        ActivityType.attendanceUpdated =>
          Icons.how_to_reg_rounded,
        ActivityType.assessmentCreated ||
        ActivityType.assessmentUpdated =>
          Icons.assignment_outlined,
        ActivityType.assessmentDeleted => Icons.delete_outline_rounded,
        ActivityType.marksEntered ||
        ActivityType.marksUpdated =>
          Icons.edit_note_rounded,
        ActivityType.reportGenerated => Icons.picture_as_pdf_outlined,
        ActivityType.teacherInvited => Icons.mail_outline_rounded,
        ActivityType.invitationRevoked => Icons.cancel_schedule_send_outlined,
        ActivityType.teacherJoined => Icons.group_add_outlined,
        ActivityType.teacherRemoved => Icons.group_remove_outlined,
        ActivityType.profileUpdated => Icons.manage_accounts_outlined,
        ActivityType.gradeScaleUpdated => Icons.grade_outlined,
      };

  static Color colorFor(BuildContext context, ActivityType type) =>
      switch (type) {
        ActivityType.classDeleted ||
        ActivityType.studentRemoved ||
        ActivityType.assessmentDeleted ||
        ActivityType.teacherRemoved ||
        ActivityType.invitationRevoked =>
          context.semantic.danger,
        ActivityType.attendanceMarked ||
        ActivityType.attendanceUpdated =>
          context.semantic.success,
        ActivityType.marksEntered ||
        ActivityType.marksUpdated ||
        ActivityType.reportGenerated =>
          context.semantic.info,
        _ => context.colors.primary,
      };
}

/// Notification row in the notification centre.
class NotificationTile extends StatelessWidget {
  const NotificationTile({
    super.key,
    required this.notification,
    this.onTap,
    this.onDismiss,
  });

  final AppNotification notification;
  final VoidCallback? onTap;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final Color color = colorFor(context, notification.category);
    final Widget tile = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      decoration: BoxDecoration(
        color: notification.isRead
            ? context.colors.surface
            : context.colors.primary.withValues(alpha: 0.05),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
          color: notification.isRead
              ? context.semantic.subtleBorder
              : context.colors.primary.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(iconFor(notification.category), size: 18, color: color),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        notification.title,
                        style: context.text.titleSmall?.copyWith(
                          fontWeight: notification.isRead
                              ? FontWeight.w600
                              : FontWeight.w700,
                        ),
                      ),
                    ),
                    if (!notification.isRead)
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: context.colors.primary,
                          shape: BoxShape.circle,
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 3),
                Text(notification.body, style: context.text.bodySmall),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  AppDate.relativeTime(notification.createdAt),
                  style: context.text.labelSmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );

    final Widget tappable = onTap == null
        ? tile
        : InkWell(
            onTap: onTap,
            borderRadius: AppRadii.cardRadius,
            child: tile,
          );

    if (onDismiss == null) return tappable;
    return Dismissible(
      key: ValueKey<String>(notification.id),
      direction: DismissDirection.endToStart,
      onDismissed: (_) => onDismiss!(),
      background: Container(
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: AppSpacing.xl),
        decoration: BoxDecoration(
          color: context.semantic.dangerContainer,
          borderRadius: AppRadii.cardRadius,
        ),
        child: Icon(Icons.delete_outline_rounded, color: context.semantic.danger),
      ),
      child: tappable,
    );
  }

  static IconData iconFor(NotificationCategory category) => switch (category) {
        NotificationCategory.attendance => Icons.event_available_rounded,
        NotificationCategory.assessment => Icons.assignment_turned_in_outlined,
        NotificationCategory.invitation => Icons.mail_outline_rounded,
        NotificationCategory.organization => Icons.apartment_rounded,
        NotificationCategory.system => Icons.info_outline_rounded,
        NotificationCategory.general => Icons.notifications_none_rounded,
      };

  static Color colorFor(BuildContext context, NotificationCategory category) =>
      switch (category) {
        NotificationCategory.attendance => context.semantic.success,
        NotificationCategory.assessment => context.semantic.info,
        NotificationCategory.invitation => context.colors.primary,
        NotificationCategory.organization => context.semantic.warning,
        NotificationCategory.system => context.semantic.mutedText,
        NotificationCategory.general => context.colors.primary,
      };
}
