import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../data/repositories/assessment_repository.dart';
import 'base_controller.dart';

/// In-memory edit state for a single student's row on the marks screen.
class MarkDraft {
  const MarkDraft({this.marks, this.remarks, this.absent = false});

  final double? marks;
  final String? remarks;
  final bool absent;

  bool get isBlank => marks == null && !absent && (remarks?.isEmpty ?? true);

  MarkDraft copyWith({
    double? marks,
    bool clearMarks = false,
    String? remarks,
    bool clearRemarks = false,
    bool? absent,
  }) {
    return MarkDraft(
      marks: clearMarks ? null : (marks ?? this.marks),
      remarks: clearRemarks ? null : (remarks ?? this.remarks),
      absent: absent ?? this.absent,
    );
  }
}

/// Backs the mark-entry screen for one assessment.
class AssessmentMarksController extends BaseController {
  AssessmentMarksController(this._deps, this.assessmentId) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.enrollments,
      DataEntity.students,
    });
  }

  final AppDependencies _deps;
  final String assessmentId;

  Assessment? _assessment;
  SchoolClass? _schoolClass;
  GradeScale? _gradeScale;
  List<Student> _roster = const <Student>[];
  Map<String, MarkDraft> _drafts = <String, MarkDraft>{};
  Map<String, MarkDraft> _saved = <String, MarkDraft>{};
  String _query = '';

  Assessment? get assessment => _assessment;
  SchoolClass? get schoolClass => _schoolClass;
  GradeScale? get gradeScale => _gradeScale;
  List<Student> get roster => _roster;
  String get query => _query;
  double get totalMarks => _assessment?.totalMarks ?? 0;

  List<Student> get visibleStudents {
    final String needle = _query.trim().toLowerCase();
    if (needle.isEmpty) return _roster;
    return _roster
        .where((Student s) =>
            s.fullName.toLowerCase().contains(needle) ||
            (s.rollNumber?.toLowerCase().contains(needle) ?? false))
        .toList(growable: false);
  }

  MarkDraft draftFor(String studentId) =>
      _drafts[studentId] ?? const MarkDraft();

  int get gradedCount =>
      _drafts.values.where((MarkDraft d) => !d.isBlank).length;

  int get pendingCount => _roster.length - gradedCount;

  bool get hasUnsavedChanges {
    for (final Student student in _roster) {
      final MarkDraft current = draftFor(student.id);
      final MarkDraft saved = _saved[student.id] ?? const MarkDraft();
      if (current.marks != saved.marks ||
          current.absent != saved.absent ||
          (current.remarks ?? '') != (saved.remarks ?? '')) {
        return true;
      }
    }
    return false;
  }

  /// Class average across the entries currently on screen.
  double? get averagePercentage {
    final List<double> values = <double>[
      for (final Student student in _roster)
        if (_percentFor(draftFor(student.id)) != null)
          _percentFor(draftFor(student.id))!,
    ];
    if (values.isEmpty) return null;
    return values.reduce((double a, double b) => a + b) / values.length;
  }

  double? percentFor(String studentId) => _percentFor(draftFor(studentId));

  GradeBand? gradeFor(String studentId) {
    final GradeScale? scale = _gradeScale;
    final double? percent = percentFor(studentId);
    if (scale == null || percent == null) return null;
    return scale.bandFor(percent);
  }

  double? _percentFor(MarkDraft draft) {
    if (totalMarks <= 0) return null;
    if (draft.absent) return 0;
    final double? value = draft.marks;
    if (value == null) return null;
    return (value / totalMarks) * 100;
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _assessment = await _deps.assessments.findById(assessmentId);
        final Assessment? current = _assessment;
        if (current == null) throw StateError('missing assessment');

        _schoolClass = await _deps.classes.findById(current.classId);
        _gradeScale = await _deps.gradeScales.resolveFor(
          organizationId: _schoolClass?.organizationId,
        );
        _roster = await _deps.students.listForClass(current.classId);

        final Map<String, AssessmentMark> marks =
            await _deps.assessments.marksForAssessment(assessmentId);
        _drafts = <String, MarkDraft>{
          for (final Student student in _roster)
            student.id: MarkDraft(
              marks: marks[student.id]?.marksObtained,
              remarks: marks[student.id]?.remarks,
              absent: marks[student.id]?.absent ?? false,
            ),
        };
        _saved = <String, MarkDraft>{
          for (final MapEntry<String, MarkDraft> entry in _drafts.entries)
            entry.key: entry.value,
        };
      },
      refreshing: refreshing,
      isEmptyResult: () => _roster.isEmpty,
    );
  }

  void search(String value) {
    if (_query == value) return;
    _query = value;
    safeNotify();
  }

  void setMarks(String studentId, double? value) {
    final MarkDraft current = draftFor(studentId);
    _drafts[studentId] = current.copyWith(
      marks: value,
      clearMarks: value == null,
      absent: value == null ? current.absent : false,
    );
    safeNotify();
  }

  void setAbsent(String studentId, bool absent) {
    final MarkDraft current = draftFor(studentId);
    _drafts[studentId] = current.copyWith(absent: absent, clearMarks: absent);
    safeNotify();
  }

  void setRemarks(String studentId, String? remarks) {
    final MarkDraft current = draftFor(studentId);
    final String? cleaned =
        (remarks == null || remarks.trim().isEmpty) ? null : remarks.trim();
    _drafts[studentId] =
        current.copyWith(remarks: cleaned, clearRemarks: cleaned == null);
    safeNotify();
  }

  /// Clears every entry, used by the "reset" action.
  void clearAll() {
    _drafts = <String, MarkDraft>{
      for (final Student student in _roster) student.id: const MarkDraft(),
    };
    safeNotify();
  }

  /// Gives every ungraded student full marks — handy for participation scores.
  void fillRemainingWith(double value) {
    for (final Student student in _roster) {
      final MarkDraft current = draftFor(student.id);
      if (current.isBlank) {
        _drafts[student.id] = current.copyWith(marks: value);
      }
    }
    safeNotify();
  }

  Future<bool> save() async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.assessments.saveMarks(
        assessmentId: assessmentId,
        entries: <MarkEntry>[
          for (final Student student in _roster)
            MarkEntry(
              studentId: student.id,
              marksObtained: draftFor(student.id).marks,
              remarks: draftFor(student.id).remarks,
              absent: draftFor(student.id).absent,
            ),
        ],
      );
      return true;
    });
    if (ok ?? false) {
      _saved = <String, MarkDraft>{
        for (final MapEntry<String, MarkDraft> entry in _drafts.entries)
          entry.key: entry.value,
      };
      safeNotify();
    }
    return ok ?? false;
  }
}
