import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/org_admin_controller.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/charts/chart_data.dart';
import '../../../widgets/charts/donut_chart.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Organization-wide performance overview.
class OrgReportsTab extends StatelessWidget {
  const OrgReportsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final OrgAdminController controller = context.watch<OrgAdminController>();
    final OrganizationDashboardData? data = controller.dashboard;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Reports'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Activity log',
            onPressed: () => Navigator.of(context).pushNamed(Routes.orgActivity),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 4),
          builder: (BuildContext context) {
            if (data == null || data.teacherSnapshots.isEmpty) {
              return const EmptyView(
                icon: Icons.insights_outlined,
                title: 'Nothing to report yet',
                message:
                    'Once your teachers add classes and record attendance, '
                    'organization-level insights appear here.',
              );
            }

            final List<TeacherSnapshot> ranked =
                List<TeacherSnapshot>.of(data.teacherSnapshots)
                  ..sort((TeacherSnapshot a, TeacherSnapshot b) =>
                      (b.averagePercentage ?? -1)
                          .compareTo(a.averagePercentage ?? -1));

            return AppPageBody(
              onRefresh: controller.refresh,
              children: <Widget>[
                StatGrid(
                  tiles: <Widget>[
                    StatTile(
                      label: 'Average marks',
                      value: Format.percentOrDash(
                        data.averagePercentage,
                        decimals: 0,
                      ),
                      icon: Icons.trending_up_rounded,
                    ),
                    StatTile(
                      label: 'Attendance',
                      value: Format.percentOrDash(
                        data.attendance.percentage,
                        decimals: 0,
                      ),
                      icon: Icons.event_available_rounded,
                      accent: context.semantic.success,
                    ),
                    StatTile(
                      label: 'Sessions this week',
                      value: '${data.sessionsThisWeek}',
                      icon: Icons.calendar_view_week_rounded,
                      accent: context.semantic.info,
                    ),
                    StatTile(
                      label: 'Active teachers',
                      value: '${ranked.where((TeacherSnapshot s) => s.isActive).length}'
                          '/${ranked.length}',
                      icon: Icons.groups_rounded,
                      accent: context.semantic.warning,
                    ),
                  ],
                ),
                const Gap.xl(),
                if (data.attendance.hasData)
                  SectionCard(
                    title: 'Attendance breakdown',
                    subtitle: 'Every recorded session across the organization',
                    child: DonutChart(
                      slices: <ChartSlice>[
                        ChartSlice(
                          label: 'Present',
                          value: data.attendance.present.toDouble(),
                          color: context.semantic.success,
                        ),
                        ChartSlice(
                          label: 'Absent',
                          value: data.attendance.absent.toDouble(),
                          color: context.semantic.danger,
                        ),
                        ChartSlice(
                          label: 'Late',
                          value: data.attendance.late.toDouble(),
                          color: context.semantic.warning,
                        ),
                        ChartSlice(
                          label: 'Excused',
                          value: data.attendance.excused.toDouble(),
                          color: context.semantic.info,
                        ),
                      ],
                      centerValue: Format.percentOrDash(
                        data.attendance.percentage,
                        decimals: 0,
                      ),
                      centerLabel: 'attended',
                    ),
                  ),
                const Gap.xl(),
                SectionCard(
                  title: 'Class average by teacher',
                  child: HorizontalBarChart(
                    labelWidth: 0,
                    maxValue: 100,
                    showValues: true,
                    slices: <ChartSlice>[
                      for (final TeacherSnapshot snapshot in ranked)
                        ChartSlice(
                          label: '',
                          value: snapshot.averagePercentage ?? 0,
                          color: context.colors.primary,
                        ),
                    ],
                  ),
                ),
                const Gap.xl(),
                const SectionHeader(
                  title: 'Teacher performance',
                  subtitle: 'Ranked by class average',
                ),
                for (final TeacherSnapshot snapshot in ranked)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: _TeacherPerformanceRow(snapshot: snapshot),
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

class _TeacherPerformanceRow extends StatelessWidget {
  const _TeacherPerformanceRow({required this.snapshot});

  final TeacherSnapshot snapshot;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: () => Navigator.of(context).pushNamed(
        Routes.orgTeacherDetail,
        arguments: TeacherDetailArgs(teacherId: snapshot.teacher.id),
      ),
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: snapshot.teacher.displayName,
            seed: snapshot.teacher.id,
            size: 38,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  snapshot.teacher.displayName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${Format.plural(snapshot.classCount, 'class', 'classes')} · '
                  '${Format.plural(snapshot.studentCount, 'student')}',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              GradeBadge(
                grade: Format.percentOrDash(
                  snapshot.averagePercentage,
                  decimals: 0,
                ),
                percent: snapshot.averagePercentage,
                dense: true,
              ),
              const SizedBox(height: 3),
              AttendanceBadge(
                percent: snapshot.attendance.percentage,
                dense: true,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
