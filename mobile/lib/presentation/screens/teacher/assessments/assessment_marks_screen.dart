import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../state/assessment_marks_controller.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Enter and edit marks for every student on one assessment.
class AssessmentMarksScreen extends StatelessWidget {
  const AssessmentMarksScreen({super.key, required this.args});

  final AssessmentMarksArgs args;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<AssessmentMarksController>(
      create: (BuildContext context) => AssessmentMarksController(
        context.read<AppDependencies>(),
        args.assessmentId,
      )..load(),
      child: const _MarksView(),
    );
  }
}

class _MarksView extends StatelessWidget {
  const _MarksView();

  Future<bool> _confirmDiscard(
    BuildContext context,
    AssessmentMarksController controller,
  ) async {
    if (!controller.hasUnsavedChanges) return true;
    return showConfirmDialog(
      context,
      title: 'Discard unsaved marks?',
      message: 'Marks you entered have not been saved yet.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
  }

  Future<void> _save(
    BuildContext context,
    AssessmentMarksController controller,
  ) async {
    // Captured before the async gap so the confirmation lands on the screen we
    // return to, not on the one being popped.
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    final bool ok = await controller.save();
    if (!context.mounted) return;
    if (!ok) {
      context.showError(controller.errorMessage ?? 'Could not save the marks.');
      return;
    }

    final String summary = 'Marks saved for ${controller.gradedCount} of '
        '${controller.roster.length} students.';
    navigator.pop(true);
    showSuccessOn(messenger, summary);
  }

  Future<void> _showBulkActions(
    BuildContext context,
    AssessmentMarksController controller,
  ) async {
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Bulk actions',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            ListTile(
              leading: const Icon(Icons.done_all_rounded),
              title: const Text('Give everyone full marks'),
              subtitle: Text(
                'Fills every ungraded student with '
                '${Format.marks(controller.totalMarks)}',
              ),
              onTap: () {
                controller.fillRemainingWith(controller.totalMarks);
                Navigator.of(sheetContext).pop();
              },
            ),
            ListTile(
              leading: const Icon(Icons.exposure_zero_rounded),
              title: const Text('Give ungraded students zero'),
              onTap: () {
                controller.fillRemainingWith(0);
                Navigator.of(sheetContext).pop();
              },
            ),
            const Divider(),
            ListTile(
              leading: Icon(
                Icons.backspace_outlined,
                color: sheetContext.semantic.danger,
              ),
              title: Text(
                'Clear all marks',
                style: TextStyle(color: sheetContext.semantic.danger),
              ),
              onTap: () {
                controller.clearAll();
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
    final AssessmentMarksController controller =
        context.watch<AssessmentMarksController>();
    final Assessment? assessment = controller.assessment;

    return PopScope(
      canPop: !controller.hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        if (await _confirmDiscard(context, controller) && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                assessment?.name ?? 'Marks',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              if (assessment != null)
                Text(
                  '${controller.schoolClass?.name ?? ''} · '
                  '${Format.marks(assessment.totalMarks)} marks',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
            ],
          ),
          actions: <Widget>[
            IconButton(
              tooltip: 'Bulk actions',
              onPressed: controller.roster.isEmpty
                  ? null
                  : () => _showBulkActions(context, controller),
              icon: const Icon(Icons.more_horiz_rounded),
            ),
          ],
        ),
        bottomNavigationBar: controller.roster.isEmpty
            ? null
            : SafeArea(
                child: Container(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  decoration: BoxDecoration(
                    color: context.colors.surface,
                    border: Border(
                      top: BorderSide(color: context.semantic.subtleBorder),
                    ),
                  ),
                  child: ContentWidth(
                    fillHeight: false,
                    child: FilledButton.icon(
                      onPressed: controller.isBusy
                          ? null
                          : () => _save(context, controller),
                      icon: controller.isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.save_rounded),
                      label: const Text('Save marks'),
                    ),
                  ),
                ),
              ),
        body: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 6, itemHeight: 72),
          empty: const EmptyView(
            icon: Icons.people_outline_rounded,
            title: 'No students in this class',
            message: 'Add students before entering marks.',
          ),
          builder: (BuildContext context) => Column(
            children: <Widget>[
              _ProgressStrip(controller: controller),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.md,
                  AppSpacing.lg,
                  AppSpacing.sm,
                ),
                child: ContentWidth(
                  child: SearchField(
                    hintText: 'Find a student',
                    onChanged: controller.search,
                  ),
                ),
              ),
              Expanded(
                child: ContentWidth(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: controller.visibleStudents.length,
                    separatorBuilder: (_, __) => const Gap.sm(),
                    itemBuilder: (BuildContext context, int index) {
                      final Student student = controller.visibleStudents[index];
                      return _MarkRow(
                        key: ValueKey<String>(student.id),
                        student: student,
                        controller: controller,
                      );
                    },
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

class _ProgressStrip extends StatelessWidget {
  const _ProgressStrip({required this.controller});

  final AssessmentMarksController controller;

  @override
  Widget build(BuildContext context) {
    final int total = controller.roster.length;
    final double progress = total == 0 ? 0 : controller.gradedCount / total;

    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: ContentWidth(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    '${controller.gradedCount} of $total graded',
                    style: context.text.labelLarge,
                  ),
                ),
                if (controller.averagePercentage != null)
                  AppBadge(
                    'Avg ${Format.percent(controller.averagePercentage!, decimals: 0)}',
                    tone: GradeBadge.toneForPercent(controller.averagePercentage),
                    dense: true,
                  ),
              ],
            ),
            const Gap.sm(),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: context.semantic.subtleBorder,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One editable row: marks field, absent toggle, live percentage and grade.
class _MarkRow extends StatefulWidget {
  const _MarkRow({
    super.key,
    required this.student,
    required this.controller,
  });

  final Student student;
  final AssessmentMarksController controller;

  @override
  State<_MarkRow> createState() => _MarkRowState();
}

class _MarkRowState extends State<_MarkRow> {
  late final TextEditingController _field;

  @override
  void initState() {
    super.initState();
    final MarkDraft draft = widget.controller.draftFor(widget.student.id);
    _field = TextEditingController(
      text: draft.marks == null ? '' : Format.marks(draft.marks!),
    );
  }

  @override
  void didUpdateWidget(covariant _MarkRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Keep the text field in sync when a bulk action rewrites the draft.
    final MarkDraft draft = widget.controller.draftFor(widget.student.id);
    final String expected = draft.marks == null ? '' : Format.marks(draft.marks!);
    if (_field.text != expected) {
      _field.value = TextEditingValue(
        text: expected,
        selection: TextSelection.collapsed(offset: expected.length),
      );
    }
  }

  @override
  void dispose() {
    _field.dispose();
    super.dispose();
  }

  void _onChanged(String value) {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      widget.controller.setMarks(widget.student.id, null);
      return;
    }
    final double? parsed = double.tryParse(trimmed);
    if (parsed == null) return;
    widget.controller.setMarks(
      widget.student.id,
      parsed.clamp(0, widget.controller.totalMarks),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AssessmentMarksController controller = widget.controller;
    final MarkDraft draft = controller.draftFor(widget.student.id);
    final double? percent = controller.percentFor(widget.student.id);
    final GradeBand? grade = controller.gradeFor(widget.student.id);

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: widget.student.fullName,
            seed: widget.student.id,
            size: 38,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  widget.student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                Row(
                  children: <Widget>[
                    if (widget.student.rollNumber != null)
                      Text(
                        '${widget.student.rollNumber} · ',
                        style: context.text.labelSmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    Text(
                      draft.absent
                          ? 'Marked absent'
                          : percent == null
                              ? 'Not graded'
                              : Format.percent(percent, decimals: 0),
                      style: context.text.labelSmall?.copyWith(
                        color: draft.absent
                            ? context.semantic.danger
                            : context.semantic.mutedText,
                      ),
                    ),
                    if (grade != null) ...<Widget>[
                      const SizedBox(width: AppSpacing.sm),
                      GradeBadge(grade: grade.label, percent: percent, dense: true),
                    ],
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          SizedBox(
            width: 74,
            child: TextField(
              controller: _field,
              enabled: !draft.absent,
              textAlign: TextAlign.center,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: AppSpacing.md,
                ),
                hintText: '—',
                suffixText: '/${Format.marks(controller.totalMarks)}',
                suffixStyle: context.text.labelSmall,
              ),
              onChanged: _onChanged,
            ),
          ),
          IconButton(
            tooltip: draft.absent ? 'Mark as present' : 'Mark absent',
            onPressed: () {
              controller.setAbsent(widget.student.id, !draft.absent);
              if (!draft.absent) _field.clear();
            },
            icon: Icon(
              draft.absent
                  ? Icons.person_off_rounded
                  : Icons.person_off_outlined,
              size: 20,
              color: draft.absent
                  ? context.semantic.danger
                  : context.semantic.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
