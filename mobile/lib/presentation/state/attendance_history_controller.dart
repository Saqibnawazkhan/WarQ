import '../../app/app_dependencies.dart';
import '../../core/utils/date_utils.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../domain/entities/attendance_summary.dart';
import 'base_controller.dart';

/// One row of the attendance history list.
class AttendanceHistoryRow {
  const AttendanceHistoryRow({
    required this.record,
    required this.date,
    required this.studentName,
    required this.className,
    this.rollNumber,
  });

  final AttendanceRecord record;
  final DateTime date;
  final String studentName;
  final String className;
  final String? rollNumber;

  AttendanceStatus get status => record.status;
}

/// A day's attendance for one class, used by the grouped history view.
class AttendanceSessionRow {
  const AttendanceSessionRow({
    required this.session,
    required this.className,
    required this.summary,
    required this.rows,
  });

  final AttendanceSession session;
  final String className;
  final AttendanceSummary summary;
  final List<AttendanceHistoryRow> rows;

  DateTime get date => session.date;
}

/// Backs the attendance history screen with class / student / date filters.
class AttendanceHistoryController extends BaseController {
  AttendanceHistoryController(this._deps, this._teacher, {String? initialClassId})
      : _classIds = <String>{if (initialClassId != null) initialClassId} {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.attendance,
      DataEntity.students,
      DataEntity.classes,
      DataEntity.enrollments,
    });
  }

  final AppDependencies _deps;
  final AppUser _teacher;

  Set<String> _classIds;
  String? _studentId;
  DateTime? _from;
  DateTime? _to;
  Set<AttendanceStatus> _statuses = <AttendanceStatus>{};

  List<SchoolClass> _classes = const <SchoolClass>[];
  List<Student> _students = const <Student>[];
  List<AttendanceSessionRow> _sessionRows = const <AttendanceSessionRow>[];
  AttendanceSummary _summary = const AttendanceSummary.empty();

  Set<String> get classIds => _classIds;
  String? get studentId => _studentId;
  DateTime? get from => _from;
  DateTime? get to => _to;
  Set<AttendanceStatus> get statuses => _statuses;

  List<SchoolClass> get classes => _classes;
  List<Student> get students => _students;
  List<AttendanceSessionRow> get sessionRows => _sessionRows;
  AttendanceSummary get summary => _summary;

  int get recordCount => _sessionRows.fold<int>(
        0,
        (int total, AttendanceSessionRow row) => total + row.rows.length,
      );

  bool get hasActiveFilters =>
      _classIds.isNotEmpty ||
      _studentId != null ||
      _from != null ||
      _to != null ||
      _statuses.isNotEmpty;

  String get filterSummary {
    final List<String> parts = <String>[];
    if (_classIds.isNotEmpty) {
      parts.add(_classIds.length == 1
          ? _classNameOf(_classIds.first)
          : '${_classIds.length} classes');
    }
    if (_studentId != null) {
      parts.add(_studentNameOf(_studentId!));
    }
    if (_from != null || _to != null) {
      final String start = _from == null ? 'Any' : AppDate.formatShort(_from!);
      final String end = _to == null ? 'today' : AppDate.formatShort(_to!);
      parts.add('$start – $end');
    }
    if (_statuses.isNotEmpty) {
      parts.add(_statuses.map((AttendanceStatus s) => s.label).join(', '));
    }
    return parts.isEmpty ? 'All attendance' : parts.join(' · ');
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _classes = await _deps.classes.listForTeacher(
          _teacher.id,
          alphabetical: true,
        );
        _students = await _deps.students.listForTeacher(_teacher.id);

        final Set<String> scope = _classIds.isNotEmpty
            ? _classIds
            : _classes.map((SchoolClass c) => c.id).toSet();

        final List<AttendanceRecord> records = await _deps.attendance.search(
          AttendanceQuery(
            classIds: scope,
            studentId: _studentId,
            from: _from,
            to: _to,
            statuses: _statuses.isEmpty ? null : _statuses,
          ),
        );

        _summary = AttendanceSummary.fromStatuses(
          records.map((AttendanceRecord r) => r.status),
        );
        _sessionRows = await _group(records);
      },
      refreshing: refreshing,
      isEmptyResult: () => _sessionRows.isEmpty,
    );
  }

  Future<List<AttendanceSessionRow>> _group(
    List<AttendanceRecord> records,
  ) async {
    if (records.isEmpty) return const <AttendanceSessionRow>[];

    final Map<String, SchoolClass> classById = <String, SchoolClass>{
      for (final SchoolClass c in _classes) c.id: c,
    };
    final Map<String, Student> studentById = <String, Student>{
      for (final Student s in _students) s.id: s,
    };

    final Map<String, AttendanceSession> sessionById =
        <String, AttendanceSession>{};
    for (final String classId in records.map((AttendanceRecord r) => r.classId).toSet()) {
      for (final AttendanceSession session
          in await _deps.attendance.sessionsForClass(classId)) {
        sessionById[session.id] = session;
      }
    }

    final Map<String, List<AttendanceRecord>> bySession =
        <String, List<AttendanceRecord>>{};
    for (final AttendanceRecord record in records) {
      bySession.putIfAbsent(record.sessionId, () => <AttendanceRecord>[]).add(record);
    }

    final List<AttendanceSessionRow> rows = <AttendanceSessionRow>[];
    bySession.forEach((String sessionId, List<AttendanceRecord> group) {
      final AttendanceSession? session = sessionById[sessionId];
      if (session == null) return;
      final String className = classById[session.classId]?.name ?? 'Class';

      final List<AttendanceHistoryRow> historyRows = <AttendanceHistoryRow>[
        for (final AttendanceRecord record in group)
          AttendanceHistoryRow(
            record: record,
            date: session.date,
            studentName: studentById[record.studentId]?.fullName ?? 'Student',
            rollNumber: studentById[record.studentId]?.rollNumber,
            className: className,
          ),
      ]..sort((AttendanceHistoryRow a, AttendanceHistoryRow b) =>
          a.studentName.toLowerCase().compareTo(b.studentName.toLowerCase()));

      rows.add(
        AttendanceSessionRow(
          session: session,
          className: className,
          summary: AttendanceSummary.fromStatuses(
            group.map((AttendanceRecord r) => r.status),
          ),
          rows: historyRows,
        ),
      );
    });

    rows.sort((AttendanceSessionRow a, AttendanceSessionRow b) {
      final int byDate = b.date.compareTo(a.date);
      return byDate != 0 ? byDate : a.className.compareTo(b.className);
    });
    return rows;
  }

  // ---------------------------------------------------------------------------
  // Filters
  // ---------------------------------------------------------------------------

  Future<void> setClassFilter(Set<String> value) async {
    _classIds = value;
    await load(refreshing: true);
  }

  Future<void> toggleClass(String classId) async {
    final Set<String> next = Set<String>.of(_classIds);
    if (!next.remove(classId)) next.add(classId);
    await setClassFilter(next);
  }

  Future<void> setStudentFilter(String? value) async {
    _studentId = value;
    await load(refreshing: true);
  }

  Future<void> setDateRange(DateTime? from, DateTime? to) async {
    _from = from == null ? null : AppDate.dateOnly(from);
    _to = to == null ? null : AppDate.dateOnly(to);
    await load(refreshing: true);
  }

  Future<void> setStatusFilter(Set<AttendanceStatus> value) async {
    _statuses = value;
    await load(refreshing: true);
  }

  Future<void> applyPreset(HistoryPreset preset) async {
    final DateTime today = AppDate.today();
    switch (preset) {
      case HistoryPreset.thisWeek:
        _from = AppDate.startOfWeek(today);
        _to = today;
      case HistoryPreset.thisMonth:
        _from = AppDate.startOfMonth(today);
        _to = today;
      case HistoryPreset.lastThirtyDays:
        _from = today.subtract(const Duration(days: 29));
        _to = today;
      case HistoryPreset.allTime:
        _from = null;
        _to = null;
    }
    await load(refreshing: true);
  }

  Future<void> clearFilters() async {
    _classIds = <String>{};
    _studentId = null;
    _from = null;
    _to = null;
    _statuses = <AttendanceStatus>{};
    await load(refreshing: true);
  }

  String _classNameOf(String id) =>
      _classes.where((SchoolClass c) => c.id == id).firstOrNull?.name ?? 'Class';

  String _studentNameOf(String id) =>
      _students.where((Student s) => s.id == id).firstOrNull?.fullName ??
      'Student';
}

/// Quick date-range presets offered on the history filter sheet.
enum HistoryPreset {
  thisWeek,
  thisMonth,
  lastThirtyDays,
  allTime;

  String get label => switch (this) {
        HistoryPreset.thisWeek => 'This week',
        HistoryPreset.thisMonth => 'This month',
        HistoryPreset.lastThirtyDays => 'Last 30 days',
        HistoryPreset.allTime => 'All time',
      };
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
