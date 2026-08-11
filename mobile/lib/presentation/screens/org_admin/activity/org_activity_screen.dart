import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../data/models/models.dart';
import '../../../state/base_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/domain/activity_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// The slices of the feed an admin actually looks for.
enum _ActivityFilter {
  all('All'),
  attendance('Attendance'),
  marks('Marks'),
  alerts('Alerts');

  const _ActivityFilter(this.label);

  final String label;

  bool matches(ActivityLog log) => switch (this) {
        _ActivityFilter.all => true,
        _ActivityFilter.attendance => const <ActivityType>{
            ActivityType.attendanceMarked,
            ActivityType.attendanceUpdated,
          }.contains(log.type),
        _ActivityFilter.marks => const <ActivityType>{
            ActivityType.marksEntered,
            ActivityType.marksUpdated,
            ActivityType.assessmentCreated,
            ActivityType.assessmentUpdated,
          }.contains(log.type),
        // Everything that removed something a teacher was relying on.
        _ActivityFilter.alerts => const <ActivityType>{
            ActivityType.classDeleted,
            ActivityType.studentRemoved,
            ActivityType.studentUnenrolled,
            ActivityType.assessmentDeleted,
            ActivityType.teacherRemoved,
            ActivityType.invitationRevoked,
          }.contains(log.type),
      };
}

/// Full organization activity log, grouped by day.
class OrgActivityScreen extends StatefulWidget {
  const OrgActivityScreen({super.key});

  @override
  State<OrgActivityScreen> createState() => _OrgActivityScreenState();
}

class _OrgActivityScreenState extends State<OrgActivityScreen> {
  List<ActivityLog> _logs = const <ActivityLog>[];
  bool _loading = true;
  String? _error;
  _ActivityFilter _filter = _ActivityFilter.all;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });

    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser admin = context.read<SessionController>().requireUser;
    final String? organizationId = admin.organizationId;

    try {
      final List<ActivityLog> logs = organizationId == null
          ? const <ActivityLog>[]
          : await deps.activity.listForOrganization(organizationId, limit: 200);
      if (!mounted) return;
      setState(() {
        _logs = logs;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = BaseController.describeFailure(error);
        _loading = false;
      });
    }
  }

  Map<String, List<ActivityLog>> _groupByDay(List<ActivityLog> logs) {
    final Map<String, List<ActivityLog>> grouped = <String, List<ActivityLog>>{};
    for (final ActivityLog log in logs) {
      grouped
          .putIfAbsent(AppDate.relativeDay(log.createdAt), () => <ActivityLog>[])
          .add(log);
    }
    return grouped;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Activity')),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_loading) return const LoadingView();
            if (_error != null) {
              return ErrorView(message: _error!, onRetry: _load);
            }
            if (_logs.isEmpty) {
              return const EmptyView(
                icon: Icons.history_rounded,
                title: 'No activity yet',
                message:
                    'Everything your teachers do — classes, attendance, marks '
                    'and reports — is logged here.',
              );
            }

            final List<ActivityLog> visible =
                _logs.where(_filter.matches).toList();

            return Column(
              children: <Widget>[
                // Outside the list: a filter that hides its own control when it
                // empties the page would trap the admin on a blank screen.
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                  ),
                  child: ContentWidth(
                    child: Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        for (final _ActivityFilter filter
                            in _ActivityFilter.values)
                          _FilterChip(
                            label: filter.label,
                            selected: filter == _filter,
                            onTap: () => setState(() => _filter = filter),
                          ),
                      ],
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? EmptyView(
                          icon: Icons.filter_alt_off_outlined,
                          title: 'Nothing here yet',
                          message:
                              'No ${_filter.label.toLowerCase()} activity has '
                              'been logged.',
                          actionLabel: 'Show all activity',
                          onAction: () =>
                              setState(() => _filter = _ActivityFilter.all),
                        )
                      : RefreshIndicator(
                          onRefresh: _load,
                          child: ContentWidth(
                            child: ListView(
                              padding: const EdgeInsets.fromLTRB(
                                AppSpacing.lg,
                                0,
                                AppSpacing.lg,
                                AppSpacing.lg,
                              ),
                              children: <Widget>[
                                for (final MapEntry<String, List<ActivityLog>>
                                    entry in _groupByDay(visible).entries) ...<Widget>[
                                  Padding(
                                    padding: const EdgeInsets.only(
                                      top: AppSpacing.md,
                                      bottom: AppSpacing.md,
                                    ),
                                    child: Text(
                                      entry.key,
                                      style: context.text.labelLarge?.copyWith(
                                        color: context.semantic.mutedText,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                  ),
                                  AppCard(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: AppSpacing.lg,
                                      vertical: AppSpacing.sm,
                                    ),
                                    child: Column(
                                      children: <Widget>[
                                        for (final ActivityLog log in entry.value)
                                          _ActivityRow(log: log),
                                      ],
                                    ),
                                  ),
                                ],
                                const Gap.xxl(),
                              ],
                            ),
                          ),
                        ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? context.colors.primary : context.colors.surface,
      borderRadius: BorderRadius.circular(AppRadii.pill),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadii.pill),
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.lg,
            vertical: AppSpacing.sm,
          ),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.pill),
            border: selected
                ? null
                : Border.all(color: context.semantic.subtleBorder),
          ),
          child: Text(
            label,
            style: context.text.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: selected
                  ? context.colors.onPrimary
                  : context.semantic.mutedText,
            ),
          ),
        ),
      ),
    );
  }
}

/// One logged action: a coloured dot, what happened, who did it, and when.
class _ActivityRow extends StatelessWidget {
  const _ActivityRow({required this.log});

  final ActivityLog log;

  @override
  Widget build(BuildContext context) {
    final String detail = <String>[
      if (log.actorName != null) log.actorName!,
      if (log.detail != null) log.detail!,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            width: 10,
            height: 10,
            // Nudged down onto the first line of the summary beside it.
            margin: const EdgeInsets.only(top: AppSpacing.xs + 2),
            decoration: BoxDecoration(
              color: ActivityTile.colorFor(context, log.type),
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  log.summary,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                if (detail.isNotEmpty) ...<Widget>[
                  const SizedBox(height: AppSpacing.xxs),
                  Text(
                    detail,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Text(
            AppDate.formatTime(log.createdAt),
            style: context.text.labelMedium
                ?.copyWith(color: context.semantic.mutedText),
          ),
        ],
      ),
    );
  }
}
