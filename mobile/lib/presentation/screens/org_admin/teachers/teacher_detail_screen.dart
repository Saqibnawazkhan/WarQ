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
      appBar: AppBar(title: Text(teacher?.displayName ?? 'Teacher')),
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
              _TeacherProfileCard(snapshot: snapshot),
              const Gap.xl(),
              StatGrid(
                // Two up, so each figure keeps the weight it has on the
                // organization dashboard.
                columns: 2,
                tiles: <Widget>[
                  StatTile(
                    label: 'Classes',
                    value: '${snapshot.classCount}',
                  ),
                  StatTile(
                    label: 'Students',
                    value: '${snapshot.studentCount}',
                  ),
                  StatTile(
                    label: 'Attendance sessions',
                    value: '${snapshot.sessionCount}',
                  ),
                  StatTile(
                    label: 'Assessments',
                    value: '${snapshot.assessmentCount}',
                  ),
                ],
              ),
              const Gap.xl(),
              SectionCard(
                title: 'Classes',
                subtitle: Format.plural(snapshot.classCount, 'class', 'classes'),
                child: controller.classes.isEmpty
                    ? Text(
                        'This teacher has not created any classes.',
                        style: context.text.bodyMedium
                            ?.copyWith(color: context.semantic.mutedText),
                      )
                    : Column(
                        children: <Widget>[
                          for (final ClassSummary summary in controller.classes)
                            _ClassRow(summary: summary),
                        ],
                      ),
              ),
              const Gap.xl(),
              SectionCard(
                title: 'Recent activity',
                child: Column(
                  children: <Widget>[
                    DetailRow(
                      label: 'Last attendance taken',
                      value: snapshot.lastAttendanceAt == null
                          ? 'Never'
                          : AppDate.relativeDay(snapshot.lastAttendanceAt!),
                    ),
                    DetailRow(
                      label: 'Attendance rate',
                      value: Format.percentOrDash(
                        snapshot.attendance.percentage,
                      ),
                      valueColor: snapshot.attendance.percentageOrZero >= 75
                          ? context.semantic.success
                          : context.semantic.warning,
                    ),
                    DetailRow(
                      label: 'Marks entered',
                      value: '${snapshot.marksRecorded}',
                    ),
                    DetailRow(
                      label: 'Class average',
                      value: Format.percentOrDash(snapshot.averagePercentage),
                    ),
                    DetailRow(
                      label: 'Last seen',
                      value: teacher.lastLoginAt == null
                          ? 'Never signed in'
                          : AppDate.relativeTime(teacher.lastLoginAt!),
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

class _TeacherProfileCard extends StatelessWidget {
  const _TeacherProfileCard({required this.snapshot});

  final TeacherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = snapshot.teacher;
    final TextStyle? mutedLine =
        context.text.bodySmall?.copyWith(color: context.semantic.mutedText);

    return AppCard(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          AppAvatar(name: teacher.displayName, seed: teacher.id, size: 60),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  teacher.displayName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                if (teacher.title != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    teacher.title!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mutedLine,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  teacher.email,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: mutedLine,
                ),
                if (teacher.phone != null) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    teacher.phone!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: mutedLine,
                  ),
                ],
                const SizedBox(height: AppSpacing.xxs),
                Text('Joined ${AppDate.format(teacher.createdAt)}',
                    style: mutedLine),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.sm,
                  runSpacing: AppSpacing.sm,
                  children: <Widget>[
                    AppBadge(
                      snapshot.isActive ? 'Active' : 'Idle',
                      tone: snapshot.isActive
                          ? BadgeTone.success
                          : BadgeTone.neutral,
                      dense: true,
                    ),
                    // Only worth a pill when it is a problem — an account that
                    // can sign in says nothing the "Active" badge does not.
                    if (!teacher.status.canSignIn)
                      AppBadge(
                        teacher.status.label,
                        tone: BadgeTone.danger,
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

class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.summary});

  final ClassSummary summary;

  @override
  Widget build(BuildContext context) {
    final String subtitle = summary.schoolClass.subtitle;

    return InkWell(
      onTap: () => Navigator.of(context).pushNamed(
        Routes.orgClassDetail,
        arguments: ClassDetailArgs(classId: summary.id),
      ),
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
        child: Row(
          children: <Widget>[
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    summary.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  if (subtitle.isNotEmpty) ...<Widget>[
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      subtitle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              Format.plural(summary.studentCount, 'student'),
              style: context.text.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: context.semantic.mutedText,
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
