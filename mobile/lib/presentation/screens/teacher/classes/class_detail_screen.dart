import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
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
import 'widgets/class_assessments_tab.dart';
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
    length: 3,
    vsync: this,
    initialIndex: widget.initialTab.clamp(0, 2),
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
        () => deps.reports.classReport(
          classId: schoolClass.id,
          teacher: teacher,
        ),
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
      message: 'Attendance history, assessments and marks for this class are '
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
      context.showError(controller.errorMessage ?? 'Could not delete the class.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final ClassDetailController controller =
        context.watch<ClassDetailController>();
    final SchoolClass? schoolClass = controller.schoolClass;

    return Scaffold(
      // The class name belongs to the page, not the bar above it, so the bar
      // is left holding only the way back and the actions.
      appBar: AppBar(
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
                    arguments:
                        AttendanceHistoryArgs(classId: controller.classId),
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
            _ClassHeader(controller: controller),
            Material(
              color: context.semantic.canvas,
              child: TabBar(
                controller: _tabController,
                // Three labels at this type scale do not fit a phone's width
                // when the row is divided equally, and a fixed tab bar fades
                // the text it cannot fit. Scrolling keeps every label whole,
                // including when the system font size is turned up.
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                tabs: const <Widget>[
                  Tab(text: 'Students'),
                  Tab(text: 'Attendance'),
                  Tab(text: 'Assessments'),
                ],
              ),
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: const <Widget>[
                  ClassStudentsTab(),
                  ClassAttendanceTab(),
                  ClassAssessmentsTab(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The page's own heading: the way back, the class name, and the one line that
/// describes the class.
class _ClassHeader extends StatelessWidget {
  const _ClassHeader({required this.controller});

  final ClassDetailController controller;

  @override
  Widget build(BuildContext context) {
    final SchoolClass? schoolClass = controller.schoolClass;
    final List<StudentPerformance> atRisk = controller.atRiskStudents;

    // Spelled out here rather than taken from SchoolClass.subtitle. That getter
    // is the compact form for dropdowns and report headers, where a bare year
    // is unambiguous; on this line it would sit between a section and a head
    // count as one more number to work out.
    final String? subject = schoolClass?.subject;
    final String summary = <String>[
      if (schoolClass != null) ...<String>[
        if (subject != null && subject != schoolClass.name) subject,
        if (schoolClass.section != null) 'Section ${schoolClass.section}',
        if (schoolClass.session != null) 'Session ${schoolClass.session}',
      ],
      Format.plural(controller.studentCount, 'student'),
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.lg,
      ),
      child: ContentWidth(
        fillHeight: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            // Names the destination rather than leaving an arrow to interpret,
            // which matters most on the tab a teacher lands on from a link.
            TextButton.icon(
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.chevron_left_rounded, size: 20),
              label: const Text('Classes'),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
              ),
            ),
            const Gap.xs(),
            Text(
              schoolClass?.name ?? 'Class',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.headlineSmall,
            ),
            const Gap.xs(),
            Text(
              summary,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.semantic.mutedText),
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

