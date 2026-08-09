import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../state/attendance_history_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Full attendance history with class, student, date-range and status filters.
class AttendanceHistoryScreen extends StatelessWidget {
  const AttendanceHistoryScreen({
    super.key,
    this.args = const AttendanceHistoryArgs(),
  });

  final AttendanceHistoryArgs args;

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<AttendanceHistoryController>(
      create: (BuildContext context) {
        final AttendanceHistoryController controller =
            AttendanceHistoryController(
          context.read<AppDependencies>(),
          teacher,
          initialClassId: args.classId,
        );
        if (args.studentId != null) {
          controller.setStudentFilter(args.studentId);
        } else {
          controller.load();
        }
        return controller;
      },
      child: const _AttendanceHistoryView(),
    );
  }
}

class _AttendanceHistoryView extends StatelessWidget {
  const _AttendanceHistoryView();

  Future<void> _showFilters(
    BuildContext context,
    AttendanceHistoryController controller,
  ) async {
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => _FilterSheet(controller: controller),
    );
  }

  @override
  Widget build(BuildContext context) {
    final AttendanceHistoryController controller =
        context.watch<AttendanceHistoryController>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance history'),
        actions: <Widget>[
          if (controller.hasActiveFilters)
            IconButton(
              tooltip: 'Clear filters',
              onPressed: controller.clearFilters,
              icon: const Icon(Icons.filter_alt_off_outlined),
            ),
          IconButton(
            tooltip: 'Filters',
            onPressed: () => _showFilters(context, controller),
            icon: const Icon(Icons.tune_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            _SummaryBar(controller: controller),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 5, itemHeight: 96),
                empty: EmptyView(
                  icon: Icons.event_busy_outlined,
                  title: 'No attendance records',
                  message: controller.hasActiveFilters
                      ? 'No records match the current filters.'
                      : 'Attendance you take will appear here, grouped by day.',
                  actionLabel:
                      controller.hasActiveFilters ? 'Clear filters' : null,
                  onAction: controller.hasActiveFilters
                      ? controller.clearFilters
                      : null,
                ),
                builder: (BuildContext context) => RefreshIndicator(
                  onRefresh: controller.refresh,
                  child: ContentWidth(
                    child: ListView.separated(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        AppSpacing.md,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      itemCount: controller.sessionRows.length,
                      separatorBuilder: (_, __) => const Gap.md(),
                      itemBuilder: (BuildContext context, int index) =>
                          _SessionGroup(row: controller.sessionRows[index]),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryBar extends StatelessWidget {
  const _SummaryBar({required this.controller});

  final AttendanceHistoryController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      color: context.colors.surface,
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: ContentWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              controller.filterSummary,
              style: context.text.labelMedium
                  ?.copyWith(color: context.semantic.mutedText),
            ),
            const Gap.sm(),
            Row(
              children: <Widget>[
                Expanded(
                  child: _Stat(
                    label: 'Records',
                    value: '${controller.recordCount}',
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Present',
                    value: '${controller.summary.present}',
                    color: context.semantic.success,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Absent',
                    value: '${controller.summary.absent}',
                    color: context.semantic.danger,
                  ),
                ),
                Expanded(
                  child: _Stat(
                    label: 'Rate',
                    value: Format.percentOrDash(
                      controller.summary.percentage,
                      decimals: 0,
                    ),
                    color: context.colors.primary,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value, this.color});

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
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
    );
  }
}

/// One day's attendance for one class, expandable to the per-student rows.
class _SessionGroup extends StatelessWidget {
  const _SessionGroup({required this.row});

  final AttendanceSessionRow row;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: EdgeInsets.zero,
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          tilePadding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
          childrenPadding: const EdgeInsets.fromLTRB(
            AppSpacing.lg,
            0,
            AppSpacing.lg,
            AppSpacing.md,
          ),
          shape: const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
          collapsedShape:
              const RoundedRectangleBorder(borderRadius: AppRadii.cardRadius),
          title: Text(
            row.className,
            style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${AppDate.format(row.date)} · ${AppDate.formatWeekday(row.date)}',
            style: context.text.bodySmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
          trailing: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              AttendanceBadge(percent: row.summary.percentage, dense: true),
              const SizedBox(height: 3),
              Text(
                '${row.summary.present}/${row.summary.assessableSessions}',
                style: context.text.labelSmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ],
          ),
          children: <Widget>[
            for (final AttendanceHistoryRow entry in row.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        entry.studentName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodyMedium,
                      ),
                    ),
                    if (entry.rollNumber != null) ...<Widget>[
                      Text(
                        entry.rollNumber!,
                        style: context.text.labelSmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                      const SizedBox(width: AppSpacing.md),
                    ],
                    AttendanceStatusChip(entry.status, dense: true),
                  ],
                ),
              ),
            const Gap.sm(),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton.icon(
                onPressed: () => Navigator.of(context).pushNamed(
                  Routes.markAttendance,
                  arguments: MarkAttendanceArgs(
                    classId: row.session.classId,
                    date: row.date,
                  ),
                ),
                icon: const Icon(Icons.edit_outlined, size: 18),
                label: const Text('Edit this session'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterSheet extends StatelessWidget {
  const _FilterSheet({required this.controller});

  final AttendanceHistoryController controller;

  @override
  Widget build(BuildContext context) {
    // The sheet lives outside the screen's provider subtree, so it listens to
    // the controller directly to keep the chips in sync as filters change.
    return ListenableBuilder(
      listenable: controller,
      builder: (BuildContext context, Widget? _) => _buildSheet(context),
    );
  }

  Widget _buildSheet(BuildContext context) {
    return AppSheet(
      title: 'Filter attendance',
      actions: <Widget>[
        TextButton(
          onPressed: () {
            controller.clearFilters();
            Navigator.of(context).pop();
          },
          child: const Text('Reset'),
        ),
      ],
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            _FilterLabel('Date range'),
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              children: <Widget>[
                for (final HistoryPreset preset in HistoryPreset.values)
                  ActionChip(
                    label: Text(preset.label),
                    onPressed: () => controller.applyPreset(preset),
                  ),
              ],
            ),
            const Gap.md(),
            OutlinedButton.icon(
              onPressed: () async {
                final DateTimeRange? picked = await showDateRangePicker(
                  context: context,
                  firstDate: DateTime(DateTime.now().year - 2),
                  lastDate: AppDate.today(),
                  initialDateRange:
                      controller.from != null && controller.to != null
                          ? DateTimeRange(
                              start: controller.from!,
                              end: controller.to!,
                            )
                          : null,
                );
                if (picked != null) {
                  await controller.setDateRange(picked.start, picked.end);
                }
              },
              icon: const Icon(Icons.date_range_rounded, size: 20),
              label: const Text('Pick a custom range'),
            ),
            const Gap.xl(),
            _FilterLabel('Classes'),
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final SchoolClass schoolClass in controller.classes)
                  FilterChip(
                    label: Text(schoolClass.name),
                    selected: controller.classIds.contains(schoolClass.id),
                    onSelected: (_) => controller.toggleClass(schoolClass.id),
                  ),
              ],
            ),
            const Gap.xl(),
            _FilterLabel('Status'),
            const Gap.sm(),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                for (final AttendanceStatus status in AttendanceStatus.values)
                  FilterChip(
                    label: Text(status.label),
                    selected: controller.statuses.contains(status),
                    onSelected: (bool selected) {
                      final Set<AttendanceStatus> next =
                          Set<AttendanceStatus>.of(controller.statuses);
                      if (selected) {
                        next.add(status);
                      } else {
                        next.remove(status);
                      }
                      controller.setStatusFilter(next);
                    },
                  ),
              ],
            ),
            const Gap.xl(),
            _FilterLabel('Student'),
            const Gap.sm(),
            DropdownButtonFormField<String?>(
              initialValue: controller.studentId,
              isExpanded: true,
              decoration: const InputDecoration(
                prefixIcon: Icon(Icons.person_search_outlined),
                hintText: 'All students',
              ),
              items: <DropdownMenuItem<String?>>[
                const DropdownMenuItem<String?>(
                  value: null,
                  child: Text('All students'),
                ),
                for (final Student student in controller.students)
                  DropdownMenuItem<String?>(
                    value: student.id,
                    child: Text(
                      student.fullName,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
              onChanged: controller.setStudentFilter,
            ),
            const Gap.xl(),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterLabel extends StatelessWidget {
  const _FilterLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text.toUpperCase(),
      style: context.text.labelSmall?.copyWith(
        color: context.semantic.mutedText,
        letterSpacing: 0.6,
      ),
    );
  }
}
