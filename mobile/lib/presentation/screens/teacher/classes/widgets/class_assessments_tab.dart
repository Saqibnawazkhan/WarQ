import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/routing/route_args.dart';
import '../../../../../core/routing/route_names.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../domain/entities/dashboard_data.dart';
import '../../../../../domain/entities/student_performance.dart';
import '../../../../state/class_detail_controller.dart';
import '../../../../widgets/charts/bar_chart.dart';
import '../../../../widgets/charts/chart_data.dart';
import '../../../../widgets/common/app_card.dart';
import '../../../../widgets/domain/assessment_tile.dart';
import '../../../../widgets/feedback/dialogs.dart';
import '../../../../widgets/feedback/state_views.dart';
import '../../../../widgets/layout/app_page.dart';

/// Assessments tab: create quizzes and exams, enter marks, see the grade mix.
class ClassAssessmentsTab extends StatelessWidget {
  const ClassAssessmentsTab({super.key});

  Future<void> _showActions(
    BuildContext context,
    ClassDetailController controller,
    AssessmentSummary summary,
  ) async {
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: summary.assessment.name,
        subtitle:
            '${summary.assessment.typeLabel} · '
            '${Format.marks(summary.assessment.totalMarks)} marks',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_note_rounded),
              title: const Text('Enter or edit marks'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed(
                  Routes.assessmentMarks,
                  arguments: AssessmentMarksArgs(assessmentId: summary.id),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit assessment'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed(
                  Routes.assessmentForm,
                  arguments: AssessmentFormArgs(
                    classId: controller.classId,
                    existing: summary.assessment,
                  ),
                );
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: sheetContext.semantic.danger,
              ),
              title: Text(
                'Delete assessment',
                style: TextStyle(color: sheetContext.semantic.danger),
              ),
              subtitle: const Text('Removes all marks recorded for it'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete ${summary.assessment.name}?',
                  message:
                      'Every mark recorded against this assessment is deleted '
                      'and student percentages are recalculated.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                  icon: Icons.delete_outline_rounded,
                );
                if (!confirmed || !context.mounted) return;
                final bool ok = await controller.deleteAssessment(summary.id);
                if (!context.mounted) return;
                if (ok) {
                  context.showSuccess('${summary.assessment.name} deleted.');
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClassDetailController controller = context
        .watch<ClassDetailController>();
    final List<AssessmentSummary> assessments = controller.assessments;
    final ClassPerformance? performance = controller.performance;

    void createAssessment() => Navigator.of(context).pushNamed(
      Routes.assessmentForm,
      arguments: AssessmentFormArgs(classId: controller.classId),
    );

    return Scaffold(
      // Transparent so the app's gradient shows through: this is a tab inside
      // another Scaffold, not a page of its own.
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-assessment',
        onPressed: createAssessment,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New assessment'),
      ),
      body: assessments.isEmpty
          ? EmptyView(
              icon: Icons.assignment_outlined,
              title: 'No assessments yet',
              message:
                  'Create a quiz, assignment or exam, then enter marks for each '
                  'student. Grades and percentages are calculated automatically.',
              actionLabel: 'Create an assessment',
              onAction: createAssessment,
            )
          : RefreshIndicator(
              onRefresh: controller.refresh,
              child: ContentWidth(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.lg,
                    AppSpacing.fabClearance,
                  ),
                  children: <Widget>[
                    if (performance != null &&
                        performance.gradeDistribution.values.any(
                          (int count) => count > 0,
                        )) ...<Widget>[
                      SectionCard(
                        title: 'Grade distribution',
                        subtitle: 'Based on total marks across all assessments',
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
                      const Gap.xl(),
                    ],
                    for (final AssessmentSummary summary in assessments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: AppSpacing.md),
                        child: AssessmentTile(
                          summary: summary,
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
                            tooltip: 'Assessment options',
                            icon: const Icon(Icons.more_vert_rounded, size: 20),
                            onPressed: () =>
                                _showActions(context, controller, summary),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
    );
  }
}
