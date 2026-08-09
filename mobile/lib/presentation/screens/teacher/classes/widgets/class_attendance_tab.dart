import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_dependencies.dart';
import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/routing/route_args.dart';
import '../../../../../core/routing/route_names.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/date_utils.dart';
import '../../../../../data/models/models.dart';
import '../../../../../domain/entities/attendance_summary.dart';
import '../../../../../domain/entities/student_performance.dart';
import '../../../../state/class_detail_controller.dart';
import '../../../../widgets/common/app_badge.dart';
import '../../../../widgets/common/app_card.dart';
import '../../../../widgets/feedback/dialogs.dart';
import '../../../../widgets/feedback/state_views.dart';
import '../../../../widgets/layout/app_page.dart';

/// Attendance tab inside a class: take today's attendance and browse history.
class ClassAttendanceTab extends StatelessWidget {
  const ClassAttendanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final ClassDetailController controller =
        context.watch<ClassDetailController>();
    final List<AttendanceSession> sessions = controller.sessions;

    return Scaffold(
      backgroundColor: context.semantic.canvas,
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'mark-attendance',
        onPressed: controller.studentCount == 0
            ? null
            : () => Navigator.of(context).pushNamed(
                  Routes.markAttendance,
                  arguments: MarkAttendanceArgs(classId: controller.classId),
                ),
        backgroundColor: controller.studentCount == 0
            ? context.colors.surfaceContainerHighest
            : null,
        foregroundColor: controller.studentCount == 0
            ? context.semantic.mutedText
            : null,
        icon: const Icon(Icons.how_to_reg_rounded),
        label: Text(
          controller.hasAttendanceToday ? 'Edit today' : "Mark today's attendance",
        ),
      ),
      body: RefreshIndicator(
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
              _AttendanceSummaryCard(controller: controller),
              const Gap.lg(),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => Navigator.of(context).pushNamed(
                        Routes.attendanceHistory,
                        arguments:
                            AttendanceHistoryArgs(classId: controller.classId),
                      ),
                      icon: const Icon(Icons.history_rounded, size: 20),
                      label: const Text('Full history'),
                    ),
                  ),
                ],
              ),
              const Gap.xl(),
              if (sessions.isEmpty)
                EmptyView(
                  compact: true,
                  icon: Icons.event_busy_outlined,
                  title: 'No attendance recorded',
                  message: controller.studentCount == 0
                      ? 'Add students to this class before taking attendance.'
                      : 'Take attendance to build a history for this class.',
                )
              else ...<Widget>[
                Text(
                  'Recent sessions',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const Gap.md(),
                for (final AttendanceSession session in sessions)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: _SessionTile(
                      session: session,
                      controller: controller,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _AttendanceSummaryCard extends StatelessWidget {
  const _AttendanceSummaryCard({required this.controller});

  final ClassDetailController controller;

  @override
  Widget build(BuildContext context) {
    final AttendanceSummary summary = AttendanceSummary.combine(
      controller.allStudents
          .map((StudentPerformance p) => p.attendance),
    );

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  'Attendance overview',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              AttendanceBadge(percent: summary.percentage),
            ],
          ),
          const Gap.lg(),
          Row(
            children: <Widget>[
              _Metric(
                label: 'Present',
                value: '${summary.present}',
                color: context.semantic.success,
              ),
              _Metric(
                label: 'Absent',
                value: '${summary.absent}',
                color: context.semantic.danger,
              ),
              _Metric(
                label: 'Late',
                value: '${summary.late}',
                color: context.semantic.warning,
              ),
              _Metric(
                label: 'Short leave',
                value: '${summary.shortLeave}',
                color: context.semantic.info,
              ),
            ],
          ),
          if (controller.hasAttendanceToday) ...<Widget>[
            const Gap.md(),
            Row(
              children: <Widget>[
                Icon(
                  Icons.check_circle_rounded,
                  size: 16,
                  color: context.semantic.success,
                ),
                const SizedBox(width: AppSpacing.sm),
                Text(
                  "Today's attendance is already saved.",
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: <Widget>[
          Text(
            value,
            style: context.text.titleMedium?.copyWith(
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

class _SessionTile extends StatefulWidget {
  const _SessionTile({required this.session, required this.controller});

  final AttendanceSession session;
  final ClassDetailController controller;

  @override
  State<_SessionTile> createState() => _SessionTileState();
}

class _SessionTileState extends State<_SessionTile> {
  AttendanceSummary? _summary;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadSummary();
  }

  Future<void> _loadSummary() async {
    final AppDependencies deps = context.read<AppDependencies>();
    final List<AttendanceRecord> records =
        await deps.attendance.recordsForSession(widget.session.id);
    if (!mounted) return;
    setState(() {
      _summary = AttendanceSummary.fromStatuses(
        records.map((AttendanceRecord r) => r.status),
      );
      _loading = false;
    });
  }

  Future<void> _delete() async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Delete this session?',
      message: 'Attendance recorded on '
          '${AppDate.format(widget.session.date)} will be removed permanently.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !mounted) return;
    final bool ok = await widget.controller.deleteSession(widget.session.id);
    if (!mounted) return;
    if (ok) context.showSuccess('Attendance session deleted.');
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceSummary? summary = _summary;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      onTap: () => Navigator.of(context).pushNamed(
        Routes.markAttendance,
        arguments: MarkAttendanceArgs(
          classId: widget.controller.classId,
          date: widget.session.date,
        ),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
            decoration: BoxDecoration(
              color: context.colors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Column(
              children: <Widget>[
                Text(
                  '${widget.session.date.day}',
                  style: context.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                Text(
                  AppDate.formatWeekday(widget.session.date),
                  style: context.text.labelSmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  AppDate.relativeDay(widget.session.date),
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                if (_loading)
                  Text(
                    'Loading…',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.semantic.mutedText),
                  )
                else if (summary != null)
                  Text(
                    '${summary.present} present · ${summary.absent} absent'
                    '${summary.late > 0 ? ' · ${summary.late} late' : ''}',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
              ],
            ),
          ),
          if (summary != null)
            AttendanceBadge(percent: summary.percentage, dense: true),
          IconButton(
            tooltip: 'Delete session',
            onPressed: _delete,
            icon: Icon(
              Icons.delete_outline_rounded,
              size: 20,
              color: context.semantic.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}
