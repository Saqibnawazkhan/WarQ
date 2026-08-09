import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/routing/route_args.dart';
import '../../../../../core/routing/route_names.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../data/models/models.dart';
import '../../../../../domain/entities/student_performance.dart';
import '../../../../state/class_detail_controller.dart';
import '../../../../widgets/common/search_field.dart';
import '../../../../widgets/domain/student_tile.dart';
import '../../../../widgets/feedback/dialogs.dart';
import '../../../../widgets/feedback/state_views.dart';
import '../../../../widgets/layout/app_page.dart';
import '../class_detail_screen.dart';

/// Roster tab: A–Z student list with search, sort and quick filters.
class ClassStudentsTab extends StatelessWidget {
  const ClassStudentsTab({super.key});

  void _openStudent(BuildContext context, ClassDetailController controller,
      StudentPerformance performance) {
    Navigator.of(context).pushNamed(
      Routes.studentDetail,
      arguments: StudentDetailArgs(
        studentId: performance.student.id,
        classId: controller.classId,
      ),
    );
  }

  Future<void> _showStudentActions(
    BuildContext context,
    ClassDetailController controller,
    StudentPerformance performance,
  ) async {
    final Student student = performance.student;
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: student.fullName,
        subtitle: student.rollNumber ?? 'No roll number',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.insights_outlined),
              title: const Text('View performance'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _openStudent(context, controller, performance);
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit student'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed(
                  Routes.studentForm,
                  arguments: StudentFormArgs(
                    classId: controller.classId,
                    existing: student,
                  ),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.person_remove_outlined),
              title: const Text('Remove from this class'),
              subtitle: const Text('Keeps the student record and history'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool confirmed = await showConfirmDialog(
                  context,
                  title: 'Remove ${student.fullName}?',
                  message:
                      'They will no longer appear in this class. Their record '
                      'and past results are preserved.',
                  confirmLabel: 'Remove',
                  isDestructive: true,
                  icon: Icons.person_remove_outlined,
                );
                if (!confirmed || !context.mounted) return;
                final bool ok = await controller.removeFromClass(student.id);
                if (!context.mounted) return;
                if (ok) {
                  context.showSuccess('${student.fullName} removed from the class.');
                }
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.delete_outline_rounded,
                color: sheetContext.semantic.danger,
              ),
              title: Text(
                'Delete student',
                style: TextStyle(color: sheetContext.semantic.danger),
              ),
              subtitle: const Text('Deletes their attendance and marks too'),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool confirmed = await showConfirmDialog(
                  context,
                  title: 'Delete ${student.fullName}?',
                  message:
                      'This permanently deletes the student along with their '
                      'attendance records and marks in every class.',
                  confirmLabel: 'Delete',
                  isDestructive: true,
                  icon: Icons.delete_outline_rounded,
                );
                if (!confirmed || !context.mounted) return;
                final bool ok = await controller.deleteStudent(student.id);
                if (!context.mounted) return;
                if (ok) context.showSuccess('${student.fullName} deleted.');
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showSortSheet(
    BuildContext context,
    ClassDetailController controller,
  ) async {
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Sort students',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final StudentSort sort in StudentSort.values)
              ListTile(
                title: Text(sort.label),
                trailing: controller.sort == sort
                    ? Icon(
                        Icons.check_rounded,
                        color: sheetContext.colors.primary,
                      )
                    : null,
                onTap: () {
                  controller.setSort(sort);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClassDetailController controller =
        context.watch<ClassDetailController>();
    final List<StudentPerformance> students = controller.visibleStudents;
    final GradeScale? scale = controller.gradeScale;

    void addStudent() => Navigator.of(context).pushNamed(
          Routes.studentForm,
          arguments: StudentFormArgs(classId: controller.classId),
        );

    void enrollExisting() => Navigator.of(context).pushNamed(
          Routes.enrollExisting,
          arguments: EnrollStudentsArgs(
            classId: controller.classId,
            className: controller.schoolClass?.name ?? 'this class',
          ),
        );

    return Scaffold(
      backgroundColor: context.semantic.canvas,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'add-student',
        onPressed: addStudent,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add student'),
      ),
      body: Column(
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(
              AppSpacing.lg,
              AppSpacing.md,
              AppSpacing.lg,
              AppSpacing.sm,
            ),
            child: ContentWidth(
              child: SearchField(
                hintText: 'Search by name, roll number or phone',
                initialValue: controller.query,
                onChanged: controller.search,
                trailing: IconButton(
                  tooltip: 'Sort',
                  icon: const Icon(Icons.sort_rounded, size: 20),
                  onPressed: () => _showSortSheet(context, controller),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            child: ContentWidth(
              child: FilterChipsRow<StudentFilter>(
                values: StudentFilter.values,
                selected: controller.filter,
                labelOf: (StudentFilter f) => f.label,
                onSelected: controller.setFilter,
              ),
            ),
          ),
          Expanded(
            child: controller.allStudents.isEmpty
                ? ClassRosterEmptyState(
                    onAddStudent: addStudent,
                    onEnrollExisting: enrollExisting,
                  )
                : students.isEmpty
                    ? EmptyView(
                        icon: Icons.filter_alt_off_outlined,
                        title: 'No students match',
                        message: 'Adjust the search or filter to see students.',
                        actionLabel: 'Clear filters',
                        onAction: controller.clearFilters,
                      )
                    : RefreshIndicator(
                        onRefresh: controller.refresh,
                        child: ContentWidth(
                          child: _RosterList(
                            controller: controller,
                            students: students,
                            scale: scale,
                            onOpen: (StudentPerformance p) =>
                                _openStudent(context, controller, p),
                            onActions: (StudentPerformance p) =>
                                _showStudentActions(context, controller, p),
                            onEnrollExisting: enrollExisting,
                          ),
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

class _RosterList extends StatelessWidget {
  const _RosterList({
    required this.controller,
    required this.students,
    required this.scale,
    required this.onOpen,
    required this.onActions,
    required this.onEnrollExisting,
  });

  final ClassDetailController controller;
  final List<StudentPerformance> students;
  final GradeScale? scale;
  final void Function(StudentPerformance performance) onOpen;
  final void Function(StudentPerformance performance) onActions;
  final VoidCallback onEnrollExisting;

  @override
  Widget build(BuildContext context) {
    // With the default A–Z sort we insert letter headers; any other sort
    // renders a plain list because the headers would be meaningless.
    final bool grouped = controller.showSectionHeaders;

    final List<Widget> items = <Widget>[];
    if (grouped) {
      final Map<String, List<StudentPerformance>> sections =
          controller.groupedStudents;
      sections.forEach((String letter, List<StudentPerformance> group) {
        items.add(AlphabetHeader(letter: letter, count: group.length));
        for (final StudentPerformance performance in group) {
          items.add(
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: StudentTile(
                performance: performance,
                onTap: () => onOpen(performance),
                onLongPress: () => onActions(performance),
                trailing: _TrailingActions(
                  performance: performance,
                  onActions: onActions,
                ),
              ),
            ),
          );
        }
      });
    } else {
      for (final StudentPerformance performance in students) {
        items.add(
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.sm),
            child: StudentTile(
              performance: performance,
              onTap: () => onOpen(performance),
              onLongPress: () => onActions(performance),
              trailing: _TrailingActions(
                performance: performance,
                onActions: onActions,
              ),
            ),
          ),
        );
      }
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.fabClearance,
      ),
      children: <Widget>[
        ...items,
        const Gap.lg(),
        OutlinedButton.icon(
          onPressed: onEnrollExisting,
          icon: const Icon(Icons.group_add_outlined, size: 20),
          label: const Text('Enroll an existing student'),
        ),
        if (scale != null) ...<Widget>[
          const Gap.lg(),
          GradeScaleLegend(scale: scale!),
        ],
        const Gap.md(),
        Text(
          '${Format.plural(controller.studentCount, 'student')} in this class.',
          textAlign: TextAlign.center,
          style: context.text.labelSmall
              ?.copyWith(color: context.semantic.mutedText),
        ),
      ],
    );
  }
}

class _TrailingActions extends StatelessWidget {
  const _TrailingActions({required this.performance, required this.onActions});

  final StudentPerformance performance;
  final void Function(StudentPerformance performance) onActions;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              Format.percentOrDash(performance.percentage, decimals: 0),
              style:
                  context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 3),
            Text(
              performance.grade?.label ?? '—',
              style: context.text.labelSmall?.copyWith(
                color: context.semantic.mutedText,
              ),
            ),
          ],
        ),
        IconButton(
          tooltip: 'Student options',
          icon: const Icon(Icons.more_vert_rounded, size: 20),
          onPressed: () => onActions(performance),
        ),
      ],
    );
  }
}
