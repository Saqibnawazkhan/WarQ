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
import '../../../../domain/entities/student_performance.dart';
import '../../../state/base_controller.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/charts/chart_data.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/domain/student_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Read-only class view for an organization admin.
///
/// Monitoring only: an admin can inspect performance but never edits a
/// teacher's roster, attendance or marks from the mobile app.
class OrgClassDetailScreen extends StatefulWidget {
  const OrgClassDetailScreen({super.key, required this.args});

  final ClassDetailArgs args;

  @override
  State<OrgClassDetailScreen> createState() => _OrgClassDetailScreenState();
}

class _OrgClassDetailScreenState extends State<OrgClassDetailScreen> {
  ClassPerformance? _performance;
  AppUser? _teacher;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final AppDependencies deps = context.read<AppDependencies>();
    try {
      final ClassPerformance performance =
          await deps.analytics.classPerformance(widget.args.classId);
      final List<AppUser> members = performance.schoolClass.organizationId == null
          ? const <AppUser>[]
          : await deps.organizations
              .members(performance.schoolClass.organizationId!);
      AppUser? teacher;
      for (final AppUser member in members) {
        if (member.id == performance.schoolClass.teacherId) {
          teacher = member;
          break;
        }
      }

      if (!mounted) return;
      setState(() {
        _performance = performance;
        _teacher = teacher;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = BaseController.describeFailure(error);
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClassPerformance? performance = _performance;

    return Scaffold(
      appBar: AppBar(
        title: Text(performance?.schoolClass.name ?? 'Class'),
        actions: <Widget>[
          if (_teacher != null)
            IconButton(
              tooltip: 'View teacher',
              onPressed: () => Navigator.of(context).pushNamed(
                Routes.orgTeacherDetail,
                arguments: TeacherDetailArgs(teacherId: _teacher!.id),
              ),
              icon: const Icon(Icons.person_outline_rounded),
            ),
        ],
      ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_loading) return const LoadingView();
            if (_error != null) {
              return ErrorView(message: _error!, onRetry: _load);
            }
            if (performance == null) {
              return const ErrorView(message: 'This class could not be loaded.');
            }
            return AppPageBody(
              onRefresh: _load,
              children: <Widget>[
                const _ReadOnlyBanner(),
                const Gap.lg(),
                AppCard(
                  child: Column(
                    children: <Widget>[
                      DetailRow(
                        label: 'Subject',
                        value: performance.schoolClass.subject ?? '—',
                        icon: Icons.menu_book_outlined,
                      ),
                      DetailRow(
                        label: 'Section',
                        value: performance.schoolClass.section ?? '—',
                        icon: Icons.group_work_outlined,
                      ),
                      DetailRow(
                        label: 'Session',
                        value: performance.schoolClass.session ?? '—',
                        icon: Icons.calendar_today_outlined,
                      ),
                      DetailRow(
                        label: 'Teacher',
                        value: _teacher?.displayName ?? '—',
                        icon: Icons.person_outline_rounded,
                      ),
                      DetailRow(
                        label: 'Last attendance',
                        value: performance.lastSessionDate == null
                            ? 'Never'
                            : AppDate.relativeDay(performance.lastSessionDate!),
                        icon: Icons.event_available_rounded,
                      ),
                    ],
                  ),
                ),
                const Gap.xl(),
                StatGrid(
                  tiles: <Widget>[
                    StatTile(
                      label: 'Students',
                      value: '${performance.studentCount}',
                      icon: Icons.people_alt_rounded,
                    ),
                    StatTile(
                      label: 'Assessments',
                      value: '${performance.assessmentCount}',
                      icon: Icons.assignment_rounded,
                      accent: context.semantic.info,
                    ),
                    StatTile(
                      label: 'Attendance',
                      value: Format.percentOrDash(
                        performance.averageAttendance,
                        decimals: 0,
                      ),
                      icon: Icons.event_available_rounded,
                      accent: context.semantic.success,
                    ),
                    StatTile(
                      label: 'Class average',
                      value: Format.percentOrDash(
                        performance.averagePercentage,
                        decimals: 0,
                      ),
                      icon: Icons.trending_up_rounded,
                      accent: context.semantic.warning,
                    ),
                  ],
                ),
                if (performance.gradeDistribution.values
                    .any((int count) => count > 0)) ...<Widget>[
                  const Gap.xl(),
                  SectionCard(
                    title: 'Grade distribution',
                    child: HorizontalBarChart(
                      slices: <ChartSlice>[
                        for (final MapEntry<String, int> entry
                            in performance.gradeDistribution.entries)
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
                  title: 'Students',
                  subtitle: 'Sorted A–Z',
                  trailing: performance.atRisk.isEmpty
                      ? null
                      : AppBadge(
                          '${performance.atRisk.length} at risk',
                          tone: BadgeTone.warning,
                          dense: true,
                        ),
                ),
                if (performance.students.isEmpty)
                  const EmptyView(
                    compact: true,
                    icon: Icons.people_outline_rounded,
                    title: 'No students',
                    message: 'This class has no enrolled students yet.',
                  )
                else
                  for (final StudentPerformance student in performance.students)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                      child: StudentTile(
                        performance: student,
                        onTap: () => Navigator.of(context).pushNamed(
                          Routes.orgStudentDetail,
                          arguments: StudentDetailArgs(
                            studentId: student.student.id,
                            classId: performance.schoolClass.id,
                          ),
                        ),
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

class _ReadOnlyBanner extends StatelessWidget {
  const _ReadOnlyBanner();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.colors.surfaceContainerHigh,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Icon(
            Icons.visibility_outlined,
            size: 18,
            color: context.semantic.mutedText,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              'Monitoring view — only the class teacher can make changes.',
              style: context.text.bodySmall
                  ?.copyWith(color: context.semantic.mutedText),
            ),
          ),
        ],
      ),
    );
  }
}
