import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/glass.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/student_performance.dart';
import '../../../../domain/services/report_service.dart';
import '../../../state/class_detail_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';
import 'widgets/class_attendance_tab.dart';
import 'widgets/class_students_tab.dart';

/// The class hub: overview header plus students, attendance and assessments.
class ClassDetailScreen extends StatelessWidget {
  const ClassDetailScreen({super.key, required this.args});

  final ClassDetailArgs args;

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<ClassDetailController>(
      create: (BuildContext context) => ClassDetailController(
        context.read<AppDependencies>(),
        teacher,
        args.classId,
      )..load(),
      child: _ClassDetailView(initialTab: args.initialTab),
    );
  }
}

class _ClassDetailView extends StatefulWidget {
  const _ClassDetailView({required this.initialTab});

  final int initialTab;

  @override
  State<_ClassDetailView> createState() => _ClassDetailViewState();
}

class _ClassDetailViewState extends State<_ClassDetailView>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController = TabController(
    length: 2,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 1),
  );

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _generateReport(ClassDetailController controller) async {
    final SchoolClass? schoolClass = controller.schoolClass;
    if (schoolClass == null) return;
    if (controller.studentCount == 0) {
      context.showInfo('Add students before generating a class report.');
      return;
    }

    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser teacher = context.read<SessionController>().requireUser;

    try {
      final GeneratedReport report = await withBlockingProgress(
        context,
        message: 'Building class report…',
        () =>
            deps.reports.classReport(classId: schoolClass.id, teacher: teacher),
      );
      if (!mounted) return;
      Navigator.of(context).pushNamed(
        Routes.reportPreview,
        arguments: ReportPreviewArgs(report: report),
      );
    } catch (_) {
      if (!mounted) return;
      context.showError('Could not generate the report. Please try again.');
    }
  }

  Future<void> _deleteClass(ClassDetailController controller) async {
    final SchoolClass? schoolClass = controller.schoolClass;
    if (schoolClass == null) return;

    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${schoolClass.name}?',
      message:
          'Attendance history, assessments and marks for this class are '
          'deleted permanently. Student records remain in your account.',
      confirmLabel: 'Delete class',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;

    final bool ok = await controller.deleteClass();
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      context.showSuccess('${schoolClass.name} deleted.');
    } else {
      context.showError(
        controller.errorMessage ?? 'Could not delete the class.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClassDetailController controller = context
        .watch<ClassDetailController>();
    final SchoolClass? schoolClass = controller.schoolClass;

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              schoolClass?.name ?? 'Class',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (schoolClass != null && schoolClass.subtitle.isNotEmpty)
              Text(
                schoolClass.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.mutedText,
                ),
              ),
          ],
        ),
        actions: <Widget>[
          IconButton(
            tooltip: 'Class report',
            onPressed: () => _generateReport(controller),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          PopupMenuButton<String>(
            tooltip: 'More',
            onSelected: (String value) {
              switch (value) {
                case 'edit':
                  if (schoolClass != null) {
                    Navigator.of(context).pushNamed(
                      Routes.classForm,
                      arguments: ClassFormArgs(existing: schoolClass),
                    );
                  }
                case 'history':
                  Navigator.of(context).pushNamed(
                    Routes.attendanceHistory,
                    arguments: AttendanceHistoryArgs(
                      classId: controller.classId,
                    ),
                  );
                case 'delete':
                  _deleteClass(controller);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit class'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'history',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history_rounded),
                  title: Text('Attendance history'),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: context.semantic.danger,
                  ),
                  title: Text(
                    'Delete class',
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
        loading: const SkeletonList(itemCount: 5),
        builder: (BuildContext context) => Column(
          children: <Widget>[
            _ClassOverviewHeader(controller: controller),
            Material(
              color: Glass.fill(context),
              child: TabBar(
                controller: _tabController,
                // Marks live on their own tab in the bottom bar, where a
                // teacher can see every class at once and create an
                // assessment. Repeating them here was a second way into the
                // same screens rather than anything this page adds.
                tabs: <Widget>[
                  Tab(text: 'Students (${controller.studentCount})'),
                  Tab(text: 'Attendance (${controller.sessions.length})'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const <Widget>[
                  ClassStudentsTab(),
                  ClassAttendanceTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClassOverviewHeader extends StatelessWidget {
  const _ClassOverviewHeader({required this.controller});

  final ClassDetailController controller;

  @override
  Widget build(BuildContext context) {
    final ClassPerformance? performance = controller.performance;
    final List<StudentPerformance> atRisk = controller.atRiskStudents;

    return Container(
      color: Glass.fill(context),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: ContentWidth(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: _MiniStat(
                    label: 'Students',
                    value: '${controller.studentCount}',
                    icon: Icons.people_alt_rounded,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Attendance',
                    value: Format.percentOrDash(
                      performance?.averageAttendance,
                      decimals: 0,
                    ),
                    icon: Icons.event_available_rounded,
                    color: context.semantic.success,
                  ),
                ),
                Expanded(
                  child: _MiniStat(
                    label: 'Sessions',
                    value: '${performance?.sessionCount ?? 0}',
                    icon: Icons.history_rounded,
                    color: context.semantic.warning,
                  ),
                ),
              ],
            ),
            if (atRisk.isNotEmpty) ...<Widget>[
              const Gap.md(),
              AppCard(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                color: context.semantic.warningContainer,
                borderColor: context.semantic.warning.withValues(alpha: 0.35),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.warning_amber_rounded,
                      size: 18,
                      color: context.semantic.warning,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        '${Format.plural(atRisk.length, 'student')} need attention '
                        '(low attendance or marks).',
                        style: context.text.bodySmall?.copyWith(
                          color: context.semantic.onWarningContainer,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () =>
                          controller.setFilter(StudentFilter.atRisk),
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                        ),
                        minimumSize: Size.zero,
                        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                      ),
                      child: const Text('View'),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Icon(icon, size: 18, color: color ?? context.colors.primary),
        const SizedBox(height: AppSpacing.xs),
        Text(
          value,
          style: context.text.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          label,
          textAlign: TextAlign.center,
          style: context.text.labelSmall?.copyWith(
            color: context.semantic.mutedText,
          ),
        ),
      ],
    );
  }
}

/// Shown in the roster when the class has no students yet.
class ClassRosterEmptyState extends StatelessWidget {
  const ClassRosterEmptyState({
    super.key,
    required this.onAddStudent,
    required this.onEnrollExisting,
  });

  final VoidCallback onAddStudent;
  final VoidCallback onEnrollExisting;

  @override
  Widget build(BuildContext context) {
    return EmptyView(
      icon: Icons.people_outline_rounded,
      title: 'No students yet',
      message: 'Add students to start taking attendance and recording marks.',
      actionLabel: 'Add a student',
      onAction: onAddStudent,
      secondaryActionLabel: 'Enroll an existing student',
      onSecondaryAction: onEnrollExisting,
    );
  }
}
