import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../domain/entities/dashboard_data.dart';
import 'base_controller.dart';

/// Backs the teacher's cross-class assessment list.
class AssessmentListController extends BaseController {
  AssessmentListController(this._deps, this._teacher) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.assessments,
      DataEntity.marks,
      DataEntity.classes,
      DataEntity.enrollments,
    });
  }

  final AppDependencies _deps;
  final AppUser _teacher;

  List<AssessmentSummary> _all = const <AssessmentSummary>[];
  List<SchoolClass> _classes = const <SchoolClass>[];
  String? _classFilter;
  String _query = '';
  bool _pendingOnly = false;

  List<SchoolClass> get classes => _classes;
  String? get classFilter => _classFilter;
  String get query => _query;
  bool get pendingOnly => _pendingOnly;
  int get totalCount => _all.length;

  int get pendingCount =>
      _all.where((AssessmentSummary s) => !s.isFullyGraded).length;

  List<AssessmentSummary> get visible {
    final String needle = _query.trim().toLowerCase();
    return _all.where((AssessmentSummary summary) {
      if (_classFilter != null && summary.assessment.classId != _classFilter) {
        return false;
      }
      if (_pendingOnly && summary.isFullyGraded) return false;
      if (needle.isEmpty) return true;
      return summary.assessment.name.toLowerCase().contains(needle) ||
          summary.assessment.typeLabel.toLowerCase().contains(needle) ||
          summary.className.toLowerCase().contains(needle);
    }).toList(growable: false);
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _classes = await _deps.classes.listForTeacher(
          _teacher.id,
          alphabetical: true,
        );

        final List<AssessmentSummary> summaries = <AssessmentSummary>[];
        for (final SchoolClass schoolClass in _classes) {
          final List<Assessment> assessments =
              await _deps.assessments.listForClass(schoolClass.id);
          if (assessments.isEmpty) continue;

          final List<Student> roster =
              await _deps.students.listForClass(schoolClass.id);
          final Map<String, int> graded = await _deps.assessments.gradedCounts(
            assessments.map((Assessment a) => a.id),
          );
          final List<AssessmentMark> marks =
              await _deps.assessments.marksForClass(schoolClass.id);

          for (final Assessment assessment in assessments) {
            summaries.add(
              AssessmentSummary(
                assessment: assessment,
                className: schoolClass.name,
                gradedCount: graded[assessment.id] ?? 0,
                studentCount: roster.length,
                averagePercentage: _deps.grading.average(
                  marks
                      .where((AssessmentMark m) => m.assessmentId == assessment.id)
                      .map((AssessmentMark m) =>
                          m.percentageOf(assessment.totalMarks)),
                ),
              ),
            );
          }
        }

        summaries.sort((AssessmentSummary a, AssessmentSummary b) =>
            b.assessment.date.compareTo(a.assessment.date));
        _all = summaries;
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

  void setClassFilter(String? classId) {
    if (_classFilter == classId) return;
    _classFilter = classId;
    safeNotify();
  }

  void setPendingOnly(bool value) {
    if (_pendingOnly == value) return;
    _pendingOnly = value;
    safeNotify();
  }

  void clearFilters() {
    _query = '';
    _classFilter = null;
    _pendingOnly = false;
    safeNotify();
  }
}
