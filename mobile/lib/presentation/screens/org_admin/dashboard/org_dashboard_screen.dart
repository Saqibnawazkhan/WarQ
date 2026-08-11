import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/org_admin_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/domain/activity_tile.dart';
import '../../../widgets/feedback/dialogs.dart';
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
                _Header(data: data),
                const Gap.xl(),
                StatGrid(
                  // Held at two columns on every width: these four numbers are
                  // the page's headline and a four-across row shrinks them back
                  // into captions.
                  columns: 2,
                  tiles: <Widget>[
                    StatTile(
                      label: 'Teachers',
                      value: '${data.teacherCount}',
                    ),
                    StatTile(
                      label: 'Classes',
                      value: '${data.classCount}',
                    ),
                    StatTile(
                      label: 'Students',
                      value: '${data.studentCount}',
                    ),
                    StatTile(
                      label: 'Attendance',
                      value: Format.percentOrDash(
                        data.attendance.percentage,
                        decimals: 0,
                      ),
                      accent: context.semantic.success,
                      caption: '${data.sessionsThisWeek} sessions this week',
                    ),
                  ],
                ),
                const Gap.lg(),
                const _InviteTeacherCard(),
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
                    title: 'Teachers',
                    subtitle: Format.plural(data.teacherCount, 'teacher'),
                    actionLabel: 'View all',
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
  const _Header({required this.data});

  final OrganizationDashboardData data;

  Future<void> _logOut(BuildContext context) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Log out?',
      message: 'You will need your password to sign back in.',
      confirmLabel: 'Log out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<SessionController>().signOut();
  }

  @override
  Widget build(BuildContext context) {
    final Organization? organization = data.organization;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'ORGANIZATION ADMIN',
                style: context.text.labelMedium?.copyWith(
                  color: context.semantic.mutedText,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const Gap.xs(),
              Text(
                organization?.name ?? 'Your organization',
                // Two lines: an organization name is often long enough to need
                // the second one, and truncating it hides which school this is.
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        // The bar now carries four destinations, so Reports and Profile lost
        // their slots on it. This is their only door: without it an admin can
        // no longer reach the organization's charts, change their password, or
        // set the grading scale.
        PopupMenuButton<String>(
          tooltip: 'Account and settings',
          icon: const Icon(Icons.more_vert_rounded),
          onSelected: (String value) {
            switch (value) {
              case 'reports':
                OrgShellScope.maybeOf(context)?.goToTab(OrgTab.reports);
              case 'profile':
                OrgShellScope.maybeOf(context)?.goToTab(OrgTab.profile);
              case 'logout':
                _logOut(context);
            }
          },
          itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
            const PopupMenuItem<String>(
              value: 'reports',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.insights_outlined),
                title: Text('Reports'),
              ),
            ),
            const PopupMenuItem<String>(
              value: 'profile',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.person_outline_rounded),
                title: Text('Profile & settings'),
              ),
            ),
            const PopupMenuDivider(),
            const PopupMenuItem<String>(
              value: 'logout',
              child: ListTile(
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.logout_rounded),
                title: Text('Log out'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The organization admin's one job on this page, given the whole width.
class _InviteTeacherCard extends StatelessWidget {
  const _InviteTeacherCard();

  @override
  Widget build(BuildContext context) {
    final Color onBrand = context.colors.onPrimary;

    return Material(
      color: context.colors.primary,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: () => Navigator.of(context).pushNamed(
          Routes.orgInviteTeacher,
          arguments: const InviteTeacherArgs(),
        ),
        borderRadius: AppRadii.cardRadius,
        child: Padding(
          padding: AppSpacing.cardPadding,
          child: Row(
            children: <Widget>[
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Invite a teacher',
                      style: context.text.titleMedium?.copyWith(
                        color: onBrand,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const Gap.xs(),
                    Text(
                      'Send an invitation by email or WhatsApp',
                      style: context.text.bodySmall?.copyWith(
                        color: onBrand.withValues(alpha: 0.82),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: onBrand.withValues(alpha: 0.18),
                  shape: BoxShape.circle,
                ),
                child: Icon(Icons.add_rounded, color: onBrand),
              ),
            ],
          ),
        ),
      ),
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

  /// The day set mid-sentence, so it reads as "attendance today".
  ///
  /// Only the relative wordings belong in lower case — past a week
  /// [AppDate.relativeDay] hands back a formatted date, and "12 mar 2026" is
  /// not a phrase.
  static String _attendanceDay(DateTime at) {
    final String day = AppDate.relativeDay(at);
    return day == AppDate.format(at) ? day : day.toLowerCase();
  }

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = snapshot.teacher;
    final DateTime? lastAttendance = snapshot.lastAttendanceAt;
    final String detail = <String>[
      Format.plural(snapshot.classCount, 'class', 'classes'),
      Format.plural(snapshot.studentCount, 'student'),
      if (lastAttendance != null) 'attendance ${_attendanceDay(lastAttendance)}',
    ].join(' · ');

    return AppCard(
      padding: AppSpacing.tilePadding,
      onTap: () => Navigator.of(context).pushNamed(
        Routes.orgTeacherDetail,
        arguments: TeacherDetailArgs(teacherId: teacher.id),
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(name: teacher.displayName, seed: teacher.id, size: 44),
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
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          AppBadge(
            snapshot.isActive ? 'Active' : 'Idle',
            tone: snapshot.isActive ? BadgeTone.success : BadgeTone.neutral,
            dense: true,
          ),
        ],
      ),
    );
  }
}
