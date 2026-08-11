import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/attendance_summary.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/class_list_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Attendance: today's registers and the record behind them, on one screen.
class AttendanceTab extends StatelessWidget {
  const AttendanceTab({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<ClassListController>(
      create: (BuildContext context) =>
          ClassListController(context.read<AppDependencies>(), teacher)..load(),
      child: const _AttendanceHubView(),
    );
  }
}

/// The two halves of the screen, switched by the pill under the title.
enum _AttendanceView { today, history }

extension on _AttendanceView {
  String get label => switch (this) {
        _AttendanceView.today => 'Today',
        _AttendanceView.history => 'History',
      };
}

class _AttendanceHubView extends StatefulWidget {
  const _AttendanceHubView();

  @override
  State<_AttendanceHubView> createState() => _AttendanceHubViewState();
}

class _AttendanceHubViewState extends State<_AttendanceHubView> {
  _AttendanceView _view = _AttendanceView.today;

  /// `null` means every class — the "All classes" chip.
  String? _classId;

  @override
  Widget build(BuildContext context) {
    final ClassListController controller = context.watch<ClassListController>();
    final List<ClassSummary> classes = controller.visible;

    // A chip can outlive the class it names — archived from the Classes tab,
    // deleted on another device — so a selection that no longer resolves falls
    // back to every class instead of leaving the teacher on a blank screen.
    final List<ClassSummary> picked = _classId == null
        ? classes
        : classes.where((ClassSummary c) => c.id == _classId).toList();
    final List<ClassSummary> scope = picked.isEmpty ? classes : picked;

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            ContentWidth(fillHeight: false, child: _ScreenHeader(classes: classes)),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 4, itemHeight: 96),
                empty: EmptyView(
                  icon: Icons.how_to_reg_outlined,
                  title: 'Nothing to mark yet',
                  message:
                      'Create a class and add students to start taking attendance.',
                  actionLabel: 'Create a class',
                  onAction: () => Navigator.of(context).pushNamed(Routes.classForm),
                ),
                builder: (BuildContext context) => Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    ContentWidth(
                      fillHeight: false,
                      child: _ViewSwitch(
                        value: _view,
                        onChanged: (_AttendanceView view) =>
                            setState(() => _view = view),
                      ),
                    ),
                    // One class needs no chooser; the header already names the
                    // day and the list below is that class.
                    if (classes.length > 1)
                      ContentWidth(
                        fillHeight: false,
                        child: _ClassChips(
                          classes: classes,
                          selectedId: _classId,
                          onSelect: (String? id) => setState(() => _classId = id),
                        ),
                      ),
                    Expanded(
                      child: switch (_view) {
                        _AttendanceView.today => _TodayView(
                            classes: scope,
                            onRefresh: controller.refresh,
                          ),
                        _AttendanceView.history => _HistoryView(
                            classes: scope,
                            onRefresh: controller.refresh,
                          ),
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The screen title, the day's progress under it, and the date on the right.
class _ScreenHeader extends StatelessWidget {
  const _ScreenHeader({required this.classes});

  final List<ClassSummary> classes;

  @override
  Widget build(BuildContext context) {
    final DateTime today = DateTime.now();
    final int marked =
        classes.where((ClassSummary c) => c.markedToday).length;
    final int total = classes
        .where((ClassSummary c) => c.markedToday || c.studentCount > 0)
        .length;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.lg,
        AppSpacing.md,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  'Attendance',
                  style: context.text.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  total == 0
                      ? AppDate.formatLong(today)
                      : marked >= total
                          ? 'Every register taken today'
                          : '$marked of $total marked today',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodyMedium
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          // Flexible, not fixed: the pill is the only child of this row that
          // takes its width first, and at the largest system text size a
          // long-form date is wide enough to leave the title none.
          Flexible(child: _DatePill(date: today)),
        ],
      ),
    );
  }
}

class _DatePill extends StatelessWidget {
  const _DatePill({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: context.colors.primary.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.calendar_today_rounded,
            size: 16,
            applyTextScaling: true,
            color: context.colors.primary,
          ),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              AppDate.formatShort(date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: context.colors.primary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Today | History, as one filled pill rather than a tab bar.
class _ViewSwitch extends StatelessWidget {
  const _ViewSwitch({required this.value, required this.onChanged});

  final _AttendanceView value;
  final ValueChanged<_AttendanceView> onChanged;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
      child: Container(
        padding: const EdgeInsets.all(AppSpacing.xs),
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(AppRadii.pill),
        ),
        child: Row(
          children: <Widget>[
            for (final _AttendanceView view in _AttendanceView.values)
              Expanded(
                child: _Segment(
                  label: view.label,
                  selected: view == value,
                  onTap: () => onChanged(view),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Segment extends StatelessWidget {
  const _Segment({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 160),
            constraints: const BoxConstraints(minHeight: 44),
            alignment: Alignment.center,
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
            decoration: BoxDecoration(
              color: selected ? context.colors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
                color: selected
                    ? context.colors.onPrimary
                    : context.semantic.mutedText,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The class chooser: a scrolling row of pills, the selected one filled.
class _ClassChips extends StatelessWidget {
  const _ClassChips({
    required this.classes,
    required this.selectedId,
    required this.onSelect,
  });

  final List<ClassSummary> classes;
  final String? selectedId;
  final ValueChanged<String?> onSelect;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: AppSpacing.md),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
        child: Row(
          children: <Widget>[
            _ClassChip(
              label: 'All classes',
              selected: selectedId == null,
              onTap: () => onSelect(null),
            ),
            for (final ClassSummary summary in classes) ...<Widget>[
              const SizedBox(width: AppSpacing.sm),
              _ClassChip(
                label: summary.name,
                selected: summary.id == selectedId,
                accent:
                    AppColors.classColors(summary.schoolClass.colorSeed).first,
                onTap: () => onSelect(summary.id),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _ClassChip extends StatelessWidget {
  const _ClassChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? context.colors.primary : context.colors.surface,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: Container(
            // The row scrolls, so nothing bounds a chip but this: a class named
            // after a whole syllabus would otherwise be one chip wide enough to
            // hide every other class behind it.
            constraints: const BoxConstraints(maxWidth: 200, minHeight: 44),
            padding: const EdgeInsets.symmetric(horizontal: AppSpacing.lg),
            // Deliberately no `alignment`: a Container that is told to align
            // its child inside a *bounded* width stops hugging it and fills
            // that width instead, which made every chip exactly 200 wide and
            // pushed all but the first two off the screen. The row inside is
            // already centred vertically by the minimum height above.
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadii.pill),
              border: Border.all(
                color: selected
                    ? context.colors.primary
                    : context.semantic.subtleBorder,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (accent != null) ...<Widget>[
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: selected ? context.colors.onPrimary : accent,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                ],
                Flexible(
                  child: Text(
                    label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.labelLarge?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: selected
                          ? context.colors.onPrimary
                          : context.colors.onSurface,
                    ),
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

// -----------------------------------------------------------------------------
// Today
// -----------------------------------------------------------------------------

class _TodayView extends StatelessWidget {
  const _TodayView({required this.classes, required this.onRefresh});

  final List<ClassSummary> classes;
  final Future<void> Function() onRefresh;

  void _mark(BuildContext context, ClassSummary summary) {
    Navigator.of(context).pushNamed(
      Routes.markAttendance,
      arguments: MarkAttendanceArgs(classId: summary.id),
    );
  }

  @override
  Widget build(BuildContext context) {
    final List<ClassSummary> pending = classes
        .where((ClassSummary c) => !c.markedToday && c.studentCount > 0)
        .toList();
    final List<ClassSummary> done =
        classes.where((ClassSummary c) => c.markedToday).toList();
    final List<ClassSummary> empty =
        classes.where((ClassSummary c) => c.studentCount == 0).toList();
    final int students = classes.fold<int>(
      0,
      (int total, ClassSummary c) => total + c.studentCount,
    );

    return AppPageBody(
      onRefresh: onRefresh,
      children: <Widget>[
        _StatRow(
          pending: pending.length,
          marked: done.length,
          students: students,
        ),
        const Gap.xl(),
        if (pending.isNotEmpty) ...<Widget>[
          SectionHeader(
            title: 'Pending today',
            subtitle: AppDate.formatLong(DateTime.now()),
          ),
          for (final ClassSummary summary in pending)
            _ClassRow(summary: summary, onTap: () => _mark(context, summary)),
          const Gap.lg(),
        ],
        if (done.isNotEmpty) ...<Widget>[
          const SectionHeader(
            title: 'Marked today',
            subtitle: 'Tap to review or edit',
          ),
          for (final ClassSummary summary in done)
            _ClassRow(summary: summary, onTap: () => _mark(context, summary)),
          const Gap.lg(),
        ],
        if (empty.isNotEmpty) ...<Widget>[
          const SectionHeader(
            title: 'Waiting for students',
            subtitle: 'Add students before taking attendance',
          ),
          for (final ClassSummary summary in empty)
            _ClassRow(
              summary: summary,
              onTap: () => Navigator.of(context).pushNamed(
                Routes.classDetail,
                arguments: ClassDetailArgs(classId: summary.id),
              ),
            ),
        ],
        const Gap.xxl(),
      ],
    );
  }
}

/// Three figures across the top of the day, the first one filled with the brand.
class _StatRow extends StatelessWidget {
  const _StatRow({
    required this.pending,
    required this.marked,
    required this.students,
  });

  final int pending;
  final int marked;
  final int students;

  @override
  Widget build(BuildContext context) {
    // Measured against each other so the filled card and its neighbours share a
    // height even when one caption wraps.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Expanded(
            child: _StatCard(
              value: Format.count(pending),
              caption: 'To mark',
              filled: true,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              value: Format.count(marked),
              caption: 'Marked',
              accent: context.semantic.success,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: _StatCard(
              value: Format.count(students),
              caption: 'Students',
            ),
          ),
        ],
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.value,
    required this.caption,
    this.accent,
    this.filled = false,
  });

  final String value;
  final String caption;
  final Color? accent;
  final bool filled;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        filled ? context.colors.onPrimary : (accent ?? context.colors.onSurface);

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.lg,
      ),
      decoration: BoxDecoration(
        color: filled ? context.colors.primary : context.colors.surface,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(
          color: filled ? context.colors.primary : context.semantic.subtleBorder,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          // A third of a phone is not wide enough to promise a four-figure
          // number will fit, and a truncated count reads as a wrong one.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                color: foreground,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          Text(
            caption,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: context.text.labelMedium?.copyWith(
              color: filled
                  ? context.colors.onPrimary.withValues(alpha: 0.88)
                  : context.semantic.mutedText,
            ),
          ),
        ],
      ),
    );
  }
}

/// One class on the Today list: colour bar, name, the quiet detail line, the
/// coloured facts, then the chevron.
class _ClassRow extends StatelessWidget {
  const _ClassRow({required this.summary, required this.onTap});

  final ClassSummary summary;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final String detail = <String>[
      if (summary.schoolClass.subtitle.isNotEmpty) summary.schoolClass.subtitle,
      Format.plural(summary.studentCount, 'student'),
    ].join(' · ');

    return _BarCard(
      accent: AppColors.classColors(summary.schoolClass.colorSeed).first,
      onTap: onTap,
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  summary.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
                const SizedBox(height: AppSpacing.sm),
                _TodayFacts(summary: summary),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right_rounded,
            applyTextScaling: true,
            color: context.semantic.mutedText,
          ),
        ],
      ),
    );
  }
}

/// The small line under a class: where today stands, then its record so far.
class _TodayFacts extends StatelessWidget {
  const _TodayFacts({required this.summary});

  final ClassSummary summary;

  @override
  Widget build(BuildContext context) {
    final (String status, Color color) = summary.studentCount == 0
        ? ('No students', context.semantic.mutedText)
        : summary.markedToday
            ? ('Marked', context.semantic.success)
            : ('To mark', context.colors.primary);

    final TextStyle? muted =
        context.text.labelMedium?.copyWith(color: context.semantic.mutedText);

    return Text.rich(
      TextSpan(
        children: <InlineSpan>[
          TextSpan(
            text: status,
            style: context.text.labelMedium
                ?.copyWith(color: color, fontWeight: FontWeight.w700),
          ),
          if (summary.attendance.hasData)
            TextSpan(
              text:
                  ' · ${Format.percentOrDash(summary.attendance.percentage, decimals: 0)} attendance',
              style: muted,
            ),
          if (summary.lastSessionDate != null)
            TextSpan(
              text: ' · Last ${AppDate.formatShort(summary.lastSessionDate!)}',
              style: muted,
            ),
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}

// -----------------------------------------------------------------------------
// History
// -----------------------------------------------------------------------------

class _HistoryView extends StatelessWidget {
  const _HistoryView({required this.classes, required this.onRefresh});

  final List<ClassSummary> classes;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final List<ClassSummary> recorded = classes
        .where((ClassSummary c) => c.sessionCount > 0 || c.attendance.hasData)
        .toList();
    final AttendanceSummary total = AttendanceSummary.combine(
      classes.map((ClassSummary c) => c.attendance),
    );
    final int sessions = classes.fold<int>(
      0,
      (int running, ClassSummary c) => running + c.sessionCount,
    );

    return AppPageBody(
      onRefresh: onRefresh,
      children: <Widget>[
        _HistoryFigures(sessions: sessions, summary: total),
        const Gap.xl(),
        if (recorded.isEmpty)
          const EmptyView(
            compact: true,
            icon: Icons.event_busy_outlined,
            title: 'No attendance yet',
            message: 'Registers you take are summarised here, class by class.',
          )
        else ...<Widget>[
          const SectionHeader(
            title: 'By class',
            subtitle: 'Tap a class for every session it has',
          ),
          for (final ClassSummary summary in recorded)
            _HistoryRow(summary: summary),
          const Gap.lg(),
        ],
        OutlinedButton.icon(
          onPressed: () =>
              Navigator.of(context).pushNamed(Routes.attendanceHistory),
          icon: const Icon(Icons.tune_rounded, size: 20),
          label: const Text('Search and filter every session'),
        ),
        const Gap.xxl(),
      ],
    );
  }
}

/// Four figures across one card — the shape the prototype opens History with.
class _HistoryFigures extends StatelessWidget {
  const _HistoryFigures({required this.sessions, required this.summary});

  final int sessions;
  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Expanded(
            child: _Figure(value: Format.count(sessions), caption: 'Sessions'),
          ),
          Expanded(
            child: _Figure(
              value: Format.count(summary.present),
              caption: 'Present',
              color: context.semantic.success,
            ),
          ),
          Expanded(
            child: _Figure(
              value: Format.count(summary.absent),
              caption: 'Absent',
              color: context.semantic.danger,
            ),
          ),
          Expanded(
            child: _Figure(
              value: Format.percentOrDash(summary.percentage, decimals: 0),
              caption: 'Average',
              color: context.colors.primary,
            ),
          ),
        ],
      ),
    );
  }
}

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
        // number gets. Scaling one down beats ellipsising it.
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

/// One class's record: name, how many sessions, then P / A / L / S in colour.
class _HistoryRow extends StatelessWidget {
  const _HistoryRow({required this.summary});

  final ClassSummary summary;

  @override
  Widget build(BuildContext context) {
    final String detail = <String>[
      Format.plural(summary.sessionCount, 'session'),
      if (summary.lastSessionDate != null)
        'last ${AppDate.formatShort(summary.lastSessionDate!)}',
    ].join(' · ');

    return _BarCard(
      accent: AppColors.classColors(summary.schoolClass.colorSeed).first,
      onTap: () => Navigator.of(context).pushNamed(
        Routes.attendanceHistory,
        arguments: AttendanceHistoryArgs(classId: summary.id),
      ),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  summary.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: AppSpacing.xxs),
                Text(
                  detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
                const SizedBox(height: AppSpacing.sm),
                _MarkCounts(summary: summary.attendance),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Icon(
            Icons.chevron_right_rounded,
            applyTextScaling: true,
            color: context.semantic.mutedText,
          ),
        ],
      ),
    );
  }
}

/// `11 P  0 A  1 L  0 S`, each figure in its status colour.
///
/// On its own line rather than at the end of the name's line: four marks at
/// this type scale need more room than a phone leaves beside a class name, and
/// the alternative is shrinking the figures below the size this app reads at.
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
/// Drawn as a coloured card the white content sits on top of, so the bar is
/// exactly as tall as the row without an intrinsic-height pass measuring it.
///
/// Keeps the app's hairline border, which the rest of this screen's cards have.
/// The prototype separates its cards with a soft shadow on a lavender page;
/// this app's page is a 2% grey and has no shadow anywhere, so a white row
/// without the border has no edge at all.
class _BarCard extends StatelessWidget {
  const _BarCard({required this.accent, required this.child, this.onTap});

  final Color accent;
  final Widget child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: accent,
          borderRadius: AppRadii.cardRadius,
          border: Border.all(color: context.semantic.subtleBorder),
        ),
        padding: const EdgeInsets.only(left: AppSpacing.xs),
        child: Material(
          color: context.colors.surface,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.md,
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}
