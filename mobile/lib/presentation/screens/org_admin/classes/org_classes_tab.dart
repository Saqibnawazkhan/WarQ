import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/org_admin_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Every class in the organization, one row each.
class OrgClassesTab extends StatefulWidget {
  const OrgClassesTab({super.key});

  @override
  State<OrgClassesTab> createState() => _OrgClassesTabState();
}

class _OrgClassesTabState extends State<OrgClassesTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final OrgAdminController controller = context.watch<OrgAdminController>();
    final String needle = _query.trim().toLowerCase();

    final Map<String, String> teacherNames = <String, String>{
      for (final TeacherSnapshot snapshot in controller.teachers)
        snapshot.teacher.id: snapshot.teacher.displayName,
    };

    final List<SchoolClass> all = controller.classes;
    final List<SchoolClass> classes = all.where((SchoolClass c) {
      if (needle.isEmpty) return true;
      return c.name.toLowerCase().contains(needle) ||
          (c.subject?.toLowerCase().contains(needle) ?? false) ||
          (teacherNames[c.teacherId]?.toLowerCase().contains(needle) ?? false);
    }).toList();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: ContentWidth(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Classes',
                      style: context.text.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.w800),
                    ),
                    if (all.isNotEmpty) ...<Widget>[
                      const Gap.xs(),
                      Text(
                        _summaryLine(all),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    ],
                    const Gap.lg(),
                    SearchField(
                      hintText: 'Search classes, subjects or teachers',
                      onChanged: (String value) => setState(() => _query = value),
                    ),
                  ],
                ),
              ),
            ),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 4, itemHeight: 96),
                builder: (BuildContext context) {
                  if (all.isEmpty) {
                    return const EmptyView(
                      icon: Icons.class_outlined,
                      title: 'No classes yet',
                      message:
                          'Classes created by your teachers appear here '
                          'automatically.',
                    );
                  }
                  if (classes.isEmpty) {
                    return EmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message: 'No class matches "$_query".',
                      actionLabel: 'Clear search',
                      onAction: () => setState(() => _query = ''),
                    );
                  }
                  return RefreshIndicator(
                    onRefresh: controller.refresh,
                    child: ContentWidth(
                      child: ListView.separated(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        ),
                        itemCount: classes.length,
                        separatorBuilder: (_, __) => const Gap.md(),
                        itemBuilder: (BuildContext context, int index) {
                          final SchoolClass schoolClass = classes[index];
                          return _OrgClassCard(
                            key: ValueKey<String>(schoolClass.id),
                            schoolClass: schoolClass,
                            teacherName:
                                teacherNames[schoolClass.teacherId] ?? 'Teacher',
                          );
                        },
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// "9 classes across 5 teachers · Session 2026".
  ///
  /// The session is only named when every class agrees on one, because a single
  /// label over a mixed set would be wrong rather than merely vague.
  String _summaryLine(List<SchoolClass> all) {
    final int teachers =
        all.map((SchoolClass c) => c.teacherId).toSet().length;
    final Set<String> sessions = <String>{
      for (final SchoolClass c in all)
        if (c.session != null) c.session!,
    };
    final String line = '${Format.plural(all.length, 'class', 'classes')} '
        'across ${Format.plural(teachers, 'teacher')}';
    return sessions.length == 1 ? '$line · Session ${sessions.first}' : line;
  }
}

/// Resolves the class summary lazily so the tab does not block on analytics
/// for every class at once.
class _OrgClassCard extends StatefulWidget {
  const _OrgClassCard({
    super.key,
    required this.schoolClass,
    required this.teacherName,
  });

  final SchoolClass schoolClass;
  final String teacherName;

  @override
  State<_OrgClassCard> createState() => _OrgClassCardState();
}

class _OrgClassCardState extends State<_OrgClassCard> {
  ClassSummary? _summary;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final AppDependencies deps = context.read<AppDependencies>();
    final ClassSummary summary =
        await deps.analytics.classSummary(widget.schoolClass);
    if (!mounted) return;
    setState(() => _summary = summary);
  }

  @override
  Widget build(BuildContext context) {
    final SchoolClass schoolClass = widget.schoolClass;
    final ClassSummary? summary = _summary;
    final String? section = schoolClass.section;

    return AppCard(
      padding: EdgeInsets.zero,
      onTap: summary == null
          ? null
          : () => Navigator.of(context).pushNamed(
                Routes.orgClassDetail,
                arguments: ClassDetailArgs(classId: summary.id),
              ),
      child: ClipRRect(
        // Squares off the colour bar against the card's own corners.
        borderRadius: AppRadii.cardRadius,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Container(
                width: 4,
                color: AppColors.classColors(schoolClass.avatarKey).first,
              ),
              Expanded(
                child: Padding(
                  padding: AppSpacing.tilePadding,
                  child: Row(
                    children: <Widget>[
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              section == null
                                  ? schoolClass.name
                                  : '${schoolClass.name} · $section',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: AppSpacing.xxs),
                            Text(
                              summary == null
                                  ? widget.teacherName
                                  : '${widget.teacherName} · '
                                      '${Format.plural(summary.studentCount, 'student')}',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall
                                  ?.copyWith(color: context.semantic.mutedText),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      if (summary == null)
                        const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      else
                        _AttendanceFigure(percent: summary.attendance.percentage),
                    ],
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

/// The percentage and its caption, right-aligned at the end of a class row.
class _AttendanceFigure extends StatelessWidget {
  const _AttendanceFigure({required this.percent});

  final double? percent;

  @override
  Widget build(BuildContext context) {
    final Color color = switch (percent) {
      null => context.semantic.mutedText,
      final double p when p >= AppConstants.attendanceRiskThreshold =>
        context.semantic.success,
      final double p when p >= 50 => context.semantic.warning,
      _ => context.semantic.danger,
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Text(
          Format.percentOrDash(percent, decimals: 0),
          style: context.text.titleMedium
              ?.copyWith(fontWeight: FontWeight.w800, color: color),
        ),
        Text(
          'attendance',
          style: context.text.labelSmall
              ?.copyWith(color: context.semantic.mutedText),
        ),
      ],
    );
  }
}
