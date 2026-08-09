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
import '../../../state/assessment_list_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/domain/assessment_tile.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Assessments across every class, with a filter for ungraded work.
class AssessmentsTab extends StatelessWidget {
  const AssessmentsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<AssessmentListController>(
      create: (BuildContext context) =>
          AssessmentListController(context.read<AppDependencies>(), teacher)
            ..load(),
      child: const _AssessmentsView(),
    );
  }
}

class _AssessmentsView extends StatelessWidget {
  const _AssessmentsView();

  Future<void> _createAssessment(
    BuildContext context,
    AssessmentListController controller,
  ) async {
    if (controller.classes.isEmpty) {
      context.showInfo('Create a class before adding assessments.');
      return;
    }
    final SchoolClass? target = controller.classes.length == 1
        ? controller.classes.first
        : await showAppSheet<SchoolClass>(
            context,
            builder: (BuildContext sheetContext) => AppSheet(
              title: 'Which class?',
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  for (final SchoolClass schoolClass in controller.classes)
                    ListTile(
                      leading: const Icon(Icons.class_outlined),
                      title: Text(schoolClass.name),
                      subtitle: schoolClass.subtitle.isEmpty
                          ? null
                          : Text(schoolClass.subtitle),
                      onTap: () =>
                          Navigator.of(sheetContext).pop(schoolClass),
                    ),
                ],
              ),
            ),
          );

    if (target == null || !context.mounted) return;
    Navigator.of(context).pushNamed(
      Routes.assessmentForm,
      arguments: AssessmentFormArgs(classId: target.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AssessmentListController controller =
        context.watch<AssessmentListController>();
    final List<AssessmentSummary> visible = controller.visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Assessments'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Reports',
            onPressed: () => Navigator.of(context).pushNamed(Routes.reports),
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'fab-assessments',
        onPressed: () => _createAssessment(context, controller),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New assessment'),
      ),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: ContentWidth(
                child: SearchField(
                  hintText: 'Search assessments',
                  initialValue: controller.query,
                  onChanged: controller.search,
                ),
              ),
            ),
            if (controller.classes.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
                child: ContentWidth(
                  child: SizedBox(
                    height: 40,
                    child: ListView(
                      scrollDirection: Axis.horizontal,
                      children: <Widget>[
                        FilterChip(
                          label: Text('Needs marks (${controller.pendingCount})'),
                          selected: controller.pendingOnly,
                          onSelected: controller.setPendingOnly,
                          avatar: const Icon(Icons.edit_note_rounded, size: 16),
                        ),
                        const SizedBox(width: AppSpacing.sm),
                        ChoiceChip(
                          label: const Text('All classes'),
                          selected: controller.classFilter == null,
                          showCheckmark: false,
                          onSelected: (_) => controller.setClassFilter(null),
                        ),
                        for (final SchoolClass schoolClass in controller.classes)
                          Padding(
                            padding: const EdgeInsets.only(left: AppSpacing.sm),
                            child: ChoiceChip(
                              label: Text(schoolClass.name),
                              selected: controller.classFilter == schoolClass.id,
                              showCheckmark: false,
                              onSelected: (_) =>
                                  controller.setClassFilter(schoolClass.id),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 4, itemHeight: 140),
                empty: EmptyView(
                  icon: Icons.assignment_outlined,
                  title: 'No assessments yet',
                  message:
                      'Create quizzes, assignments and exams. Marks you enter '
                      'are graded automatically using your grading scale.',
                  actionLabel: 'Create an assessment',
                  onAction: () => _createAssessment(context, controller),
                ),
                builder: (BuildContext context) {
                  if (visible.isEmpty) {
                    return EmptyView(
                      icon: Icons.filter_alt_off_outlined,
                      title: 'No assessments match',
                      message: 'Adjust the search or filters to see more.',
                      actionLabel: 'Clear filters',
                      onAction: controller.clearFilters,
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ContentWidth(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          AppSpacing.md,
                          AppSpacing.lg,
                          AppSpacing.fabClearance,
                        ),
                        itemCount: visible.length + 1,
                        separatorBuilder: (_, __) => const Gap.md(),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == visible.length) {
                            return _GradingSummary(controller: controller);
                          }
                          final AssessmentSummary summary = visible[index];
                          return AssessmentTile(
                            summary: summary,
                            showClassName: true,
                            onTap: () => Navigator.of(context).pushNamed(
                              Routes.assessmentMarks,
                              arguments: AssessmentMarksArgs(
                                assessmentId: summary.id,
                              ),
                            ),
                            onEnterMarks: () => Navigator.of(context).pushNamed(
                              Routes.assessmentMarks,
                              arguments: AssessmentMarksArgs(
                                assessmentId: summary.id,
                              ),
                            ),
                            trailing: IconButton(
                              tooltip: 'Open class',
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                              ),
                              onPressed: () => Navigator.of(context).pushNamed(
                                Routes.classDetail,
                                arguments: ClassDetailArgs(
                                  classId: summary.assessment.classId,
                                  initialTab: 2,
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _GradingSummary extends StatelessWidget {
  const _GradingSummary({required this.controller});

  final AssessmentListController controller;

  @override
  Widget build(BuildContext context) {
    final int pending = controller.pendingCount;

    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: AppCard(
        color: pending == 0
            ? context.semantic.successContainer
            : context.colors.surfaceContainerHigh,
        borderColor: pending == 0
            ? context.semantic.success.withValues(alpha: 0.3)
            : null,
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        child: Row(
          children: <Widget>[
            Icon(
              pending == 0
                  ? Icons.check_circle_outline_rounded
                  : Icons.pending_actions_rounded,
              size: 18,
              color: pending == 0
                  ? context.semantic.success
                  : context.semantic.mutedText,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                pending == 0
                    ? 'Every assessment is fully graded.'
                    : '${Format.plural(pending, 'assessment')} still need marks.',
                style: context.text.bodySmall?.copyWith(
                  color: pending == 0
                      ? context.semantic.onSuccessContainer
                      : context.semantic.mutedText,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
