import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/org_admin_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';
import '../../../widgets/layout/floating_nav_bar.dart';
import '../dashboard/org_dashboard_screen.dart';

/// Teacher directory for an organization admin.
class OrgTeachersTab extends StatelessWidget {
  const OrgTeachersTab({super.key});

  @override
  Widget build(BuildContext context) {
    final OrgAdminController controller = context.watch<OrgAdminController>();
    final List<TeacherSnapshot> teachers = controller.visibleTeachers;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Teachers'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Invitations',
            onPressed: () =>
                Navigator.of(context).pushNamed(Routes.orgInvitations),
            icon: Badge(
              isLabelVisible: controller.pendingInvitations.isNotEmpty,
              label: Text('${controller.pendingInvitations.length}'),
              child: const Icon(Icons.mail_outline_rounded),
            ),
          ),
        ],
      ),
      floatingActionButton: ClearOfNavBar(
        child: FloatingActionButton.extended(
          heroTag: 'fab-org-teachers',
          onPressed: () => Navigator.of(context).pushNamed(
            Routes.orgInviteTeacher,
            arguments: const InviteTeacherArgs(),
          ),
          icon: const Icon(Icons.person_add_alt_1_rounded),
          label: const Text('Invite teacher'),
        ),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: ContentWidth(
                child: SearchField(
                  hintText: 'Search teachers by name or email',
                  initialValue: controller.teacherQuery,
                  onChanged: controller.searchTeachers,
                ),
              ),
            ),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 4, itemHeight: 128),
                builder: (BuildContext context) {
                  if (controller.teachers.isEmpty) {
                    return EmptyView(
                      icon: Icons.groups_outlined,
                      title: 'No teachers yet',
                      message:
                          'Invite teachers by email. When they create an account '
                          'with that address they join your organization '
                          'automatically.',
                      actionLabel: 'Invite a teacher',
                      onAction: () => Navigator.of(context).pushNamed(
                        Routes.orgInviteTeacher,
                        arguments: const InviteTeacherArgs(),
                      ),
                    );
                  }
                  if (teachers.isEmpty) {
                    return EmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message:
                          'No teacher matches "${controller.teacherQuery}".',
                      actionLabel: 'Clear search',
                      onAction: () => controller.searchTeachers(''),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ContentWidth(
                      child: ListView.separated(
                        // Room for the action button, and for the nav bar the
                        // list scrolls behind on top of that.
                        padding: EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.fabClearance +
                              FloatingNavBar.reservedHeight(context),
                        ),
                        itemCount: teachers.length + 1,
                        separatorBuilder: (_, __) => const Gap.md(),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == teachers.length) {
                            return _InvitationsSummary(controller: controller);
                          }
                          return TeacherSnapshotCard(snapshot: teachers[index]);
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InvitationsSummary extends StatelessWidget {
  const _InvitationsSummary({required this.controller});

  final OrgAdminController controller;

  @override
  Widget build(BuildContext context) {
    final int pending = controller.pendingInvitations.length;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        color: context.colors.surfaceContainerHigh,
        onTap: () => Navigator.of(context).pushNamed(Routes.orgInvitations),
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              Icons.mail_outline_rounded,
              size: 18,
              color: context.semantic.mutedText,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                pending == 0
                    ? 'No pending invitations.'
                    : '${Format.plural(pending, 'invitation')} pending.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: context.semantic.mutedText,
            ),
          ],
        ),
      ),
    );
  }
}
