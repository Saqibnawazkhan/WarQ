import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/services/messaging/message_templates.dart';
import '../../../state/org_admin_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Invitation tracker: pending, accepted, revoked and expired.
class InvitationsScreen extends StatelessWidget {
  const InvitationsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser admin = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<OrgAdminController>(
      create: (BuildContext context) =>
          OrgAdminController(context.read<AppDependencies>(), admin)..load(),
      child: const _InvitationsView(),
    );
  }
}

class _InvitationsView extends StatelessWidget {
  const _InvitationsView();

  @override
  Widget build(BuildContext context) {
    final OrgAdminController controller = context.watch<OrgAdminController>();
    final List<Invitation> invitations = controller.invitations;

    return Scaffold(
      appBar: AppBar(title: const Text('Invitations')),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-invitations',
        onPressed: () => Navigator.of(context).pushNamed(
          Routes.orgInviteTeacher,
          arguments: const InviteTeacherArgs(),
        ),
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Invite'),
      ),
      body: SafeArea(
        child: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 4, itemHeight: 120),
          builder: (BuildContext context) {
            if (invitations.isEmpty) {
              return EmptyView(
                icon: Icons.mail_outline_rounded,
                title: 'No invitations yet',
                message:
                    'Invite teachers by email — they join your organization as '
                    'soon as they create an account.',
                actionLabel: 'Invite a teacher',
                onAction: () => Navigator.of(context).pushNamed(
                  Routes.orgInviteTeacher,
                  arguments: const InviteTeacherArgs(),
                ),
              );
            }
            return RefreshIndicator(
              onRefresh: controller.refresh,
              child: ContentWidth(
                child: ListView.separated(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.fabClearance,
                  ),
                  itemCount: invitations.length,
                  separatorBuilder: (_, __) => const Gap.md(),
                  itemBuilder: (BuildContext context, int index) =>
                      _InvitationCard(
                    invitation: invitations[index],
                    controller: controller,
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}

class _InvitationCard extends StatelessWidget {
  const _InvitationCard({required this.invitation, required this.controller});

  final Invitation invitation;
  final OrgAdminController controller;

  BadgeTone get _tone => switch (invitation.effectiveStatus) {
        InvitationStatus.pending => BadgeTone.warning,
        InvitationStatus.accepted => BadgeTone.success,
        InvitationStatus.revoked => BadgeTone.neutral,
        InvitationStatus.expired => BadgeTone.danger,
      };

  @override
  Widget build(BuildContext context) {
    final InvitationStatus status = invitation.effectiveStatus;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      invitation.inviteeName ?? invitation.email,
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (invitation.inviteeName != null) ...<Widget>[
                      const SizedBox(height: 2),
                      Text(
                        invitation.email,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              AppBadge(status.label, tone: _tone, dense: true),
            ],
          ),
          const Gap.sm(),
          Text(
            status == InvitationStatus.accepted
                ? 'Accepted ${AppDate.relativeDay(invitation.acceptedAt ?? invitation.createdAt)}'
                : status == InvitationStatus.pending
                    ? 'Sent ${AppDate.relativeDay(invitation.createdAt)} · expires '
                        '${AppDate.format(invitation.expiresAt)}'
                    : 'Sent ${AppDate.relativeDay(invitation.createdAt)}',
            style: context.text.labelSmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
          if (invitation.message != null) ...<Widget>[
            const Gap.sm(),
            Text(
              '"${invitation.message}"',
              style: context.text.bodySmall?.copyWith(
                fontStyle: FontStyle.italic,
                color: context.semantic.mutedText,
              ),
            ),
          ],
          if (status != InvitationStatus.accepted) ...<Widget>[
            const Gap.md(),
            Row(
              children: <Widget>[
                TextButton.icon(
                  onPressed: () {
                    final String text = MessageTemplates.invitation(
                      organizationName:
                          controller.organization?.name ?? 'the organization',
                      inviterName: controller.admin.displayName,
                      token: invitation.token,
                      inviteeName: invitation.inviteeName,
                    );
                    Clipboard.setData(ClipboardData(text: text));
                    context.showInfo('Invitation text copied.');
                  },
                  icon: const Icon(Icons.copy_rounded, size: 18),
                  label: const Text('Copy'),
                ),
                const SizedBox(width: AppSpacing.sm),
                if (status == InvitationStatus.expired ||
                    status == InvitationStatus.revoked)
                  TextButton.icon(
                    onPressed: () async {
                      final bool ok =
                          await controller.resendInvitation(invitation.id);
                      if (!context.mounted) return;
                      if (ok) context.showSuccess('Invitation reactivated.');
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 18),
                    label: const Text('Resend'),
                  ),
                const Spacer(),
                if (status == InvitationStatus.pending)
                  TextButton.icon(
                    onPressed: () async {
                      final bool confirmed = await showConfirmDialog(
                        context,
                        title: 'Revoke invitation?',
                        message:
                            '${invitation.email} will no longer be able to join '
                            'your organization with this invitation.',
                        confirmLabel: 'Revoke',
                        isDestructive: true,
                        icon: Icons.cancel_schedule_send_outlined,
                      );
                      if (!confirmed || !context.mounted) return;
                      final bool ok =
                          await controller.revokeInvitation(invitation.id);
                      if (!context.mounted) return;
                      if (ok) context.showSuccess('Invitation revoked.');
                    },
                    icon: Icon(
                      Icons.cancel_schedule_send_outlined,
                      size: 18,
                      color: context.semantic.danger,
                    ),
                    label: Text(
                      'Revoke',
                      style: TextStyle(color: context.semantic.danger),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
