import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../domain/services/report_service.dart';
import 'base_controller.dart';

/// Backs the reports hub: pick a class (and optionally a student), then
/// generate, preview, share, print or save the PDF.
class ReportsController extends BaseController {
  ReportsController(this._deps, this._teacher) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.classes,
      DataEntity.enrollments,
      DataEntity.students,
    });
  }

  final AppDependencies _deps;
  final AppUser _teacher;

  List<SchoolClass> _classes = const <SchoolClass>[];
  List<Student> _roster = const <Student>[];
  String? _selectedClassId;
  String _studentQuery = '';
  GeneratedReport? _lastReport;
  String? _lastSavedPath;

  List<SchoolClass> get classes => _classes;
  List<Student> get roster => _roster;
  String? get selectedClassId => _selectedClassId;
  String get studentQuery => _studentQuery;
  GeneratedReport? get lastReport => _lastReport;
  String? get lastSavedPath => _lastSavedPath;

  SchoolClass? get selectedClass {
    final String? id = _selectedClassId;
    if (id == null) return null;
    for (final SchoolClass schoolClass in _classes) {
      if (schoolClass.id == id) return schoolClass;
    }
    return null;
  }

  List<Student> get visibleStudents {
    final String needle = _studentQuery.trim().toLowerCase();
    if (needle.isEmpty) return _roster;
    return _roster
        .where((Student s) =>
            s.fullName.toLowerCase().contains(needle) ||
            (s.rollNumber?.toLowerCase().contains(needle) ?? false))
        .toList(growable: false);
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _classes = await _deps.classes.listForTeacher(
          _teacher.id,
          alphabetical: true,
        );
        _selectedClassId ??= _classes.isEmpty ? null : _classes.first.id;
        _roster = _selectedClassId == null
            ? const <Student>[]
            : await _deps.students.listForClass(_selectedClassId!);
      },
      refreshing: refreshing,
      isEmptyResult: () => _classes.isEmpty,
    );
  }

  Future<void> selectClass(String classId) async {
    if (_selectedClassId == classId) return;
    _selectedClassId = classId;
    _lastReport = null;
    _lastSavedPath = null;
    await load(refreshing: true);
  }

  void searchStudents(String value) {
    if (_studentQuery == value) return;
    _studentQuery = value;
    safeNotify();
  }

  Future<GeneratedReport?> generateClassReport([String? classId]) async {
    final String? id = classId ?? _selectedClassId;
    if (id == null) return null;
    final GeneratedReport? report = await guardAction<GeneratedReport>(
      () => _deps.reports.classReport(classId: id, teacher: _teacher),
    );
    if (report != null) {
      _lastReport = report;
      _lastSavedPath = null;
      safeNotify();
    }
    return report;
  }

  Future<GeneratedReport?> generateStudentReport(
    String studentId, {
    String? classId,
  }) async {
    final GeneratedReport? report = await guardAction<GeneratedReport>(
      () => _deps.reports.studentReport(
        studentId: studentId,
        teacher: _teacher,
        classId: classId ?? _selectedClassId,
      ),
    );
    if (report != null) {
      _lastReport = report;
      _lastSavedPath = null;
      safeNotify();
    }
    return report;
  }

  Future<bool> share(GeneratedReport report) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.reports.share(report);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> printReport(GeneratedReport report) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.reports.printDocument(report);
      return true;
    });
    return ok ?? false;
  }

  Future<String?> saveToDevice(GeneratedReport report) async {
    final String? path = await guardAction<String>(
      () => _deps.reports.saveToDevice(report),
    );
    if (path != null) {
      _lastSavedPath = path;
      safeNotify();
    }
    return path;
  }
}
