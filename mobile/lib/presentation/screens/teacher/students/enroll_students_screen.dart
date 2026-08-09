import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../state/base_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/search_field.dart';
import '../../../widgets/domain/student_tile.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Enroll students that already exist in the teacher's account into a class.
///
/// Because students are owned by the teacher rather than by a class, the same
/// person can be taught in several classes without re-entering their details.
class EnrollStudentsScreen extends StatefulWidget {
  const EnrollStudentsScreen({super.key, required this.args});

  final EnrollStudentsArgs args;

  @override
  State<EnrollStudentsScreen> createState() => _EnrollStudentsScreenState();
}

class _EnrollStudentsScreenState extends State<EnrollStudentsScreen> {
  final Set<String> _selected = <String>{};
  List<Student> _candidates = const <Student>[];
  String _query = '';
  bool _loading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  Future<void> _load() async {
    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser teacher = context.read<SessionController>().requireUser;
    try {
      final List<Student> mine = await deps.students.listForTeacher(teacher.id);
      final List<String> enrolledIds = <String>[];
      for (final Student student in mine) {
        final List<String> classIds =
            await deps.students.classIdsFor(student.id);
        if (classIds.contains(widget.args.classId)) enrolledIds.add(student.id);
      }
      if (!mounted) return;
      setState(() {
        _candidates = mine
            .where((Student s) => !enrolledIds.contains(s.id))
            .toList(growable: false);
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

  List<Student> get _visible {
    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _candidates;
    return _candidates
        .where((Student s) =>
            s.fullName.toLowerCase().contains(needle) ||
            (s.rollNumber?.toLowerCase().contains(needle) ?? false))
        .toList(growable: false);
  }

  Future<void> _enroll() async {
    if (_selected.isEmpty) return;
    setState(() => _saving = true);

    final AppDependencies deps = context.read<AppDependencies>();
    try {
      for (final String studentId in _selected) {
        await deps.students.enroll(
          classId: widget.args.classId,
          studentId: studentId,
        );
      }
      if (!mounted) return;
      final int count = _selected.length;
      Navigator.of(context).pop(true);
      context.showSuccess(
        '${Format.plural(count, 'student')} enrolled in ${widget.args.className}.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = BaseController.describeFailure(error);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Student> visible = _visible;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Enroll students'),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(28),
          child: Padding(
            padding: const EdgeInsets.only(
              left: AppSpacing.lg,
              bottom: AppSpacing.md,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Into ${widget.args.className}',
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ),
          ),
        ),
      ),
      bottomNavigationBar: _selected.isEmpty
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton.icon(
                  onPressed: _saving ? null : _enroll,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Icon(Icons.group_add_rounded),
                  label: Text(
                    'Enroll ${Format.plural(_selected.length, 'student')}',
                  ),
                ),
              ),
            ),
      body: SafeArea(
        child: Builder(
          builder: (BuildContext context) {
            if (_loading) return const LoadingView();
            if (_error != null) {
              return ErrorView(message: _error!, onRetry: _load);
            }
            if (_candidates.isEmpty) {
              return EmptyView(
                icon: Icons.person_search_outlined,
                title: 'No other students',
                message:
                    'Every student in your account is already enrolled in this '
                    'class. Add a new student instead.',
                actionLabel: 'Add a new student',
                onAction: () {
                  Navigator.of(context).pop();
                  Navigator.of(context).pushNamed(
                    Routes.studentForm,
                    arguments: StudentFormArgs(classId: widget.args.classId),
                  );
                },
              );
            }

            return Column(
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
                      hintText: 'Search your students',
                      onChanged: (String value) =>
                          setState(() => _query = value),
                    ),
                  ),
                ),
                Expanded(
                  child: visible.isEmpty
                      ? const EmptyView(
                          icon: Icons.search_off_rounded,
                          title: 'No matches',
                          message: 'Try a different search term.',
                        )
                      : ContentWidth(
                          child: ListView.builder(
                            padding: const EdgeInsets.fromLTRB(
                              AppSpacing.lg,
                              0,
                              AppSpacing.lg,
                              AppSpacing.xxl,
                            ),
                            itemCount: visible.length,
                            itemBuilder: (BuildContext context, int index) {
                              final Student student = visible[index];
                              final bool selected = _selected.contains(student.id);
                              return StudentPickerTile(
                                student: student,
                                selected: selected,
                                onTap: () => setState(() {
                                  if (!_selected.remove(student.id)) {
                                    _selected.add(student.id);
                                  }
                                }),
                              );
                            },
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
