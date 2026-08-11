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
          // Two lines of the larger type overflow a standard toolbar once the
          // system text scale is turned up, so the bar is given room to hold it.
          toolbarHeight: kToolbarHeight + AppSpacing.lg,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
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
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
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
          loading: const SkeletonList(itemCount: 6, itemHeight: 76),
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
                    separatorBuilder: (_, __) => const Gap.md(),
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
        AppSpacing.lg,
      ),
      child: ContentWidth(
        child: Column(
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  // The count is the number a teacher glances at, so it leads
                  // and the rest of the sentence supports it.
                  child: Text.rich(
                    TextSpan(
                      children: <InlineSpan>[
                        TextSpan(
                          text: '${controller.gradedCount}',
                          style: context.text.titleLarge,
                        ),
                        TextSpan(
                          text: ' of $total graded',
                          style: context.text.bodyMedium
                              ?.copyWith(color: context.semantic.mutedText),
                        ),
                      ],
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                if (controller.averagePercentage != null) ...<Widget>[
                  const SizedBox(width: AppSpacing.sm),
                  AppBadge(
                    'Avg ${Format.percent(controller.averagePercentage!, decimals: 0)}',
                    tone: GradeBadge.toneForPercent(controller.averagePercentage),
                  ),
                ],
              ],
            ),
            const Gap.md(),
            ClipRRect(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 8,
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

    final TextStyle? subtle = context.text.bodySmall
        ?.copyWith(color: context.semantic.mutedText);

    return AppCard(
      // Horizontal padding stays tighter than a plain tile's: this row also
      // carries a field and a toggle, and the width it saves goes to the name.
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: widget.student.fullName,
            seed: widget.student.id,
            size: 42,
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
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Row(
                  children: <Widget>[
                    // One paragraph rather than two adjacent Texts: the roll
                    // number and the status together are wider than this column
                    // on a narrow phone, and only a single Text can ellipsize.
                    Flexible(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            if (widget.student.rollNumber != null)
                              TextSpan(text: '${widget.student.rollNumber} · '),
                            TextSpan(
                              text: draft.absent
                                  ? 'Marked absent'
                                  : percent == null
                                      ? 'Not graded'
                                      : Format.percent(percent, decimals: 0),
                              style: draft.absent
                                  ? subtle?.copyWith(
                                      color: context.semantic.danger,
                                      fontWeight: FontWeight.w600,
                                    )
                                  : null,
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: subtle,
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
            // Roomy enough to tap and to read the value back at a glance; the
            // mark is the point of the row, so it is set larger than its label.
            // The `/total` suffix eats into the same box, so this has to hold
            // three digits *and* the suffix at the largest text scale allowed,
            // or a teacher entering 100 cannot see what they typed.
            width: 92,
            child: TextField(
              controller: _field,
              enabled: !draft.absent,
              textAlign: TextAlign.center,
              style: context.text.titleMedium,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.]')),
              ],
              decoration: InputDecoration(
                isDense: true,
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.xs,
                  vertical: AppSpacing.md,
                ),
                hintText: '—',
                suffixText: '/${Format.marks(controller.totalMarks)}',
                suffixStyle: subtle,
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
              size: 22,
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
