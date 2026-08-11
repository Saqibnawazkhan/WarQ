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
import '../../../../domain/entities/attendance_summary.dart';
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
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.sm,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: ContentWidth(
        child: AppCard(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                controller.filterSummary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelMedium
                    ?.copyWith(color: context.semantic.mutedText),
              ),
              const Gap.md(),
              Row(
                // Tops aligned, so the four numbers sit on one line even when a
                // caption below one of them wraps.
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _Figure(
                      // Days, not records: a teacher scanning this card is
                      // counting registers taken, and the list underneath is
                      // one row per session.
                      value: Format.count(controller.sessionRows.length),
                      caption: 'Sessions',
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      value: Format.count(controller.summary.present),
                      caption: 'Present',
                      color: context.semantic.success,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      value: Format.count(controller.summary.absent),
                      caption: 'Absent',
                      color: context.semantic.danger,
                    ),
                  ),
                  Expanded(
                    child: _Figure(
                      value: Format.percentOrDash(
                        controller.summary.percentage,
                        decimals: 0,
                      ),
                      caption: 'Average',
                      color: context.colors.primary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A big number over a small muted caption.
class _Figure extends StatelessWidget {
  const _Figure({required this.value, required this.caption, this.color});

  final String value;
  final String caption;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        // Four figures share the card, so a quarter of it is all the width a
        // number gets. Scaling one down beats ellipsising it — a truncated
        // figure reads as a wrong one.
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            maxLines: 1,
            style: context.text.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800, color: color),
          ),
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          caption,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium
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
    return _BarCard(
      // Neutral rather than the class colour: a row here is a day, and the
      // class it belongs to is already named on the line under the date.
      accent: context.colors.primary,
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
          // The date leads, the way the prototype has it — a teacher opening
          // history is looking for a day, and the class is a chip away.
          title: Text(
            AppDate.format(row.date),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          // The marks sit under the class name rather than out to the right:
          // four figures at this type scale need more width than a phone leaves
          // beside a date, and the chevron has to keep its place.
          subtitle: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Text(
                '${row.className} · ${AppDate.formatWeekday(row.date)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
              const Gap.sm(),
              _MarkCounts(summary: row.summary),
            ],
          ),
          children: <Widget>[
            for (final AttendanceHistoryRow entry in row.rows)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
                child: Row(
                  children: <Widget>[
                    // Name and roll number as one run, so a long roll number
                    // eats into the space it needs rather than taking its width
                    // first and pushing the chip off the end of the row.
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: <InlineSpan>[
                            TextSpan(
                              text: entry.studentName,
                              style: context.text.bodyMedium,
                            ),
                            if (entry.rollNumber != null)
                              TextSpan(
                                text: '  ${entry.rollNumber}',
                                style: context.text.labelSmall?.copyWith(
                                  color: context.semantic.mutedText,
                                ),
                              ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
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

/// `11 P  0 A  1 L  0 S`, each figure in its status colour.
///
/// Four marks, not the three the prototype draws: short leave is a real mark in
/// this app and a day it was used has to say so.
class _MarkCounts extends StatelessWidget {
  const _MarkCounts({required this.summary});

  final AttendanceSummary summary;

  int _countOf(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => summary.present,
        AttendanceStatus.absent => summary.absent,
        AttendanceStatus.late => summary.late,
        AttendanceStatus.shortLeave => summary.shortLeave,
      };

  @override
  Widget build(BuildContext context) {
    // Only shrinks once the system text size has already grown the row past the
    // width it has, so the figures never end up smaller than they start.
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          for (final AttendanceStatus status in AttendanceStatus.values) ...<Widget>[
            if (status != AttendanceStatus.values.first)
              const SizedBox(width: AppSpacing.md),
            Text.rich(
              TextSpan(
                children: <InlineSpan>[
                  TextSpan(
                    text: '${_countOf(status)}',
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AttendanceStatusChip.colorFor(context, status),
                    ),
                  ),
                  TextSpan(
                    text: ' ${status.shortLabel}',
                    style: context.text.labelMedium?.copyWith(
                      color: AttendanceStatusChip.colorFor(context, status),
                    ),
                  ),
                ],
              ),
              maxLines: 1,
            ),
          ],
        ],
      ),
    );
  }
}

/// The prototype's list row: a white card with a thin colour bar down its left
/// edge.
///
/// Drawn as a coloured card the white content sits on top of, so the bar stays
/// exactly as tall as the row — including while the row is expanding, which an
/// intrinsic-height measurement would have to redo on every frame.
///
/// Keeps the app's hairline border, which the summary card above it has. The
/// prototype separates its cards with a soft shadow on a lavender page; this
/// app's page is a 2% grey and has no shadow anywhere, so a white row without
/// the border has no edge at all.
class _BarCard extends StatelessWidget {
  const _BarCard({required this.accent, required this.child});

  final Color accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: accent,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: context.semantic.subtleBorder),
      ),
      padding: const EdgeInsets.only(left: AppSpacing.xs),
      child: Material(color: context.colors.surface, child: child),
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
