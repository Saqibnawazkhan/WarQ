import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/glass.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/services/absence_notification_service.dart';
import '../../../state/attendance_marking_controller.dart';
import '../../../state/session_controller.dart';
import 'widgets/absence_dispatch_sheet.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Take or edit attendance for one class on one date.
class MarkAttendanceScreen extends StatelessWidget {
  const MarkAttendanceScreen({super.key, required this.args});

  final MarkAttendanceArgs args;

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<AttendanceMarkingController>(
      create: (BuildContext context) => AttendanceMarkingController(
        context.read<AppDependencies>(),
        teacher,
        classId: args.classId,
        initialDate: args.date,
      )..load(),
      child: const _MarkAttendanceView(),
    );
  }
}

class _MarkAttendanceView extends StatefulWidget {
  const _MarkAttendanceView();

  @override
  State<_MarkAttendanceView> createState() => _MarkAttendanceViewState();
}

class _MarkAttendanceViewState extends State<_MarkAttendanceView> {
  bool _notifyGuardians = true;
  String? _error;

  Future<void> _pickDate(AttendanceMarkingController controller) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: controller.date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: AppDate.today(),
      helpText: 'Attendance date',
    );
    if (picked != null) await controller.changeDate(picked);
  }

  Future<void> _save(AttendanceMarkingController controller) async {
    // Captured before the async gap: the confirmation is shown after this
    // route is popped, because this screen's save bar is too tall for a
    // floating snackbar to fit above it.
    final NavigatorState navigator = Navigator.of(context);
    final ScaffoldMessengerState messenger = ScaffoldMessenger.of(context);

    setState(() => _error = null);
    final AbsenceDispatchReport? report = await controller.save(
      notifyGuardians: _notifyGuardians,
    );
    if (!mounted) return;

    if (report == null) {
      // Reported inline rather than as a snackbar so it cannot be hidden
      // behind the save bar, and so it stays on screen while the teacher fixes
      // the problem.
      setState(
        () => _error = controller.errorMessage ?? 'Could not save attendance.',
      );
      return;
    }

    // Hand the prepared notices to WhatsApp before leaving the screen.
    if (report.pending.isNotEmpty || report.studentsWithoutContact.isNotEmpty) {
      await showAbsenceDispatchSheet(
        context,
        report: report,
        className: controller.schoolClass?.name ?? 'this class',
      );
      if (!mounted) return;
    }

    final String summary = report.isEmpty
        ? 'Attendance saved. ${controller.presentCount} present, '
              '${controller.absentCount} absent.'
        : 'Attendance saved. ${report.describe()}';

    navigator.pop(true);
    showSuccessOn(messenger, summary);
  }

  Future<bool> _confirmDiscard(AttendanceMarkingController controller) async {
    if (!controller.hasUnsavedChanges) return true;
    return showConfirmDialog(
      context,
      title: 'Discard changes?',
      message: 'Attendance for this date has not been saved yet.',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep editing',
      isDestructive: true,
      icon: Icons.warning_amber_rounded,
    );
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceMarkingController controller = context
        .watch<AttendanceMarkingController>();

    return PopScope(
      canPop: !controller.hasUnsavedChanges,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (didPop) return;
        final bool discard = await _confirmDiscard(controller);
        if (!discard || !context.mounted) return;
        Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AppBar(
          // Two stacked lines at the current type scale need more than the
          // 56dp default, which clips them as soon as the system text size is
          // turned up.
          toolbarHeight: 72,
          title: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                controller.schoolClass?.name ?? 'Attendance',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              Text(
                AppDate.relativeDay(controller.date),
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
              tooltip: 'Change date',
              onPressed: () => _pickDate(controller),
              icon: const Icon(Icons.calendar_today_rounded),
            ),
          ],
        ),
        bottomNavigationBar: controller.hasStudents
            ? _SaveBar(
                controller: controller,
                notifyGuardians: _notifyGuardians,
                onToggleNotify: (bool value) =>
                    setState(() => _notifyGuardians = value),
                onSave: () => _save(controller),
              )
            : null,
        body: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 5, itemHeight: 140),
          empty: const EmptyView(
            icon: Icons.people_outline_rounded,
            title: 'No students in this class',
            message: 'Add students to the class before taking attendance.',
          ),
          builder: (BuildContext context) => Column(
            children: <Widget>[
              if (_error != null)
                Container(
                  width: double.infinity,
                  color: context.semantic.dangerContainer,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                  child: Row(
                    // Keeps the icon beside the first line when the message
                    // wraps rather than floating in the middle of it.
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 20,
                        color: context.semantic.danger,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _error!,
                          style: context.text.bodyMedium?.copyWith(
                            color: context.semantic.onDangerContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _SummaryStrip(controller: controller),
              Expanded(
                child: ContentWidth(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.md,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: controller.roster.length,
                    separatorBuilder: (_, __) => const Gap.md(),
                    itemBuilder: (BuildContext context, int index) {
                      final Student student = controller.roster[index];
                      return _AttendanceRow(
                        student: student,
                        status: controller.statusFor(student.id),
                        onChanged: (AttendanceStatus status) =>
                            controller.setStatus(student.id, status),
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

class _SummaryStrip extends StatelessWidget {
  const _SummaryStrip({required this.controller});

  final AttendanceMarkingController controller;

  @override
  Widget build(BuildContext context) {
    // One line, the way the prototype has it: the tally on the left and the
    // bulk action on the right. Four stacked number-and-caption columns plus a
    // separate row of buttons underneath cost about a fifth of the screen to
    // say something a teacher reads in a glance.
    return Container(
      color: Glass.fill(context),
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: ContentWidth(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            color: context.colors.surfaceContainerHigh,
            borderRadius: AppRadii.cardRadius,
          ),
          child: Row(
            children: <Widget>[
              Expanded(
                // Scrolls rather than wraps: with four counts and a long word
                // like "short leave" there is no width at which all of it fits
                // every phone, and a tally that reflows to two lines moves the
                // bulk action around under the teacher's thumb.
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: <Widget>[
                      _Count(
                        label: 'present',
                        value: controller.presentCount,
                        color: context.semantic.success,
                      ),
                      _Count(
                        label: 'absent',
                        value: controller.absentCount,
                        color: context.semantic.danger,
                      ),
                      _Count(
                        label: 'late',
                        value: controller.lateCount,
                        color: context.semantic.warning,
                      ),
                      // "leave" rather than "short leave": the tally has a
                      // fourth figure the prototype did not, and the full
                      // phrase pushes it off the end of the line. In a row
                      // that already reads present, absent, late, the short
                      // word is unambiguous.
                      _Count(
                        label: 'leave',
                        value: controller.shortLeaveCount,
                        color: context.semantic.info,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              TextButton(
                onPressed: () => controller.markAll(AttendanceStatus.present),
                style: TextButton.styleFrom(
                  foregroundColor: context.colors.primary,
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.sm,
                  ),
                  minimumSize: const Size(0, 40),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('All present'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One figure in the tally: the number in its status colour, the word after it.
class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: AppSpacing.md),
      child: Text.rich(
        TextSpan(
          children: <InlineSpan>[
            TextSpan(
              text: '$value ',
              style: context.text.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            TextSpan(
              text: label,
              style: context.text.bodySmall?.copyWith(color: color),
            ),
          ],
        ),
        maxLines: 1,
      ),
    );
  }
}

/// One student row with a four-way status selector.
///
/// The name and the selector are stacked rather than side by side. Sharing one
/// line left a phone barely 90dp for the name — long enough for "Muhammad A…"
/// and nothing more — while squeezing four buttons below the size a thumb can
/// hit reliably. Given a line each, the name reads in full and every button is
/// a comfortable target.
class _AttendanceRow extends StatelessWidget {
  const _AttendanceRow({
    required this.student,
    required this.status,
    required this.onChanged,
  });

  final Student student;
  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    final bool showMeta = student.rollNumber != null || !student.hasAnyContact;

    // One line per student, with the marks on the same line as the name.
    // Stacking them put three students on a screen; a class of thirty is the
    // normal case, and a teacher should be able to see who is left to mark
    // without scrolling away from the ones they just did.
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderColor: AttendanceStatusChip.colorFor(
        context,
        status,
      ).withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                // Two lines, because four mark buttons leave the name about
                // 150dp and a register full of "Muhammad Saqib …" is a register
                // where two students cannot be told apart. Only long names
                // take the second line, so most rows stay one line tall.
                Text(
                  student.fullName,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                ),
                if (showMeta) _StudentMeta(student: student),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          _StatusSelector(status: status, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// The quiet second line under a student's name.
class _StudentMeta extends StatelessWidget {
  const _StudentMeta({required this.student});

  final Student student;

  @override
  Widget build(BuildContext context) {
    final TextStyle? muted = context.text.bodySmall?.copyWith(
      color: context.semantic.mutedText,
    );
    final bool needsContact = !student.hasAnyContact;

    // One text run rather than a row of them: a long roll number then eats into
    // the space it actually needs instead of squeezing the contact warning,
    // which is the part the teacher has to act on.
    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          if (student.rollNumber != null)
            TextSpan(text: student.rollNumber, style: muted),
          if (student.rollNumber != null && needsContact)
            TextSpan(text: ' · ', style: muted),
          if (needsContact)
            TextSpan(
              text: 'No contact number',
              style: context.text.bodySmall?.copyWith(
                color: context.semantic.warning,
              ),
            ),
        ],
      ),
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.status, required this.onChanged});

  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    const List<AttendanceStatus> options = AttendanceStatus.values;

    // Fixed width rather than shares of the row, so the four marks sit in the
    // same place on every student. A register is marked by working down the
    // column without looking away from the names.
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (int i = 0; i < options.length; i++) ...<Widget>[
          if (i > 0) const SizedBox(width: AppSpacing.xs),
          _StatusButton(
            option: options[i],
            selected: options[i] == status,
            onTap: () => onChanged(options[i]),
          ),
        ],
      ],
    );
  }
}

class _StatusButton extends StatelessWidget {
  const _StatusButton({
    required this.option,
    required this.selected,
    required this.onTap,
  });

  final AttendanceStatus option;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = AttendanceStatusChip.colorFor(context, option);
    final Color foreground = selected ? Colors.white : color;
    return Tooltip(
      message: option.label,
      child: Semantics(
        button: true,
        selected: selected,
        label: option.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.sm),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            // Square and comfortably past the 48dp minimum target. The letter
            // alone now: at this size an icon beside it made both small, and
            // the letter is the thing a teacher is actually aiming at.
            width: 46,
            height: 48,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.25),
                width: selected ? 1.5 : 1,
              ),
            ),
            child: Text(
              option.shortLabel,
              style: context.text.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SaveBar extends StatelessWidget {
  const _SaveBar({
    required this.controller,
    required this.notifyGuardians,
    required this.onToggleNotify,
    required this.onSave,
  });

  final AttendanceMarkingController controller;
  final bool notifyGuardians;
  final ValueChanged<bool> onToggleNotify;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final int notifiable = controller.notifiableAbsentees.length;
    final int unreachable = controller.absenteesWithoutContact.length;

    // Blurred, not merely translucent: the register scrolls underneath this
    // bar, and a see-through fill would show the student rows through it.
    return GlassSurface(
      blur: 20,
      border: false,
      raised: true,
      child: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          decoration: BoxDecoration(
            border: Border(top: BorderSide(color: Glass.edge(context))),
          ),
          child: ContentWidth(
            fillHeight: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              // Everywhere else in the app a primary button spans its container,
              // because a list body stretches its children. This column did not,
              // leaving the one button that ends the task sized to its label.
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                if (controller.absentCount > 0) ...<Widget>[
                  SwitchListTile.adaptive(
                    value: notifyGuardians,
                    onChanged: onToggleNotify,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(
                      'Notify guardians of absences',
                      style: context.text.titleSmall,
                    ),
                    subtitle: Text(
                      <String>[
                        if (notifiable > 0)
                          '${Format.plural(notifiable, 'student')} will be messaged',
                        if (unreachable > 0)
                          '$unreachable without a phone number',
                      ].join(' · '),
                      style: context.text.bodySmall?.copyWith(
                        color: context.semantic.mutedText,
                      ),
                    ),
                  ),
                  const Gap.sm(),
                ],
                FilledButton.icon(
                  onPressed: controller.isBusy ? null : onSave,
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
                  label: Text(
                    controller.isExistingSession
                        ? 'Update attendance'
                        : 'Save attendance',
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
