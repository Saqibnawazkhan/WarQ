import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/dashboard_data.dart';
import '../../../state/org_admin_controller.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/domain/class_card.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Every class in the organization, grouped by teacher.
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

    final List<TeacherSnapshot> teachers = controller.teachers;
    final Map<String, String> teacherNames = <String, String>{
      for (final TeacherSnapshot snapshot in teachers)
        snapshot.teacher.id: snapshot.teacher.displayName,
    };

    final List<SchoolClass> classes = controller.classes.where((SchoolClass c) {
      if (needle.isEmpty) return true;
      return c.name.toLowerCase().contains(needle) ||
          (c.subject?.toLowerCase().contains(needle) ?? false) ||
          (teacherNames[c.teacherId]?.toLowerCase().contains(needle) ?? false);
    }).toList();

    final Map<String, List<SchoolClass>> byTeacher = <String, List<SchoolClass>>{};
    for (final SchoolClass schoolClass in classes) {
      byTeacher
          .putIfAbsent(schoolClass.teacherId, () => <SchoolClass>[])
          .add(schoolClass);
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Classes')),
      body: SafeArea(
        bottom: false,
        child: Column(
          children: <Widget>[
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.lg,
                AppSpacing.sm,
                AppSpacing.lg,
                AppSpacing.md,
              ),
              child: ContentWidth(
                child: SearchField(
                  hintText: 'Search classes, subjects or teachers',
                  onChanged: (String value) => setState(() => _query = value),
                ),
              ),
            ),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 4, itemHeight: 120),
                builder: (BuildContext context) {
                  if (controller.classes.isEmpty) {
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
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.lg,
                          0,
                          AppSpacing.lg,
                          AppSpacing.xxl,
                        ),
                        children: <Widget>[
                          for (final MapEntry<String, List<SchoolClass>> entry
                              in byTeacher.entries) ...<Widget>[
                            _TeacherGroupHeader(
                              teacherId: entry.key,
                              name: teacherNames[entry.key] ?? 'Teacher',
                              classCount: entry.value.length,
                            ),
                            for (final SchoolClass schoolClass in entry.value)
                              Padding(
                                padding:
                                    const EdgeInsets.only(bottom: AppSpacing.md),
                                child: _OrgClassCard(
                                  schoolClass: schoolClass,
                                  snapshot: _snapshotFor(teachers, entry.key),
                                ),
                              ),
                          ],
                        ],
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

  TeacherSnapshot? _snapshotFor(List<TeacherSnapshot> teachers, String id) {
    for (final TeacherSnapshot snapshot in teachers) {
      if (snapshot.teacher.id == id) return snapshot;
    }
    return null;
  }
}

class _TeacherGroupHeader extends StatelessWidget {
  const _TeacherGroupHeader({
    required this.teacherId,
    required this.name,
    required this.classCount,
  });

  final String teacherId;
  final String name;
  final int classCount;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(
        top: AppSpacing.md,
        bottom: AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          AppAvatar(name: name, seed: teacherId, size: 32),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Text(
              name,
              style: context.text.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          Text(
            Format.plural(classCount, 'class', 'classes'),
            style: context.text.labelSmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pushNamed(
              Routes.orgTeacherDetail,
              arguments: TeacherDetailArgs(teacherId: teacherId),
            ),
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: const Text('View'),
          ),
        ],
      ),
    );
  }
}

/// Resolves the class summary lazily so the tab does not block on analytics
/// for every class at once.
class _OrgClassCard extends StatefulWidget {
  const _OrgClassCard({required this.schoolClass, this.snapshot});

  final SchoolClass schoolClass;
  final TeacherSnapshot? snapshot;

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
    final ClassSummary? summary = _summary;
    if (summary == null) {
      return AppCard(
        child: Row(
          children: <Widget>[
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(strokeWidth: 2),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(widget.schoolClass.name, style: context.text.titleSmall),
          ],
        ),
      );
    }

    return ClassCard(
      summary: summary,
      onTap: () => Navigator.of(context).pushNamed(
        Routes.orgClassDetail,
        arguments: ClassDetailArgs(classId: summary.id),
      ),
    );
  }
}
