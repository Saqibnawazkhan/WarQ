import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/session_controller.dart';
import '../../../state/teacher_dashboard_controller.dart';
import '../../../widgets/charts/chart_data.dart';
import '../../../widgets/charts/donut_chart.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/quick_action.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/domain/activity_tile.dart';
import '../../../widgets/domain/assessment_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';
import '../teacher_shell.dart';

/// The teacher's home screen.
class TeacherDashboardScreen extends StatelessWidget {
  const TeacherDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<TeacherDashboardController>(
      create: (BuildContext context) =>
          TeacherDashboardController(context.read<AppDependencies>(), teacher)
            ..load(),
      child: const _DashboardView(),
    );
  }
}

class _DashboardView extends StatelessWidget {
  const _DashboardView();

  void _openClass(BuildContext context, String classId, {int tab = 0}) {
    Navigator.of(context).pushNamed(
      Routes.classDetail,
      arguments: ClassDetailArgs(classId: classId, initialTab: tab),
    );
  }

  Future<void> _pickClassThen(
    BuildContext context, {
    required String title,
    required List<ClassSummary> classes,
    required void Function(ClassSummary summary) onPicked,
    String emptyMessage = 'Create a class first.',
  }) async {
    if (classes.isEmpty) {
      context.showInfo(emptyMessage);
      return;
    }
    if (classes.length == 1) {
      onPicked(classes.first);
      return;
    }
    final ClassSummary? picked = await showModalBottomSheet<ClassSummary>(
      context: context,
      useSafeArea: true,
      builder: (BuildContext sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.xl,
                AppSpacing.lg,
                AppSpacing.xl,
                AppSpacing.md,
              ),
              child: Text(
                title,
                style: sheetContext.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ),
            Flexible(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: classes.length,
                itemBuilder: (BuildContext context, int index) {
                  final ClassSummary summary = classes[index];
                  return ListTile(
                    // Aligns the rows with the sheet's heading and gives each one
                    // room to breathe at the larger type scale.
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.xl,
                      vertical: AppSpacing.sm,
                    ),
                    leading: ClassAvatar(
                      name: summary.name,
                      seed: summary.schoolClass.avatarKey,
                    ),
                    title: Text(
                      summary.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    subtitle: Text(
                      Format.plural(summary.studentCount, 'student'),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                    onTap: () => Navigator.of(sheetContext).pop(summary),
                  );
                },
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
        ),
      ),
    );
    if (picked != null) onPicked(picked);
  }

  @override
  Widget build(BuildContext context) {
    final TeacherDashboardController controller =
        context.watch<TeacherDashboardController>();
    final TeacherDashboardData data = controller.data;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 5),
          builder: (BuildContext context) => AppPageBody(
            onRefresh: controller.refresh,
            children: <Widget>[
              _Header(controller: controller),
              const Gap.xxl(),
              _StatsSection(data: data),
              const Gap.xxl(),
              const SectionHeader(title: 'Quick actions'),
              _QuickActions(
                data: data,
                onPickClass: _pickClassThen,
                onOpenClass: _openClass,
              ),
              const Gap.xxl(),
              if (data.today.pendingClasses.isNotEmpty) ...<Widget>[
                _PendingAttendanceCard(
                  pending: data.today.pendingClasses,
                  onMark: (SchoolClass schoolClass) =>
                      Navigator.of(context).pushNamed(
                    Routes.markAttendance,
                    arguments: MarkAttendanceArgs(classId: schoolClass.id),
                  ),
                ),
                const Gap.xxl(),
              ],
              if (data.today.hasAnyRecords) ...<Widget>[
                _TodayAttendanceCard(today: data.today),
                const Gap.xxl(),
              ],
              // A teacher with no classes still needs somewhere to start. Once
              // they have some, the list used to be repeated here from the
              // Classes tab; the pending-attendance card above already names
              // the classes that actually need something doing today.
              if (data.recentClasses.isEmpty) ...<Widget>[
                EmptyView(
                  compact: true,
                  icon: Icons.class_outlined,
                  title: 'No classes yet',
                  message:
                      'Create your first class to start adding students, taking '
                      'attendance and recording marks.',
                  actionLabel: 'Create a class',
                  onAction: () =>
                      Navigator.of(context).pushNamed(Routes.classForm),
                ),
                const Gap.xxl(),
              ],
              if (data.recentAssessments.isNotEmpty) ...<Widget>[
                SectionHeader(
                  title: 'Recent assessments',
                  actionLabel: 'See all',
                  onAction: () => TeacherShellScope.maybeOf(context)
                      ?.goToTab(TeacherTab.assessments),
                ),
                for (final AssessmentSummary summary in data.recentAssessments)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.md),
                    child: AssessmentTile(
                      summary: summary,
                      showClassName: true,
                      onEnterMarks: () => Navigator.of(context).pushNamed(
                        Routes.assessmentMarks,
                        arguments: AssessmentMarksArgs(assessmentId: summary.id),
                      ),
                      onTap: () => Navigator.of(context).pushNamed(
                        Routes.assessmentMarks,
                        arguments: AssessmentMarksArgs(assessmentId: summary.id),
                      ),
                    ),
                  ),
                const Gap.md(),
              ],
              if (data.recentActivity.isNotEmpty)
                SectionCard(
                  title: 'Recent activity',
                  child: Column(
                    children: <Widget>[
                      for (int i = 0; i < data.recentActivity.length; i++)
                        ActivityTile(
                          log: data.recentActivity[i],
                          isLast: i == data.recentActivity.length - 1,
                        ),
                    ],
                  ),
                ),
              const Gap.xxl(),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.controller});

  final TeacherDashboardController controller;

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = controller.teacher;

    return Row(
      children: <Widget>[
        AppAvatar(name: teacher.displayName, seed: teacher.id, size: 52),
        const SizedBox(width: AppSpacing.lg),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              // The greeting is a quiet kicker; the name below it is what the
              // eye should land on first.
              Text(
                controller.greeting,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.semantic.mutedText),
              ),
              const SizedBox(height: AppSpacing.xxs),
              Text(
                teacher.displayName,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
        const SizedBox(width: AppSpacing.sm),
        IconButton.filledTonal(
          onPressed: () => Navigator.of(context).pushNamed(Routes.notifications),
          icon: Badge(
            isLabelVisible: controller.unreadNotifications > 0,
            label: Text('${controller.unreadNotifications}'),
            child: const Icon(Icons.notifications_none_rounded),
          ),
          tooltip: 'Notifications',
        ),
      ],
    );
  }
}

class _StatsSection extends StatelessWidget {
  const _StatsSection({required this.data});

  final TeacherDashboardData data;

  @override
  Widget build(BuildContext context) {
    return StatGrid(
      tiles: <Widget>[
        StatTile(
          label: 'Total classes',
          value: '${data.totalClasses}',
          icon: Icons.class_rounded,
        ),
        StatTile(
          label: 'Total students',
          value: '${data.totalStudents}',
          icon: Icons.people_alt_rounded,
          accent: context.semantic.info,
        ),
        StatTile(
          label: 'Present today',
          value: '${data.today.summary.attended}',
          icon: Icons.check_circle_rounded,
          accent: context.semantic.success,
          // Kept short: the tile is half a screen wide and the caption is
          // clipped to one line, so "classes marked" would be cut off.
          caption: data.today.classesTotal == 0
              ? null
              : '${data.today.classesMarked}/${data.today.classesTotal} marked',
        ),
        StatTile(
          label: 'Absent today',
          value: '${data.today.summary.absent}',
          icon: Icons.cancel_rounded,
          accent: context.semantic.danger,
          caption: data.overallAttendance.hasData
              ? 'Overall ${Format.percentOrDash(data.overallAttendance.percentage, decimals: 0)}'
              : null,
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({
    required this.data,
    required this.onPickClass,
    required this.onOpenClass,
  });

  final TeacherDashboardData data;
  final Future<void> Function(
    BuildContext context, {
    required String title,
    required List<ClassSummary> classes,
    required void Function(ClassSummary summary) onPicked,
    String emptyMessage,
  }) onPickClass;
  final void Function(BuildContext context, String classId, {int tab}) onOpenClass;

  @override
  Widget build(BuildContext context) {
    final List<ClassSummary> classes = data.recentClasses;

    return QuickActionBar(
      actions: <QuickAction>[
        QuickAction(
          label: 'Create class',
          icon: Icons.add_box_rounded,
          onTap: () => Navigator.of(context).pushNamed(Routes.classForm),
        ),
        QuickAction(
          label: 'Add student',
          icon: Icons.person_add_alt_1_rounded,
          color: context.semantic.info,
          onTap: () => onPickClass(
            context,
            title: 'Add a student to…',
            classes: classes,
            emptyMessage: 'Create a class before adding students.',
            onPicked: (ClassSummary summary) => Navigator.of(context).pushNamed(
              Routes.studentForm,
              arguments: StudentFormArgs(classId: summary.id),
            ),
          ),
        ),
        QuickAction(
          label: 'Mark attendance',
          icon: Icons.how_to_reg_rounded,
          color: context.semantic.success,
          onTap: () => onPickClass(
            context,
            title: 'Take attendance for…',
            classes: classes,
            emptyMessage: 'Create a class before taking attendance.',
            onPicked: (ClassSummary summary) => Navigator.of(context).pushNamed(
              Routes.markAttendance,
              arguments: MarkAttendanceArgs(classId: summary.id),
            ),
          ),
        ),
        QuickAction(
          label: 'Create quiz',
          icon: Icons.quiz_rounded,
          color: context.semantic.warning,
          onTap: () => onPickClass(
            context,
            title: 'Create an assessment in…',
            classes: classes,
            emptyMessage: 'Create a class before adding assessments.',
            onPicked: (ClassSummary summary) => Navigator.of(context).pushNamed(
              Routes.assessmentForm,
              arguments: AssessmentFormArgs(classId: summary.id),
            ),
          ),
        ),
        QuickAction(
          label: 'Add marks',
          icon: Icons.edit_note_rounded,
          color: context.colors.secondary,
          onTap: () {
            final List<AssessmentSummary> pending = data.assessmentsAwaitingMarks;
            if (pending.isEmpty) {
              context.showInfo('Every assessment is fully graded.');
              return;
            }
            Navigator.of(context).pushNamed(
              Routes.assessmentMarks,
              arguments: AssessmentMarksArgs(assessmentId: pending.first.id),
            );
          },
        ),
        QuickAction(
          label: 'Generate report',
          icon: Icons.picture_as_pdf_rounded,
          color: context.semantic.danger,
          onTap: () => Navigator.of(context).pushNamed(Routes.reports),
        ),
      ],
    );
  }
}

class _PendingAttendanceCard extends StatelessWidget {
  const _PendingAttendanceCard({required this.pending, required this.onMark});

  final List<SchoolClass> pending;
  final void Function(SchoolClass schoolClass) onMark;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.semantic.warningContainer,
      borderColor: context.semantic.warning.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.pending_actions_rounded,
                color: context.semantic.warning,
                size: 22,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  'Attendance pending for today',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.semantic.onWarningContainer,
                  ),
                ),
              ),
            ],
          ),
          const Gap.lg(),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              for (final SchoolClass schoolClass in pending)
                ActionChip(
                  avatar: const Icon(Icons.how_to_reg_rounded, size: 18),
                  // A long class name is otherwise squeezed into whatever width
                  // the run has left and clipped mid-word. Capping it keeps the
                  // chip on one line and leaves room for a neighbour.
                  label: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: context.screenWidth * 0.5,
                    ),
                    child: Text(
                      schoolClass.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  onPressed: () => onMark(schoolClass),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard({required this.today});

  final TodayAttendance today;

  @override
  Widget build(BuildContext context) {
    final List<ChartSlice> slices = <ChartSlice>[
      ChartSlice(
        label: 'Present',
        value: today.summary.present.toDouble(),
        color: context.semantic.success,
      ),
      ChartSlice(
        label: 'Absent',
        value: today.summary.absent.toDouble(),
        color: context.semantic.danger,
      ),
      if (today.summary.late > 0)
        ChartSlice(
          label: 'Late',
          value: today.summary.late.toDouble(),
          color: context.semantic.warning,
        ),
      if (today.summary.shortLeave > 0)
        ChartSlice(
          label: 'Short leave',
          value: today.summary.shortLeave.toDouble(),
          color: context.semantic.info,
        ),
    ];

    return SectionCard(
      title: "Today's attendance",
      subtitle:
          '${today.classesMarked} of ${today.classesTotal} classes marked',
      child: DonutChart(
        slices: slices,
        centerValue: Format.percentOrDash(
          today.summary.percentage,
          decimals: 0,
        ),
        centerLabel: 'attended',
      ),
    );
  }
}
