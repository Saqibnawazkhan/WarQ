import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import 'base_controller.dart';

/// A student paired with the classes they belong to.
class StudentSearchResult {
  const StudentSearchResult({
    required this.student,
    required this.classNames,
    required this.primaryClassId,
  });

  final Student student;
  final List<String> classNames;

  /// Used when opening the profile so it can be scoped to a class.
  final String? primaryClassId;
}

/// Backs the cross-class student search screen.
class StudentSearchController extends BaseController {
  StudentSearchController(this._deps, this._teacher) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.students,
      DataEntity.enrollments,
      DataEntity.classes,
    });
  }

  final AppDependencies _deps;
  final AppUser _teacher;

  List<StudentSearchResult> _all = const <StudentSearchResult>[];
  String _query = '';

  String get query => _query;
  int get totalCount => _all.length;

  /// A–Z results filtered by name, roll number or any phone number.
  List<StudentSearchResult> get results {
    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _all;
    return _all.where((StudentSearchResult result) {
      final Student s = result.student;
      return s.fullName.toLowerCase().contains(needle) ||
          (s.rollNumber?.toLowerCase().contains(needle) ?? false) ||
          (s.email?.toLowerCase().contains(needle) ?? false) ||
          (s.studentPhone?.contains(needle) ?? false) ||
          (s.fatherPhone?.contains(needle) ?? false) ||
          (s.motherPhone?.contains(needle) ?? false) ||
          result.classNames
              .any((String name) => name.toLowerCase().contains(needle));
    }).toList(growable: false);
  }

  /// Results grouped under their first letter, matching the class roster.
  Map<String, List<StudentSearchResult>> get grouped {
    final Map<String, List<StudentSearchResult>> map =
        <String, List<StudentSearchResult>>{};
    for (final StudentSearchResult result in results) {
      map
          .putIfAbsent(result.student.sectionLetter, () => <StudentSearchResult>[])
          .add(result);
    }
    return map;
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        final List<Student> students =
            await _deps.students.listForTeacher(_teacher.id);
        final List<SchoolClass> classes = await _deps.classes.listForTeacher(
          _teacher.id,
          includeArchived: true,
        );
        final Map<String, SchoolClass> classById = <String, SchoolClass>{
          for (final SchoolClass c in classes) c.id: c,
        };

        final List<StudentSearchResult> results = <StudentSearchResult>[];
        for (final Student student in students) {
          final List<String> classIds =
              await _deps.students.classIdsFor(student.id);
          results.add(
            StudentSearchResult(
              student: student,
              classNames: <String>[
                for (final String id in classIds)
                  if (classById[id] != null) classById[id]!.name,
              ]..sort(),
              primaryClassId: classIds.isEmpty ? null : classIds.first,
            ),
          );
        }
        _all = results;
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
}
