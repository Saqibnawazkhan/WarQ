import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../state/notifications_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/common/app_badge.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/domain/activity_tile.dart';
import '../../widgets/feedback/dialogs.dart';
import '../../widgets/feedback/state_views.dart';
import '../../widgets/layout/app_page.dart';

/// Notification centre with a second tab for the guardian message outbox.
class NotificationsScreen extends StatelessWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser user = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<NotificationsController>(
      create: (BuildContext context) =>
          NotificationsController(context.read<AppDependencies>(), user)..load(),
      child: const _NotificationsView(),
    );
  }
}

class _NotificationsView extends StatelessWidget {
  const _NotificationsView();

  @override
  Widget build(BuildContext context) {
    final NotificationsController controller =
        context.watch<NotificationsController>();

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Notifications'),
          actions: <Widget>[
            if (controller.hasUnread)
              TextButton(
                onPressed: controller.markAllRead,
                child: const Text('Mark all read'),
              ),
            PopupMenuButton<String>(
              onSelected: (String value) async {
                if (value == 'clear') {
                  final bool confirmed = await showConfirmDialog(
                    context,
                    title: 'Clear notifications?',
                    message: 'All notifications will be removed from this device.',
                    confirmLabel: 'Clear',
                    isDestructive: true,
                    icon: Icons.clear_all_rounded,
                  );
                  if (confirmed) await controller.clearAll();
                } else if (value == 'unread') {
                  controller.setUnreadOnly(!controller.unreadOnly);
                }
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                CheckedPopupMenuItem<String>(
                  value: 'unread',
                  checked: controller.unreadOnly,
                  child: const Text('Unread only'),
                ),
                const PopupMenuItem<String>(
                  value: 'clear',
                  child: Text('Clear all'),
                ),
              ],
            ),
          ],
          bottom: TabBar(
            tabs: <Widget>[
              Tab(
                text: controller.hasUnread
                    ? 'Alerts (${controller.unreadCount})'
                    : 'Alerts',
              ),
              Tab(text: 'Guardian messages (${controller.outbox.length})'),
            ],
          ),
        ),
        body: TabBarView(
          children: <Widget>[
            _AlertsTab(controller: controller),
            _OutboxTab(controller: controller),
          ],
        ),
      ),
    );
  }
}

class _AlertsTab extends StatelessWidget {
  const _AlertsTab({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final List<AppNotification> visible = controller.visible;

    return ControllerStateView(
      controller: controller,
      loading: const SkeletonList(itemCount: 5, itemHeight: 92),
      empty: const EmptyView(
        icon: Icons.notifications_none_rounded,
        title: 'You are all caught up',
        message: 'Reminders and organization updates will appear here.',
      ),
      builder: (BuildContext context) {
        if (visible.isEmpty) {
          return EmptyView(
            icon: Icons.mark_email_read_outlined,
            title: 'Nothing unread',
            message: 'Every notification has been read.',
            actionLabel: 'Show all',
            onAction: () => controller.setUnreadOnly(false),
          );
        }
        return RefreshIndicator(
          onRefresh: controller.refresh,
          child: ContentWidth(
            child: ListView.separated(
              padding: const EdgeInsets.all(AppSpacing.lg),
              itemCount: visible.length,
              separatorBuilder: (_, __) => const Gap.sm(),
              itemBuilder: (BuildContext context, int index) {
                final AppNotification notification = visible[index];
                return NotificationTile(
                  notification: notification,
                  onTap: () => controller.markRead(notification.id),
                  onDismiss: () => controller.delete(notification.id),
                );
              },
            ),
          ),
        );
      },
    );
  }
}

/// Absence notices queued for guardians.
///
/// Phase 1 records them without sending; connecting a provider flips the
/// status column to "sent" without any UI change.
class _OutboxTab extends StatelessWidget {
  const _OutboxTab({required this.controller});

  final NotificationsController controller;

  @override
  Widget build(BuildContext context) {
    final List<OutboundMessage> messages = controller.outbox;

    return ContentWidth(
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        children: <Widget>[
          AppCard(
            color: context.semantic.infoContainer,
            borderColor: context.semantic.info.withValues(alpha: 0.3),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: context.semantic.info,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Text(
                        'Delivery: ${controller.messagingProviderName}',
                        style: context.text.labelLarge?.copyWith(
                          color: context.semantic.onInfoContainer,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        controller.messagingStatus,
                        style: context.text.bodySmall?.copyWith(
                          color: context.semantic.onInfoContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const Gap.lg(),
          if (messages.isEmpty)
            const EmptyView(
              compact: true,
              icon: Icons.forward_to_inbox_outlined,
              title: 'No guardian messages yet',
              message:
                  'When you mark a student absent, a message is prepared for '
                  'every phone number on their record.',
            )
          else
            for (final OutboundMessage message in messages)
              Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.md),
                child: _OutboundTile(
                  message: message,
                  onRetry: () => controller.retryMessage(message),
                ),
              ),
        ],
      ),
    );
  }
}

class _OutboundTile extends StatelessWidget {
  const _OutboundTile({required this.message, required this.onRetry});

  final OutboundMessage message;
  final VoidCallback onRetry;

  BadgeTone get _tone => switch (message.status) {
        MessageStatus.sent => BadgeTone.success,
        MessageStatus.queued => BadgeTone.info,
        MessageStatus.failed => BadgeTone.danger,
        MessageStatus.skipped => BadgeTone.neutral,
      };

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  message.studentName ?? 'Student',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              AppBadge(message.status.label, tone: _tone, dense: true),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${message.relation.label} · ${Format.maskedPhone(message.recipientPhone)}'
            '${message.className == null ? '' : ' · ${message.className}'}',
            style: context.text.labelSmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
          const Gap.md(),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHigh,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Text(message.body, style: context.text.bodySmall),
          ),
          const Gap.sm(),
          Row(
            children: <Widget>[
              Text(
                AppDate.relativeTime(message.createdAt),
                style: context.text.labelSmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
              const Spacer(),
              if (message.status != MessageStatus.sent)
                TextButton.icon(
                  onPressed: onRetry,
                  icon: Icon(
                    message.status == MessageStatus.failed
                        ? Icons.refresh_rounded
                        : Icons.send_rounded,
                    size: 16,
                  ),
                  label: Text(
                    message.status == MessageStatus.failed ? 'Retry' : 'Send',
                  ),
                  style: TextButton.styleFrom(
                    padding:
                        const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
            ],
          ),
          if (message.failureReason != null) ...<Widget>[
            const Gap.xs(),
            Text(
              message.failureReason!,
              style: context.text.labelSmall
                  ?.copyWith(color: context.semantic.danger),
            ),
          ],
        ],
      ),
    );
  }
}
