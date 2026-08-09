import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../state/session_controller.dart';
import '../../../state/student_search_controller.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/domain/student_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Search every student the teacher owns, across all classes.
class StudentSearchScreen extends StatelessWidget {
  const StudentSearchScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser teacher = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<StudentSearchController>(
      create: (BuildContext context) =>
          StudentSearchController(context.read<AppDependencies>(), teacher)
            ..load(),
      child: const _StudentSearchView(),
    );
  }
}

class _StudentSearchView extends StatelessWidget {
  const _StudentSearchView();

  @override
  Widget build(BuildContext context) {
    final StudentSearchController controller =
        context.watch<StudentSearchController>();
    final Map<String, List<StudentSearchResult>> grouped = controller.grouped;

    return Scaffold(
      appBar: AppBar(title: const Text('All students')),
      body: SafeArea(
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
                  autofocus: true,
                  hintText: 'Search by name, roll number, phone or class',
                  onChanged: controller.search,
                ),
              ),
            ),
            Expanded(
              child: ControllerStateView(
                controller: controller,
                loading: const SkeletonList(itemCount: 6, itemHeight: 64),
                empty: const EmptyView(
                  icon: Icons.people_outline_rounded,
                  title: 'No students yet',
                  message:
                      'Students you add to any class will be searchable here.',
                ),
                builder: (BuildContext context) {
                  if (controller.results.isEmpty) {
                    return EmptyView(
                      icon: Icons.search_off_rounded,
                      title: 'No matches',
                      message:
                          'No student matches "${controller.query}". Try another '
                          'name, roll number or phone number.',
                    );
                  }
                  return ContentWidth(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.lg,
                        0,
                        AppSpacing.lg,
                        AppSpacing.xxl,
                      ),
                      children: <Widget>[
                        Text(
                          '${Format.plural(controller.results.length, 'student')} '
                          'of ${controller.totalCount}',
                          style: context.text.labelSmall
                              ?.copyWith(color: context.semantic.mutedText),
                        ),
                        for (final MapEntry<String, List<StudentSearchResult>> entry
                            in grouped.entries) ...<Widget>[
                          AlphabetHeader(
                            letter: entry.key,
                            count: entry.value.length,
                          ),
                          for (final StudentSearchResult result in entry.value)
                            StudentPickerTile(
                              student: result.student,
                              subtitle: result.classNames.isEmpty
                                  ? 'Not enrolled in any class'
                                  : result.classNames.join(' · '),
                              trailing: const Icon(Icons.chevron_right_rounded),
                              onTap: () => Navigator.of(context).pushNamed(
                                Routes.studentDetail,
                                arguments: StudentDetailArgs(
                                  studentId: result.student.id,
                                  classId: result.primaryClassId,
                                ),
                              ),
                            ),
                        ],
                      ],
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
}
