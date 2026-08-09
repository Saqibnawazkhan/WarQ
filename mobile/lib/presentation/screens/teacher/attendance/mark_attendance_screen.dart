import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/services/absence_notification_service.dart';
import '../../../state/attendance_marking_controller.dart';
import '../../../state/session_controller.dart';
import 'widgets/absence_dispatch_sheet.dart';
import '../../../widgets/common/app_avatar.dart';
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
    final AbsenceDispatchReport? report =
        await controller.save(notifyGuardians: _notifyGuardians);
    if (!mounted) return;

    if (report == null) {
      // Reported inline rather than as a snackbar so it cannot be hidden
      // behind the save bar, and so it stays on screen while the teacher fixes
      // the problem.
      setState(() =>
          _error = controller.errorMessage ?? 'Could not save attendance.');
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
    final AttendanceMarkingController controller =
        context.watch<AttendanceMarkingController>();

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
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(controller.schoolClass?.name ?? 'Attendance'),
              Text(
                AppDate.relativeDay(controller.date),
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
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
          loading: const SkeletonList(itemCount: 6, itemHeight: 64),
          empty: const EmptyView(
            icon: Icons.people_outline_rounded,
            title: 'No students in this class',
            message:
                'Add students to the class before taking attendance.',
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
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: context.semantic.danger,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _error!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.semantic.onDangerContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              _SummaryStrip(controller: controller),
              _BulkActions(controller: controller),
              Expanded(
                child: ContentWidth(
                  child: ListView.separated(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.lg,
                      AppSpacing.sm,
                      AppSpacing.lg,
                      AppSpacing.xxl,
                    ),
                    itemCount: controller.roster.length,
                    separatorBuilder: (_, __) => const Gap.sm(),
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
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      child: ContentWidth(
        child: Row(
          children: <Widget>[
            _Count(
              label: 'Present',
              value: controller.presentCount,
              color: context.semantic.success,
            ),
            _Count(
              label: 'Absent',
              value: controller.absentCount,
              color: context.semantic.danger,
            ),
            _Count(
              label: 'Late',
              value: controller.lateCount,
              color: context.semantic.warning,
            ),
            _Count(
              label: 'Excused',
              value: controller.excusedCount,
              color: context.semantic.info,
            ),
          ],
        ),
      ),
    );
  }
}

class _Count extends StatelessWidget {
  const _Count({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            '$value',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: color,
            ),
          ),
          Text(
            label,
            style: context.text.labelSmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
        ],
      ),
    );
  }
}

class _BulkActions extends StatelessWidget {
  const _BulkActions({required this.controller});

  final AttendanceMarkingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        0,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: ContentWidth(
        child: Row(
          children: <Widget>[
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.markAll(AttendanceStatus.present),
                icon: const Icon(Icons.done_all_rounded, size: 18),
                label: const Text('All present'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: context.semantic.success,
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => controller.markAll(AttendanceStatus.absent),
                icon: const Icon(Icons.remove_done_rounded, size: 18),
                label: const Text('All absent'),
                style: OutlinedButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
                  foregroundColor: context.semantic.danger,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One student row with a four-way status selector.
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
    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      borderColor: AttendanceStatusChip.colorFor(context, status)
          .withValues(alpha: 0.35),
      child: Row(
        children: <Widget>[
          AppAvatar(name: student.fullName, seed: student.id, size: 38),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  student.fullName,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                Row(
                  children: <Widget>[
                    if (student.rollNumber != null)
                      Text(
                        student.rollNumber!,
                        style: context.text.labelSmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    if (student.rollNumber != null &&
                        !student.hasAnyContact)
                      Text(
                        ' · ',
                        style: context.text.labelSmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    if (!student.hasAnyContact)
                      Text(
                        'No contact number',
                        style: context.text.labelSmall
                            ?.copyWith(color: context.semantic.warning),
                      ),
                  ],
                ),
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

class _StatusSelector extends StatelessWidget {
  const _StatusSelector({required this.status, required this.onChanged});

  final AttendanceStatus status;
  final ValueChanged<AttendanceStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final AttendanceStatus option in AttendanceStatus.values)
          Padding(
            padding: const EdgeInsets.only(left: 4),
            child: _StatusButton(
              option: option,
              selected: option == status,
              onTap: () => onChanged(option),
            ),
          ),
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
            width: 34,
            height: 34,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: selected ? color : color.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(AppRadii.sm),
              border: Border.all(
                color: selected ? color : color.withValues(alpha: 0.25),
              ),
            ),
            child: Text(
              option.shortLabel,
              style: context.text.labelMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: selected ? Colors.white : color,
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

    return SafeArea(
      child: Container(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          AppSpacing.md,
          AppSpacing.lg,
          AppSpacing.md,
        ),
        decoration: BoxDecoration(
          color: context.colors.surface,
          border: Border(top: BorderSide(color: context.semantic.subtleBorder)),
        ),
        child: ContentWidth(
          fillHeight: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (controller.absentCount > 0)
                SwitchListTile.adaptive(
                  value: notifyGuardians,
                  onChanged: onToggleNotify,
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'Notify guardians of absences',
                    style: context.text.bodyMedium,
                  ),
                  subtitle: Text(
                    <String>[
                      if (notifiable > 0)
                        '${Format.plural(notifiable, 'student')} will be messaged',
                      if (unreachable > 0)
                        '$unreachable without a phone number',
                    ].join(' · '),
                    style: context.text.labelSmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                ),
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
    );
  }
}
