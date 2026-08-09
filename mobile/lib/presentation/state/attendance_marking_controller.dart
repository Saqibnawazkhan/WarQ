import '../../app/app_dependencies.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../domain/services/absence_notification_service.dart';
import 'base_controller.dart';

/// Drives the "mark attendance" screen for one class on one date.
///
/// Edits are held in memory until the teacher saves, so switching dates or
/// backing out never writes a half-filled sheet.
class AttendanceMarkingController extends BaseController {
  AttendanceMarkingController(
    this._deps,
    this._teacher, {
    required this.classId,
    DateTime? initialDate,
  }) : _date = AppDate.dateOnly(initialDate ?? DateTime.now());

  final AppDependencies _deps;
  final AppUser _teacher;
  final String classId;

  DateTime _date;
  SchoolClass? _schoolClass;
  List<Student> _roster = const <Student>[];
  Map<String, AttendanceStatus> _statuses = <String, AttendanceStatus>{};
  Map<String, AttendanceStatus> _savedStatuses = <String, AttendanceStatus>{};
  String? _sessionNote;
  bool _isExistingSession = false;
  AbsenceDispatchReport? _lastDispatch;

  DateTime get date => _date;
  SchoolClass? get schoolClass => _schoolClass;
  List<Student> get roster => _roster;
  String? get sessionNote => _sessionNote;
  bool get isExistingSession => _isExistingSession;
  AbsenceDispatchReport? get lastDispatch => _lastDispatch;

  bool get hasStudents => _roster.isNotEmpty;
  bool get isFutureDate => AppDate.isFuture(_date);

  /// True when the in-memory sheet differs from what is stored.
  bool get hasUnsavedChanges {
    if (_statuses.length != _savedStatuses.length) return true;
    for (final MapEntry<String, AttendanceStatus> entry in _statuses.entries) {
      if (_savedStatuses[entry.key] != entry.value) return true;
    }
    return false;
  }

  AttendanceStatus statusFor(String studentId) =>
      _statuses[studentId] ?? AttendanceStatus.present;

  int countOf(AttendanceStatus status) =>
      _statuses.values.where((AttendanceStatus s) => s == status).length;

  int get presentCount => countOf(AttendanceStatus.present);
  int get absentCount => countOf(AttendanceStatus.absent);
  int get lateCount => countOf(AttendanceStatus.late);
  int get shortLeaveCount => countOf(AttendanceStatus.shortLeave);

  /// Absent students that have at least one guardian number on file.
  List<Student> get notifiableAbsentees => _roster
      .where((Student s) =>
          _statuses[s.id] == AttendanceStatus.absent && s.hasAnyContact)
      .toList(growable: false);

  List<Student> get absenteesWithoutContact => _roster
      .where((Student s) =>
          _statuses[s.id] == AttendanceStatus.absent && !s.hasAnyContact)
      .toList(growable: false);

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _schoolClass = await _deps.classes.findById(classId);
        _roster = await _deps.students.listForClass(classId);

        final AttendanceSheet sheet = await _deps.attendance.sheetFor(
          classId: classId,
          date: _date,
          userId: _teacher.id,
        );
        _isExistingSession = !sheet.isNew;
        _sessionNote = sheet.session.note;

        // Default everyone to present: marking the exceptions is far faster
        // than tapping every student.
        _statuses = <String, AttendanceStatus>{
          for (final Student student in _roster)
            student.id:
                sheet.records[student.id]?.status ?? AttendanceStatus.present,
        };
        _savedStatuses = sheet.isNew
            ? <String, AttendanceStatus>{}
            : Map<String, AttendanceStatus>.of(_statuses);
      },
      refreshing: refreshing,
      isEmptyResult: () => _roster.isEmpty,
    );
  }

  Future<void> changeDate(DateTime value) async {
    final DateTime normalised = AppDate.dateOnly(value);
    if (AppDate.isSameDay(normalised, _date)) return;
    _date = normalised;
    _lastDispatch = null;
    await load(refreshing: true);
  }

  void setStatus(String studentId, AttendanceStatus status) {
    if (_statuses[studentId] == status) return;
    _statuses[studentId] = status;
    safeNotify();
  }

  /// Cycles Present → Absent → Late → Short leave, used by the row tap target.
  void cycleStatus(String studentId) {
    final AttendanceStatus current = statusFor(studentId);
    final int next = (AttendanceStatus.values.indexOf(current) + 1) %
        AttendanceStatus.values.length;
    setStatus(studentId, AttendanceStatus.values[next]);
  }

  void markAll(AttendanceStatus status) {
    for (final Student student in _roster) {
      _statuses[student.id] = status;
    }
    safeNotify();
  }

  void setSessionNote(String? note) {
    _sessionNote = note;
    safeNotify();
  }

  /// Persists the sheet and, when requested, queues absence notifications.
  ///
  /// Returns the dispatch report so the screen can tell the teacher how many
  /// guardians were contacted and how many students had no phone number.
  Future<AbsenceDispatchReport?> save({bool notifyGuardians = true}) async {
    final SchoolClass? current = _schoolClass;
    if (current == null) return null;

    return guardAction<AbsenceDispatchReport>(() async {
      final AttendanceSaveResult result = await _deps.attendance.save(
        classId: classId,
        date: _date,
        userId: _teacher.id,
        statuses: Map<String, AttendanceStatus>.of(_statuses),
        sessionNote: _sessionNote,
      );

      _savedStatuses = Map<String, AttendanceStatus>.of(_statuses);
      _isExistingSession = true;

      if (!notifyGuardians || result.newlyAbsentStudentIds.isEmpty) {
        _lastDispatch = const AbsenceDispatchReport.empty();
        return _lastDispatch!;
      }

      final Set<String> absentIds = result.newlyAbsentStudentIds.toSet();
      final List<Student> absentees =
          _roster.where((Student s) => absentIds.contains(s.id)).toList();
      final List<AttendanceRecord> records =
          await _deps.attendance.recordsForSession(result.session.id);

      _lastDispatch = await _deps.absenceNotifications.notifyAbsences(
        schoolClass: current,
        absentStudents: absentees,
        date: _date,
        teacher: _teacher,
        records: records,
      );
      return _lastDispatch!;
    });
  }
}
