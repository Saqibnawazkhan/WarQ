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
import '../../../state/class_list_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/domain/class_card.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Class list tab: search, archive toggle and per-class actions.
class ClassesTab extends StatelessWidget {
  const ClassesTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<ClassListController>(
      create: (BuildContext context) =>
          ClassListController(context.read<AppDependencies>(), teacher)..load(),
      child: const ClassesView(),
    );
  }
}

/// Extracted so the same list can be reused inside a full-screen route.
class ClassesView extends StatelessWidget {
  const ClassesView({super.key, this.showAppBar = true});

  final bool showAppBar;

  Future<void> _confirmDelete(
    BuildContext context,
    ClassListController controller,
    ClassSummary summary,
  ) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${summary.name}?',
      message: 'This permanently removes the class along with its attendance '
          'history, assessments and marks. Student records stay in your account.',
      confirmLabel: 'Delete class',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final bool ok = await controller.deleteClass(summary.id);
    if (!context.mounted) return;
    if (ok) {
      context.showSuccess('${summary.name} deleted.');
    } else {
      context.showError(controller.errorMessage ?? 'Could not delete the class.');
    }
  }

  Future<void> _showActions(
    BuildContext context,
    ClassListController controller,
    ClassSummary summary,
  ) async {
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: summary.name,
        subtitle: summary.schoolClass.subtitle.isEmpty
            ? Format.plural(summary.studentCount, 'student')
            : summary.schoolClass.subtitle,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: const Text('Edit class'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed(
                  Routes.classForm,
                  arguments: ClassFormArgs(existing: summary.schoolClass),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.how_to_reg_outlined),
              title: const Text('Mark attendance'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed(
                  Routes.markAttendance,
                  arguments: MarkAttendanceArgs(classId: summary.id),
                );
              },
            ),
            ListTile(
              leading: const Icon(Icons.picture_as_pdf_outlined),
              title: const Text('Generate class report'),
              onTap: () {
                Navigator.of(sheetContext).pop();
                Navigator.of(context).pushNamed(Routes.reports);
              },
            ),
            ListTile(
              leading: Icon(
                summary.schoolClass.archived
                    ? Icons.unarchive_outlined
                    : Icons.archive_outlined,
              ),
              title: Text(
                summary.schoolClass.archived ? 'Restore class' : 'Archive class',
              ),
              subtitle: Text(
                summary.schoolClass.archived
                    ? 'Show it in your active list again'
                    : 'Hide it without deleting any data',
              ),
              onTap: () async {
                Navigator.of(sheetContext).pop();
                final bool ok = await controller.setArchived(
                  summary.id,
                  !summary.schoolClass.archived,
                );
                if (!context.mounted) return;
                if (ok) {
                  context.showSuccess(
                    summary.schoolClass.archived
                        ? '${summary.name} restored.'
                        : '${summary.name} archived.',
                  );
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
                'Delete class',
                style: TextStyle(color: sheetContext.semantic.danger),
              ),
              onTap: () {
                Navigator.of(sheetContext).pop();
                _confirmDelete(context, controller, summary);
              },
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final ClassListController controller = context.watch<ClassListController>();
    final List<ClassSummary> visible = controller.visible;

    return Scaffold(
      appBar: showAppBar
          ? AppBar(
              title: const Text('Classes'),
              actions: <Widget>[
                IconButton(
                  tooltip: 'Search students',
                  onPressed: () =>
                      Navigator.of(context).pushNamed(Routes.studentSearch),
                  icon: const Icon(Icons.person_search_outlined),
                ),
                PopupMenuButton<String>(
                  tooltip: 'List options',
                  icon: const Icon(Icons.tune_rounded),
                  onSelected: (String value) {
                    switch (value) {
                      case 'archived':
                        controller.setShowArchived(!controller.showArchived);
                      case 'alphabetical':
                        controller.setAlphabetical(!controller.alphabetical);
                    }
                  },
                  itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
                    CheckedPopupMenuItem<String>(
                      value: 'alphabetical',
                      checked: controller.alphabetical,
                      child: const Text('Sort A–Z'),
                    ),
                    CheckedPopupMenuItem<String>(
                      value: 'archived',
                      checked: controller.showArchived,
                      child: const Text('Show archived'),
                    ),
                  ],
                ),
              ],
            )
          : null,
      floatingActionButton: FloatingActionButton.extended(
        // Shell tabs stay alive in an IndexedStack, so every FAB needs its own
        // hero tag or the shared default collides during route transitions.
        heroTag: 'fab-classes',
        onPressed: () => Navigator.of(context).pushNamed(Routes.classForm),
        icon: const Icon(Icons.add_rounded),
        label: const Text('New class'),
      ),
      body: SafeArea(
        top: !showAppBar,
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
                  hintText: 'Search classes, subjects, sections',
                  initialValue: controller.query,
                  onChanged: controller.search,
                ),
              ),
            ),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 4, itemHeight: 130),
                empty: EmptyView(
                  icon: Icons.class_outlined,
                  title: 'No classes yet',
                  message:
                      'Create your first class — you can add students, take '
                      'attendance and record marks straight after.',
                  actionLabel: 'Create a class',
                  onAction: () =>
                      Navigator.of(context).pushNamed(Routes.classForm),
                ),
                builder: (BuildContext context) {
                  if (visible.isEmpty) {
                    return EmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message:
                          'No class matches "${controller.query}". Try a different '
                          'search term.',
                      actionLabel: 'Clear search',
                      onAction: () => controller.search(''),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ContentWidth(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.fabClearance,
                        ),
                        itemCount: visible.length + 1,
                        separatorBuilder: (_, __) => const Gap.md(),
                        itemBuilder: (BuildContext context, int index) {
                          if (index == visible.length) {
                            return _ListFooter(controller: controller);
                          }
                          final ClassSummary summary = visible[index];
                          return ClassCard(
                            summary: summary,
                            onTap: () => Navigator.of(context).pushNamed(
                              Routes.classDetail,
                              arguments: ClassDetailArgs(classId: summary.id),
                            ),
                            trailing: IconButton(
                              tooltip: 'Class options',
                              icon: const Icon(Icons.more_vert_rounded),
                              onPressed: () =>
                                  _showActions(context, controller, summary),
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

class _ListFooter extends StatelessWidget {
  const _ListFooter({required this.controller});

  final ClassListController controller;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.lg),
      child: AppCard(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.lg,
          vertical: AppSpacing.md,
        ),
        color: context.colors.surfaceContainerHigh,
        child: Row(
          children: <Widget>[
            Icon(
              Icons.info_outline_rounded,
              size: 16,
              color: context.semantic.mutedText,
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Text(
                controller.showArchived
                    ? 'Showing archived classes too.'
                    : 'Archived classes are hidden. Use the filter to show them.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
