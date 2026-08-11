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
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/class_list_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/domain/class_grid_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Attendance hub: pick a class to mark today, or open the full history.
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

class _AttendanceHubView extends StatelessWidget {
  const _AttendanceHubView();

  @override
  Widget build(BuildContext context) {
    final ClassListController controller = context.watch<ClassListController>();
    final List<ClassSummary> classes = controller.visible;
    final List<ClassSummary> pending = classes
        .where((ClassSummary c) => !c.markedToday && c.studentCount > 0)
        .toList();
    final List<ClassSummary> done =
        classes.where((ClassSummary c) => c.markedToday).toList();
    final List<ClassSummary> empty =
        classes.where((ClassSummary c) => c.studentCount == 0).toList();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Attendance'),
        actions: <Widget>[
          IconButton(
            tooltip: 'Attendance history',
            onPressed: () =>
                Navigator.of(context).pushNamed(Routes.attendanceHistory),
            icon: const Icon(Icons.history_rounded),
          ),
        ],
      ),
      body: SafeArea(
        bottom: false,
        child: ControllerStateView(
          controller: controller,
          loading: const SkeletonList(itemCount: 4, itemHeight: 130),
          empty: EmptyView(
            icon: Icons.how_to_reg_outlined,
            title: 'Nothing to mark yet',
            message: 'Create a class and add students to start taking attendance.',
            actionLabel: 'Create a class',
            onAction: () => Navigator.of(context).pushNamed(Routes.classForm),
          ),
          builder: (BuildContext context) => AppPageBody(
            onRefresh: controller.refresh,
            children: <Widget>[
              _TodayHeader(pending: pending.length, marked: done.length),
              const Gap.xl(),
              OutlinedButton.icon(
                onPressed: () =>
                    Navigator.of(context).pushNamed(Routes.attendanceHistory),
                icon: const Icon(Icons.history_rounded, size: 20),
                label: const Text('View attendance history'),
              ),
              const Gap.xl(),
              if (pending.isNotEmpty) ...<Widget>[
                SectionHeader(
                  title: 'Pending today',
                  subtitle: AppDate.formatLong(DateTime.now()),
                ),
                _ClassGrid(
                  classes: pending,
                  onTap: (ClassSummary summary) => _mark(context, summary),
                ),
                const Gap.lg(),
              ],
              if (done.isNotEmpty) ...<Widget>[
                const SectionHeader(
                  title: 'Marked today',
                  subtitle: 'Tap to review or edit',
                ),
                _ClassGrid(
                  classes: done,
                  onTap: (ClassSummary summary) => _mark(context, summary),
                  statusIcon: Icons.check_circle_rounded,
                ),
                const Gap.lg(),
              ],
              if (empty.isNotEmpty) ...<Widget>[
                const SectionHeader(
                  title: 'Waiting for students',
                  subtitle: 'Add students before taking attendance',
                ),
                _ClassGrid(
                  classes: empty,
                  onTap: (ClassSummary summary) => Navigator.of(context).pushNamed(
                    Routes.classDetail,
                    arguments: ClassDetailArgs(classId: summary.id),
                  ),
                ),
              ],
              const Gap.xxl(),
            ],
          ),
        ),
      ),
    );
  }

  void _mark(BuildContext context, ClassSummary summary) {
    Navigator.of(context).pushNamed(
      Routes.markAttendance,
      arguments: MarkAttendanceArgs(classId: summary.id),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({required this.pending, required this.marked});

  final int pending;
  final int marked;

  @override
  Widget build(BuildContext context) {
    final int total = pending + marked;
    final bool allDone = pending == 0 && marked > 0;

    return AppCard(
      color: allDone
          ? context.semantic.successContainer
          : context.colors.surface,
      borderColor: allDone
          ? context.semantic.success.withValues(alpha: 0.35)
          : null,
      child: Row(
        children: <Widget>[
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(
              color: (allDone
                      ? context.semantic.success
                      : context.colors.primary)
                  .withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(AppRadii.sm),
            ),
            child: Icon(
              allDone ? Icons.task_alt_rounded : Icons.today_rounded,
              color:
                  allDone ? context.semantic.success : context.colors.primary,
            ),
          ),
          const SizedBox(width: AppSpacing.lg),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  allDone
                      ? 'All attendance taken'
                      : '${Format.plural(pending, 'class', 'classes')} pending',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 2),
                Text(
                  total == 0
                      ? AppDate.formatLong(DateTime.now())
                      : '$marked of $total marked · '
                          '${AppDate.formatLong(DateTime.now())}',
                  style: context.text.bodySmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The same coloured tiles the Classes tab uses, laid out in a grid.
///
/// Nested inside the page's own scroll view, so it never scrolls itself: a
/// section here holds a handful of classes, and a second scrolling area inside
/// the first is a way to lose them.
class _ClassGrid extends StatelessWidget {
  const _ClassGrid({required this.classes, required this.onTap, this.statusIcon});

  final List<ClassSummary> classes;
  final void Function(ClassSummary summary) onTap;
  final IconData? statusIcon;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        for (final ClassSummary summary in classes)
          Padding(
            padding: const EdgeInsets.only(bottom: AppSpacing.md),
            child: ClassGridTile(
              summary: summary,
              wide: true,
              onTap: () => onTap(summary),
              statusIcon: statusIcon,
            ),
          ),
      ],
    );
  }
}