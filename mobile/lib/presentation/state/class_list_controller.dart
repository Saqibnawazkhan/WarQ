import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../data/repositories/class_repository.dart';
import '../../domain/entities/dashboard_data.dart';
import 'base_controller.dart';

/// Backs the teacher's class list: search, archive filter and CRUD.
class ClassListController extends BaseController {
  ClassListController(this._deps, this._teacher) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.classes,
      DataEntity.enrollments,
      DataEntity.attendance,
      DataEntity.assessments,
      DataEntity.marks,
    });
  }

  final AppDependencies _deps;
  final AppUser _teacher;

  List<ClassSummary> _all = const <ClassSummary>[];
  String _query = '';
  bool _showArchived = false;
  bool _alphabetical = false;

  String get query => _query;
  bool get showArchived => _showArchived;
  bool get alphabetical => _alphabetical;
  int get totalCount => _all.length;

  /// Classes after search and archive filtering.
  List<ClassSummary> get visible {
    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _all;
    return _all.where((ClassSummary summary) {
      final SchoolClass c = summary.schoolClass;
      return c.name.toLowerCase().contains(needle) ||
          (c.subject?.toLowerCase().contains(needle) ?? false) ||
          (c.section?.toLowerCase().contains(needle) ?? false) ||
          (c.session?.toLowerCase().contains(needle) ?? false);
    }).toList(growable: false);
  }

  bool get hasResults => visible.isNotEmpty;
  bool get isFiltering => _query.trim().isNotEmpty;

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        final List<SchoolClass> classes = await _deps.classes.listForTeacher(
          _teacher.id,
          includeArchived: _showArchived,
          alphabetical: _alphabetical,
        );
        _all = <ClassSummary>[
          for (final SchoolClass schoolClass in classes)
            await _deps.analytics.classSummary(schoolClass),
        ];
      },
      refreshing: refreshing,
      isEmptyResult: () => _all.isEmpty,
    );
  }

  void search(String value) {
    if (_query == value) return;
    _query = value;
    safeNotify();
  }

  Future<void> setShowArchived(bool value) async {
    if (_showArchived == value) return;
    _showArchived = value;
    await load(refreshing: true);
  }

  Future<void> setAlphabetical(bool value) async {
    if (_alphabetical == value) return;
    _alphabetical = value;
    await load(refreshing: true);
  }

  Future<SchoolClass?> createClass(ClassDraft draft) {
    return guardAction<SchoolClass>(
      () => _deps.classes.create(
        teacherId: _teacher.id,
        draft: draft,
        organizationId: _teacher.organizationId,
      ),
    );
  }

  Future<SchoolClass?> updateClass(String classId, ClassDraft draft) {
    return guardAction<SchoolClass>(() => _deps.classes.update(classId, draft));
  }

  Future<bool> deleteClass(String classId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.classes.delete(classId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> setArchived(String classId, bool archived) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.classes.setArchived(classId, archived);
      return true;
    });
    return ok ?? false;
  }
}
