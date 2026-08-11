import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/org_admin_controller.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/quick_action.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/domain/activity_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';
import '../org_admin_shell.dart';

/// Organization admin home: headline numbers, teacher activity and the feed.
class OrgDashboardScreen extends StatelessWidget {
  const OrgDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final OrgAdminController controller = context.watch<OrgAdminController>();
    final OrganizationDashboardData? data = controller.dashboard;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 5),
          builder: (BuildContext context) {
            if (data == null) {
              return const ErrorView(
                message: 'Your organization could not be loaded.',
              );
            }
            return AppPageBody(
              onRefresh: controller.refresh,
              children: <Widget>[
                _Header(controller: controller, data: data),
                const Gap.xl(),
                StatGrid(
                  tiles: <Widget>[
                    StatTile(
                      label: 'Teachers',
                      value: '${data.teacherCount}',
                      icon: Icons.groups_rounded,
                    ),
                    StatTile(
                      label: 'Classes',
                      value: '${data.classCount}',
                      icon: Icons.class_rounded,
                      accent: context.semantic.info,
                    ),
                    StatTile(
                      label: 'Students',
                      value: '${data.studentCount}',
                      icon: Icons.school_rounded,
                      accent: context.semantic.success,
                    ),
                    StatTile(
                      label: 'Attendance',
                      value: Format.percentOrDash(
                        data.attendance.percentage,
                        decimals: 0,
                      ),
                      icon: Icons.event_available_rounded,
                      accent: context.semantic.warning,
                      caption: '${data.sessionsThisWeek} sessions this week',
                    ),
                  ],
                ),
                const Gap.xl(),
                const SectionHeader(title: 'Quick actions'),
                QuickActionBar(
                  actions: <QuickAction>[
                    QuickAction(
                      label: 'Invite teacher',
                      icon: Icons.person_add_alt_1_rounded,
                      onTap: () => Navigator.of(context).pushNamed(
                        Routes.orgInviteTeacher,
                        arguments: const InviteTeacherArgs(),
                      ),
                    ),
                    QuickAction(
                      label: 'Invitations',
                      icon: Icons.mail_outline_rounded,
                      color: context.semantic.info,
                      onTap: () => Navigator.of(context)
                          .pushNamed(Routes.orgInvitations),
                    ),
                    QuickAction(
                      label: 'Teachers',
                      icon: Icons.groups_rounded,
                      color: context.semantic.success,
                      onTap: () =>
                          OrgShellScope.maybeOf(context)?.goToTab(OrgTab.teachers),
                    ),
                    QuickAction(
                      label: 'Classes',
                      icon: Icons.class_rounded,
                      color: context.semantic.warning,
                      onTap: () =>
                          OrgShellScope.maybeOf(context)?.goToTab(OrgTab.classes),
                    ),
                    QuickAction(
                      label: 'Reports',
                      icon: Icons.insights_rounded,
                      color: context.colors.secondary,
                      onTap: () =>
                          OrgShellScope.maybeOf(context)?.goToTab(OrgTab.reports),
                    ),
                  ],
                ),
                const Gap.xxl(),
                if (data.pendingInvitations > 0) ...<Widget>[
                  _PendingInvitesCard(count: data.pendingInvitations),
                  const Gap.xxl(),
                ],
                if (data.teacherSnapshots.isEmpty)
                  EmptyView(
                    compact: true,
                    icon: Icons.groups_outlined,
                    title: 'No teachers yet',
                    message:
                        'Invite your teachers — their classes, attendance and '
                        'results appear here automatically.',
                    actionLabel: 'Invite a teacher',
                    onAction: () => Navigator.of(context).pushNamed(
                      Routes.orgInviteTeacher,
                      arguments: const InviteTeacherArgs(),
                    ),
                  )
                else ...<Widget>[
                  SectionHeader(
                    title: 'Teacher activity',
                    subtitle: Format.plural(data.teacherCount, 'teacher'),
                    actionLabel: 'See all',
                    onAction: () =>
                        OrgShellScope.maybeOf(context)?.goToTab(OrgTab.teachers),
                  ),
                  for (final TeacherSnapshot snapshot
                      in data.teacherSnapshots.take(4))
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: TeacherSnapshotCard(snapshot: snapshot),
                    ),
                  const Gap.lg(),
                ],
                if (data.attendance.hasData) ...<Widget>[
                  SectionCard(
                    title: 'Attendance across the organization',
                    child: Column(
                      children: <Widget>[
                        LabeledProgressBar(
                          label: 'Present',
                          value: data.attendance.assessableSessions == 0
                              ? 0
                              : data.attendance.present /
                                  data.attendance.assessableSessions,
                          trailingLabel: '${data.attendance.present}',
                          color: context.semantic.success,
                        ),
                        const Gap.md(),
                        LabeledProgressBar(
                          label: 'Absent',
                          value: data.attendance.assessableSessions == 0
                              ? 0
                              : data.attendance.absent /
                                  data.attendance.assessableSessions,
                          trailingLabel: '${data.attendance.absent}',
                          color: context.semantic.danger,
                        ),
                        const Gap.md(),
                        LabeledProgressBar(
                          label: 'Late',
                          value: data.attendance.assessableSessions == 0
                              ? 0
                              : data.attendance.late /
                                  data.attendance.assessableSessions,
                          trailingLabel: '${data.attendance.late}',
                          color: context.semantic.warning,
                        ),
                      ],
                    ),
                  ),
                  const Gap.xl(),
                ],
                if (data.recentActivity.isNotEmpty)
                  SectionCard(
                    title: 'Recent activity',
                    actionLabel: 'See all',
                    onAction: () =>
                        Navigator.of(context).pushNamed(Routes.orgActivity),
                    child: Column(
                      children: <Widget>[
                        for (int i = 0;
                            i < data.recentActivity.take(6).length;
                            i++)
                          ActivityTile(
                            log: data.recentActivity[i],
                            showActor: true,
                            isLast: i == data.recentActivity.take(6).length - 1,
                          ),
                      ],
                    ),
                  ),
                const Gap.xxl(),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller, required this.data});

  final OrgAdminController controller;
  final OrganizationDashboardData data;

  @override
  Widget build(BuildContext context) {
    final Organization? organization = data.organization;

    return Row(
      children: <Widget>[
        AppAvatar(
          name: organization?.name ?? 'Organization',
          seed: organization?.id,
          size: 46,
          icon: Icons.apartment_rounded,
        ),
        const SizedBox(width: AppSpacing.md),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Organization',
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
              Text(
                organization?.name ?? 'Your organization',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pushNamed(Routes.notifications),
          icon: const Icon(Icons.notifications_none_rounded),
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}

class _PendingInvitesCard extends StatelessWidget {
  const _PendingInvitesCard({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.semantic.warningContainer,
      borderColor: context.semantic.warning.withValues(alpha: 0.35),
      onTap: () => Navigator.of(context).pushNamed(Routes.orgInvitations),
      child: Row(
        children: <Widget>[
          Icon(Icons.mark_email_unread_outlined, color: context.semantic.warning),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              '${Format.plural(count, 'invitation')} waiting to be accepted.',
              style: context.text.bodyMedium?.copyWith(
                color: context.semantic.onWarningContainer,
              ),
            ),
          ),
          Icon(
            Icons.chevron_right_rounded,
            color: context.semantic.onWarningContainer,
          ),
        ],
      ),
    );
  }
}

/// Compact teacher row used on the dashboard and the teachers tab.
class TeacherSnapshotCard extends StatelessWidget {
  const TeacherSnapshotCard({super.key, required this.snapshot});

  final TeacherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = snapshot.teacher;

    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(
        Routes.orgTeacherDetail,
        arguments: TeacherDetailArgs(teacherId: teacher.id),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(name: teacher.displayName, seed: teacher.id, size: 42),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      teacher.displayName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      teacher.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  ],
                ),
              ),
              AppBadge(
                snapshot.isActive ? 'Active' : 'Quiet',
                tone: snapshot.isActive ? BadgeTone.success : BadgeTone.neutral,
                dense: true,
              ),
            ],
          ),
          const Gap.md(),
          Row(
            children: <Widget>[
              _Metric(label: 'Classes', value: '${snapshot.classCount}'),
              _Metric(label: 'Students', value: '${snapshot.studentCount}'),
              _Metric(label: 'Sessions', value: '${snapshot.sessionCount}'),
              _Metric(
                label: 'Attendance',
                value: Format.percentOrDash(
                  snapshot.attendance.percentage,
                  decimals: 0,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          Text(
            label,
            style: context.text.labelSmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
        ],
      ),
    );
  }
}
