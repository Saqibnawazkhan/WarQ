import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/session_controller.dart';
import '../../../state/teacher_dashboard_controller.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/quick_action.dart';
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

  void _markAttendance(BuildContext context, ClassSummary summary) {
    Navigator.of(context).pushNamed(
      Routes.markAttendance,
      arguments: MarkAttendanceArgs(classId: summary.id),
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

    // A class with nobody in it cannot have a register taken, so it is not an
    // outstanding task — the same rule the today figures are counted by.
    final List<ClassSummary> todayClasses = data.recentClasses
        .where((ClassSummary summary) => summary.studentCount > 0)
        .toList(growable: false);

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
              _StatsRow(data: data),
              const Gap.xxl(),
              if (todayClasses.isNotEmpty) ...<Widget>[
                _TodayAttendanceCard(
                  today: data.today,
                  classes: todayClasses,
                  onMark: (ClassSummary summary) =>
                      _markAttendance(context, summary),
                ),
                const Gap.xxl(),
              ],
              const SectionHeader(title: 'Quick actions'),
              _QuickActions(data: data, onPickClass: _pickClassThen),
              const Gap.xxl(),
              // A teacher with no classes still needs somewhere to start. Once
              // they have some, the Classes and Attendance tabs own the lists —
              // Home is the summary, not a second copy of them.
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
    // A greeting uses the name someone is called by. The surname adds nothing
    // here and would be the first thing ellipsised on a narrow phone.
    final String firstName =
        teacher.displayName.split(RegExp(r'\s+')).first;
    final DateTime now = DateTime.now();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          '${AppDate.formatWeekday(now)} · ${AppDate.format(now)}'.toUpperCase(),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium?.copyWith(
            color: context.semantic.mutedText,
            // Capitals set solid read as a block; the extra tracking is what
            // makes a line this short scannable rather than dense.
            letterSpacing: 0.9,
          ),
        ),
        const Gap.sm(),
        Row(
          children: <Widget>[
            Expanded(
              child: Text(
                '${controller.greeting}, $firstName',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.headlineSmall,
              ),
            ),
            const SizedBox(width: AppSpacing.sm),
            IconButton.filledTonal(
              onPressed: () =>
                  Navigator.of(context).pushNamed(Routes.notifications),
              icon: Badge(
                isLabelVisible: controller.unreadNotifications > 0,
                label: Text('${controller.unreadNotifications}'),
                child: const Icon(Icons.notifications_none_rounded),
              ),
              tooltip: 'Notifications',
            ),
          ],
        ),
      ],
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.data});

  final TeacherDashboardData data;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      // Three across, so the cards are measured against each other and a
      // two-line caption does not leave its neighbours short.
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _StatCard(
              value: '${data.totalClasses}',
              label: 'Classes',
              filled: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              value: '${data.totalStudents}',
              label: 'Students',
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              value: '${data.today.summary.attended}',
              label: 'Present today',
            ),
          ),
        ],
      ),
    );
  }
}

/// A figure over its caption. The first card of the row is filled with the
/// brand colour, which is what makes a row of three read as one group with a
/// starting point rather than three equal boxes.
class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.label,
    this.filled = false,
  });

  final String value;
  final String label;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        filled ? context.colors.onPrimary : context.colors.onSurface;

    return AppCard(
      // Tight at the sides: a three-up row leaves a card about 100pt wide on a
      // phone, and every point spent on the gutter is a point the figure has to
      // shrink by.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      color: filled ? context.colors.primary : null,
      // The filled card shows no edge, but it still needs one: dropping the
      // border would leave it a hairline shorter than the two beside it.
      borderColor: filled ? context.colors.primary : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          // Shrinking an unusually large roll beats ellipsising it, because a
          // truncated figure reads as a wrong one.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: context.text.headlineMedium
                  ?.copyWith(color: foreground, height: 1.1),
            ),
          ),
          const Gap.xs(),
          Text(
            label,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: filled
                  ? foreground.withValues(alpha: 0.88)
                  : context.semantic.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// Today's register, class by class: what is done and what is still owed.
class _TodayAttendanceCard extends StatelessWidget {
  const _TodayAttendanceCard({
    required this.today,
    required this.classes,
    required this.onMark,
  });

  final TodayAttendance today;
  final List<ClassSummary> classes;
  final void Function(ClassSummary summary) onMark;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: "Today's attendance",
      subtitle:
          '${today.classesMarked} of ${today.classesTotal} classes marked',
      child: Column(
        children: <Widget>[
          for (int i = 0; i < classes.length; i++) ...<Widget>[
            if (i > 0) const Gap.lg(),
            _TodayClassRow(
              summary: classes[i],
              onMark: () => onMark(classes[i]),
            ),
          ],
        ],
      ),
    );
  }
}

class _TodayClassRow extends StatelessWidget {
  const _TodayClassRow({required this.summary, required this.onMark});

  final ClassSummary summary;
  final VoidCallback onMark;

  @override
  Widget build(BuildContext context) {
    final String? section = summary.schoolClass.section;
    final String detail = <String>[
      if (section != null) 'Section $section',
      Format.plural(summary.studentCount, 'student'),
    ].join(' · ');

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          // The colour the class already carries on the Classes tab, so the
          // right row is found by colour before the name is read.
          Container(
            width: AppSpacing.xs,
            decoration: BoxDecoration(
              color: AppColors.classColors(summary.schoolClass.colorSeed).first,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Text(
                  summary.name,
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
          const SizedBox(width: AppSpacing.md),
          // Centred, not stretched: the row's height is set by the class name
          // and its detail line, and a button pulled to that height would read
          // as a second card.
          Center(
            child: summary.markedToday
                ? const _MarkedFlag()
                : FilledButton(
                    onPressed: onMark,
                    style: FilledButton.styleFrom(
                      // A row action, not a form's submit button, so it drops
                      // the full-width button height the theme sets.
                      minimumSize: const Size(0, 40),
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.lg,
                      ),
                      textStyle: context.text.labelLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    child: const Text('Mark'),
                  ),
          ),
        ],
      ),
    );
  }
}

class _MarkedFlag extends StatelessWidget {
  const _MarkedFlag();

  @override
  Widget build(BuildContext context) {
    final Color color = context.semantic.success;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.check_circle_rounded, size: 20, color: color),
        const SizedBox(width: AppSpacing.xs),
        Text(
          'Marked',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium
              ?.copyWith(color: color, fontWeight: FontWeight.w700),
        ),
      ],
    );
  }
}

class _QuickActions extends StatelessWidget {
  const _QuickActions({required this.data, required this.onPickClass});

  final TeacherDashboardData data;
  final Future<void> Function(
    BuildContext context, {
    required String title,
    required List<ClassSummary> classes,
    required void Function(ClassSummary summary) onPicked,
    String emptyMessage,
  }) onPickClass;

  @override
  Widget build(BuildContext context) {
    final List<ClassSummary> classes = data.recentClasses;

    return _QuickActionGrid(
      actions: <QuickAction>[
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
          label: 'New assessment',
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
          label: 'Class report',
          icon: Icons.picture_as_pdf_rounded,
          color: context.semantic.danger,
          onTap: () => Navigator.of(context).pushNamed(Routes.reports),
        ),
      ],
    );
  }
}

/// The shortcuts as a grid rather than a scrolling strip, so all four are on
/// screen at once instead of the last one being discovered by swiping.
class _QuickActionGrid extends StatelessWidget {
  const _QuickActionGrid({required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (int i = 0; i < actions.length; i += 2) ...<Widget>[
          if (i > 0) const Gap.md(),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Expanded(child: _QuickActionCard(action: actions[i])),
                const SizedBox(width: AppSpacing.md),
                // An odd action count leaves a gap rather than stretching the
                // last card across a whole row.
                if (i + 1 < actions.length)
                  Expanded(child: _QuickActionCard(action: actions[i + 1]))
                else
                  const Spacer(),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _QuickActionCard extends StatelessWidget {
  const _QuickActionCard({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final Color color = action.color ?? context.colors.primary;

    return Opacity(
      opacity: action.enabled ? 1 : 0.45,
      child: Material(
        color: context.colors.surface,
        borderRadius: AppRadii.cardRadius,
        child: InkWell(
          onTap: action.enabled ? action.onTap : null,
          borderRadius: AppRadii.cardRadius,
          child: Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              borderRadius: AppRadii.cardRadius,
              border: Border.all(color: context.semantic.subtleBorder),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(action.icon, size: 22, color: color),
                ),
                const Gap.md(),
                // Two lines, because half a phone width does not hold "Mark
                // attendance" on one at this type scale. Flexible so a longer
                // label than any of these four ellipsises rather than pushing
                // the column past the height the row was measured for.
                Flexible(
                  child: Text(
                    action.label,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
