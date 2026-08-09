import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/route_args.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../domain/services/report_service.dart';
import '../../state/reports_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/search_field.dart';
import '../../widgets/domain/student_tile.dart';
import '../../widgets/feedback/dialogs.dart';
import '../../widgets/feedback/state_views.dart';
import '../../widgets/layout/app_page.dart';

/// Reports hub: generate a full class report or an individual student report.
class ReportsScreen extends StatelessWidget {
  const ReportsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<ReportsController>(
      create: (BuildContext context) =>
          ReportsController(context.read<AppDependencies>(), teacher)..load(),
      child: const _ReportsView(),
    );
  }
}

class _ReportsView extends StatelessWidget {
  const _ReportsView();

  Future<void> _open(BuildContext context, GeneratedReport? report) async {
    if (report == null || !context.mounted) return;
    await Navigator.of(context).pushNamed(
      Routes.reportPreview,
      arguments: ReportPreviewArgs(report: report),
    );
  }

  Future<void> _generateClassReport(
    BuildContext context,
    ReportsController controller,
  ) async {
    final GeneratedReport? report = await withBlockingProgress(
      context,
      message: 'Building class report…',
      () => controller.generateClassReport(),
    );
    if (!context.mounted) return;
    if (report == null) {
      context.showError(
        controller.errorMessage ?? 'Could not generate the class report.',
      );
      return;
    }
    await _open(context, report);
  }

  Future<void> _generateStudentReport(
    BuildContext context,
    ReportsController controller,
    Student student,
  ) async {
    final GeneratedReport? report = await withBlockingProgress(
      context,
      message: 'Building report for ${student.fullName}…',
      () => controller.generateStudentReport(student.id),
    );
    if (!context.mounted) return;
    if (report == null) {
      context.showError(
        controller.errorMessage ?? 'Could not generate the report.',
      );
      return;
    }
    await _open(context, report);
  }

  @override
  Widget build(BuildContext context) {
    final ReportsController controller = context.watch<ReportsController>();
    final SchoolClass? selected = controller.selectedClass;

    return Scaffold(
      appBar: AppBar(title: const Text('Reports')),
      body: SafeArea(
        child: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 4),
          empty: EmptyView(
            icon: Icons.picture_as_pdf_outlined,
            title: 'Nothing to report yet',
            message:
                'Create a class and add students — then you can generate class '
                'and individual PDF reports.',
            actionLabel: 'Create a class',
            onAction: () => Navigator.of(context).pushNamed(Routes.classForm),
          ),
          builder: (BuildContext context) => AppPageBody(
            onRefresh: controller.refresh,
            children: <Widget>[
              SectionCard(
                title: 'Choose a class',
                subtitle: 'Reports are generated per class',
                child: DropdownButtonFormField<String>(
                  initialValue: controller.selectedClassId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    prefixIcon: Icon(Icons.class_outlined),
                  ),
                  items: <DropdownMenuItem<String>>[
                    for (final SchoolClass schoolClass in controller.classes)
                      DropdownMenuItem<String>(
                        value: schoolClass.id,
                        child: Text(
                          schoolClass.displayName,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                  ],
                  onChanged: (String? value) {
                    if (value != null) controller.selectClass(value);
                  },
                ),
              ),
              const Gap.xl(),
              _ReportOptionCard(
                icon: Icons.groups_rounded,
                title: 'Complete class report',
                description:
                    'Class information, teacher, student list, attendance '
                    'summary, marks, grades and performance.',
                buttonLabel: 'Generate class report',
                enabled: selected != null && controller.roster.isNotEmpty,
                disabledHint: controller.roster.isEmpty
                    ? 'Add students to this class first.'
                    : null,
                onPressed: () => _generateClassReport(context, controller),
              ),
              const Gap.xl(),
              SectionHeader(
                title: 'Individual student report',
                subtitle: selected == null
                    ? null
                    : '${Format.plural(controller.roster.length, 'student')} in '
                        '${selected.name}',
              ),
              if (controller.roster.isEmpty)
                const EmptyView(
                  compact: true,
                  icon: Icons.person_outline_rounded,
                  title: 'No students',
                  message: 'This class has no students to report on yet.',
                )
              else ...<Widget>[
                SearchField(
                  hintText: 'Find a student',
                  onChanged: controller.searchStudents,
                ),
                const Gap.md(),
                for (final Student student in controller.visibleStudents)
                  StudentPickerTile(
                    student: student,
                    subtitle: student.rollNumber ?? 'No roll number',
                    trailing: IconButton(
                      tooltip: 'Generate report',
                      icon: const Icon(Icons.picture_as_pdf_outlined),
                      onPressed: () =>
                          _generateStudentReport(context, controller, student),
                    ),
                    onTap: () =>
                        _generateStudentReport(context, controller, student),
                  ),
              ],
              const Gap.xxl(),
              const _ReportHelpCard(),
              const Gap.xxl(),
            ],
          ),
        ),
      ),
    );
  }
}

class _ReportOptionCard extends StatelessWidget {
  const _ReportOptionCard({
    required this.icon,
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onPressed,
    this.enabled = true,
    this.disabledHint,
  });

  final IconData icon;
  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onPressed;
  final bool enabled;
  final String? disabledHint;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadii.sm),
                ),
                child: Icon(icon, color: context.colors.primary),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Text(
                  title,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const Gap.md(),
          Text(
            description,
            style: context.text.bodySmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
          if (!enabled && disabledHint != null) ...<Widget>[
            const Gap.sm(),
            Text(
              disabledHint!,
              style: context.text.labelSmall
                  ?.copyWith(color: context.semantic.warning),
            ),
          ],
          const Gap.lg(),
          FilledButton.icon(
            onPressed: enabled ? onPressed : null,
            icon: const Icon(Icons.picture_as_pdf_rounded, size: 20),
            label: Text(buttonLabel),
          ),
        ],
      ),
    );
  }
}

class _ReportHelpCard extends StatelessWidget {
  const _ReportHelpCard();

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.colors.surfaceContainerHigh,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.lightbulb_outline_rounded,
                size: 18,
                color: context.semantic.mutedText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'About reports',
                style: context.text.labelLarge
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ],
          ),
          const Gap.sm(),
          Text(
            'Every report can be previewed, printed, saved to this device or '
            'shared using the system share sheet. Assessments without marks are '
            'excluded from percentage calculations so the totals stay accurate.',
            style: context.text.bodySmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
        ],
      ),
    );
  }
}
