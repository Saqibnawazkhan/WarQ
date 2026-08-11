import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/session_controller.dart';
import '../../../state/teacher_monitor_controller.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/charts/chart_data.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/domain/activity_tile.dart';
import '../../../widgets/domain/class_card.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Read-only monitoring view of one teacher inside the organization.
class TeacherDetailScreen extends StatelessWidget {
  const TeacherDetailScreen({super.key, required this.args});

  final TeacherDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final AppUser admin = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<TeacherMonitorController>(
      create: (BuildContext context) => TeacherMonitorController(
        context.read<AppDependencies>(),
        admin,
        args.teacherId,
      )..load(),
      child: const _TeacherDetailView(),
    );
  }
}

class _TeacherDetailView extends StatelessWidget {
  const _TeacherDetailView();

  Future<void> _removeTeacher(
    BuildContext context,
    TeacherMonitorController controller,
  ) async {
    final AppUser? teacher = controller.teacher;
    if (teacher == null) return;

    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Remove ${teacher.displayName}?',
      message:
          'Are you sure you want to remove this teacher from your organization? '
          'Their classes, students and history are preserved on their own '
          'account and simply stop appearing in your dashboard.',
      confirmLabel: 'Remove teacher',
      isDestructive: true,
      icon: Icons.group_remove_outlined,
    );
    if (!confirmed || !context.mounted) return;

    final bool ok = await controller.removeFromOrganization();
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      context.showSuccess('${teacher.displayName} removed from the organization.');
    } else {
      context.showError(
        controller.errorMessage ?? 'Could not remove this teacher.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final TeacherMonitorController controller =
        context.watch<TeacherMonitorController>();
    final TeacherSnapshot? snapshot = controller.snapshot;
    final AppUser? teacher = controller.teacher;

    return Scaffold(
      appBar: AppBar(
        title: Text(teacher?.displayName ?? 'Teacher'),
        actions: <Widget>[
          if (teacher != null)
            PopupMenuButton<String>(
              onSelected: (String value) {
                if (value == 'remove') _removeTeacher(context, controller);
              },
              itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                PopupMenuItem<String>(
                  value: 'remove',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                      Icons.group_remove_outlined,
                      color: context.semantic.danger,
                    ),
                    title: Text(
                      'Remove from organization',
                      style: TextStyle(color: context.semantic.danger),
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
      body: ControllerStateView(
        controller: controller,
        loading: const SkeletonList(itemCount: 4),
        builder: (BuildContext context) {
          if (snapshot == null || teacher == null) {
            return const ErrorView(
              message: 'This teacher could not be loaded.',
            );
          }
          return AppPageBody(
            onRefresh: controller.refresh,
            children: <Widget>[
              _TeacherHeader(snapshot: snapshot),
              const Gap.xl(),
              SectionCard(
                title: 'Teacher information',
                child: Column(
                  children: <Widget>[
                    DetailRow(
                      label: 'Email',
                      value: teacher.email,
                      icon: Icons.alternate_email_rounded,
                    ),
                    DetailRow(
                      label: 'Account status',
                      value: teacher.status.label,
                      icon: Icons.verified_user_outlined,
                      valueColor: teacher.status.canSignIn
                          ? context.semantic.success
                          : context.semantic.danger,
                    ),
                    DetailRow(
                      label: 'Joined',
                      value: AppDate.format(teacher.createdAt),
                      icon: Icons.calendar_today_outlined,
                    ),
                    DetailRow(
                      label: 'Last seen',
                      value: teacher.lastLoginAt == null
                          ? 'Never signed in'
                          : AppDate.relativeTime(teacher.lastLoginAt!),
                      icon: Icons.login_rounded,
                    ),
                    if (teacher.phone != null)
                      DetailRow(
                        label: 'Phone',
                        value: teacher.phone!,
                        icon: Icons.phone_outlined,
                      ),
                    if (teacher.title != null)
                      DetailRow(
                        label: 'Title',
                        value: teacher.title!,
                        icon: Icons.badge_outlined,
                      ),
                  ],
                ),
              ),
              const Gap.xl(),
              StatGrid(
                tiles: <Widget>[
                  StatTile(
                    label: 'Classes',
                    value: '${snapshot.classCount}',
                    icon: Icons.class_rounded,
                  ),
                  StatTile(
                    label: 'Students',
                    value: '${snapshot.studentCount}',
                    icon: Icons.people_alt_rounded,
                    accent: context.semantic.info,
                  ),
                  StatTile(
                    label: 'Assessments',
                    value: '${snapshot.assessmentCount}',
                    icon: Icons.assignment_rounded,
                    accent: context.semantic.warning,
                  ),
                  StatTile(
                    label: 'Marks entered',
                    value: '${snapshot.marksRecorded}',
                    icon: Icons.edit_note_rounded,
                    accent: context.colors.secondary,
                  ),
                ],
              ),
              const Gap.xl(),
              SectionCard(
                title: 'Attendance activity',
                child: Column(
                  children: <Widget>[
                    DetailRow(
                      label: 'Attendance sessions',
                      value: '${snapshot.sessionCount}',
                      icon: Icons.how_to_reg_rounded,
                    ),
                    DetailRow(
                      label: 'Last attendance taken',
                      value: snapshot.lastAttendanceAt == null
                          ? 'Never'
                          : AppDate.relativeDay(snapshot.lastAttendanceAt!),
                      icon: Icons.event_available_rounded,
                    ),
                    DetailRow(
                      label: 'Attendance rate',
                      value: Format.percentOrDash(
                        snapshot.attendance.percentage,
                      ),
                      icon: Icons.percent_rounded,
                      valueColor: snapshot.attendance.percentageOrZero >= 75
                          ? context.semantic.success
                          : context.semantic.warning,
                    ),
                    DetailRow(
                      label: 'Class average',
                      value: Format.percentOrDash(snapshot.averagePercentage),
                      icon: Icons.trending_up_rounded,
                    ),
                  ],
                ),
              ),
              if (snapshot.gradeDistribution.values
                  .any((int count) => count > 0)) ...<Widget>[
                const Gap.xl(),
                SectionCard(
                  title: 'Grade distribution',
                  subtitle: 'Across every class this teacher runs',
                  child: HorizontalBarChart(
                    slices: <ChartSlice>[
                      for (final MapEntry<String, int> entry
                          in snapshot.gradeDistribution.entries)
                        ChartSlice(
                          label: entry.key,
                          value: entry.value.toDouble(),
                          color: context.colors.primary,
                        ),
                    ],
                  ),
                ),
              ],
              const Gap.xl(),
              SectionHeader(
                title: 'Classes',
                subtitle: Format.plural(snapshot.classCount, 'class', 'classes'),
              ),
              if (controller.classes.isEmpty)
                const EmptyView(
                  compact: true,
                  icon: Icons.class_outlined,
                  title: 'No classes yet',
                  message: 'This teacher has not created any classes.',
                )
              else
                for (final ClassSummary summary in controller.classes)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: ClassCard(
                      summary: summary,
                      onTap: () => Navigator.of(context).pushNamed(
                        Routes.orgClassDetail,
                        arguments: ClassDetailArgs(classId: summary.id),
                      ),
                    ),
                  ),
              const Gap.lg(),
              if (controller.activity.isNotEmpty)
                SectionCard(
                  title: 'Recent activity',
                  child: Column(
                    children: <Widget>[
                      for (int i = 0;
                          i < controller.activity.take(12).length;
                          i++)
                        ActivityTile(
                          log: controller.activity[i],
                          isLast: i == controller.activity.take(12).length - 1,
                        ),
                    ],
                  ),
                ),
              const Gap.xxl(),
              OutlinedButton.icon(
                onPressed: () => _removeTeacher(context, controller),
                icon: Icon(
                  Icons.group_remove_outlined,
                  color: context.semantic.danger,
                ),
                label: Text(
                  'Remove from organization',
                  style: TextStyle(color: context.semantic.danger),
                ),
                style: OutlinedButton.styleFrom(
                  side: BorderSide(
                    color: context.semantic.danger.withValues(alpha: 0.4),
                  ),
                ),
              ),
              const Gap.xxl(),
            ],
          );
        },
      ),
    );
  }
}

class _TeacherHeader extends StatelessWidget {
  const _TeacherHeader({required this.snapshot});

  final TeacherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = snapshot.teacher;

    return AppCard(
      child: Row(
        children: <Widget>[
          AppAvatar(name: teacher.displayName, seed: teacher.id, size: 60),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  teacher.displayName,
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  teacher.title ?? teacher.role.label,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppBadge(
                      snapshot.isActive ? 'Active this week' : 'No recent activity',
                      tone: snapshot.isActive
                          ? BadgeTone.success
                          : BadgeTone.neutral,
                      dense: true,
                    ),
                    if (snapshot.lastActivityAt != null)
                      AppBadge(
                        AppDate.relativeTime(snapshot.lastActivityAt!),
                        icon: Icons.schedule_rounded,
                        dense: true,
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
