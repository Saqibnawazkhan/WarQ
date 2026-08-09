import '../models/models.dart';

/// A session together with its records — what the marking screen edits.
class AttendanceSheet {
  const AttendanceSheet({
    required this.session,
    required this.records,
    required this.isNew,
  });

  final AttendanceSession session;

  /// Keyed by student id.
  final Map<String, AttendanceRecord> records;

  /// True when the sheet has not been saved for this date yet.
  final bool isNew;

  int get presentCount => records.values
      .where((AttendanceRecord r) => r.status == AttendanceStatus.present)
      .length;

  int get absentCount => records.values
      .where((AttendanceRecord r) => r.status == AttendanceStatus.absent)
      .length;

  int get lateCount =>
      records.values.where((AttendanceRecord r) => r.status == AttendanceStatus.late).length;

  int get excusedCount => records.values
      .where((AttendanceRecord r) => r.status == AttendanceStatus.excused)
      .length;
}

/// Outcome of saving a sheet, including which absences were newly recorded so
/// the notification pipeline only messages guardians once.
class AttendanceSaveResult {
  const AttendanceSaveResult({
    required this.session,
    required this.newlyAbsentStudentIds,
    required this.wasUpdate,
  });

  final AttendanceSession session;
  final List<String> newlyAbsentStudentIds;
  final bool wasUpdate;
}

/// Filters for the attendance history screen.
class AttendanceQuery {
  const AttendanceQuery({
    this.classIds,
    this.studentId,
    this.from,
    this.to,
    this.statuses,
  });

  final Set<String>? classIds;
  final String? studentId;
  final DateTime? from;
  final DateTime? to;
  final Set<AttendanceStatus>? statuses;

  bool get isEmpty =>
      (classIds == null || classIds!.isEmpty) &&
      studentId == null &&
      from == null &&
      to == null &&
      (statuses == null || statuses!.isEmpty);
}

/// Attendance sessions and records.
abstract class AttendanceRepository {
  /// Loads (or prepares, if none exists) the sheet for a class on a date.
  Future<AttendanceSheet> sheetFor({
    required String classId,
    required DateTime date,
    required String userId,
  });

  /// Persists the sheet. Existing records for the date are replaced.
  Future<AttendanceSaveResult> save({
    required String classId,
    required DateTime date,
    required String userId,
    required Map<String, AttendanceStatus> statuses,
    Map<String, String?> notes = const <String, String?>{},
    String? sessionNote,
  });

  Future<List<AttendanceSession>> sessionsForClass(String classId);

  Future<List<AttendanceSession>> sessionsForTeacher(String teacherId);

  Future<AttendanceSession?> sessionOn({
    required String classId,
    required DateTime date,
  });

  Future<List<AttendanceRecord>> recordsForSession(String sessionId);

  Future<List<AttendanceRecord>> recordsForStudent(
    String studentId, {
    String? classId,
  });

  Future<List<AttendanceRecord>> recordsForClass(String classId);

  /// History rows matching [query], newest first.
  Future<List<AttendanceRecord>> search(AttendanceQuery query);

  Future<void> deleteSession(String sessionId);

  /// Marks records as notified so re-saving does not message guardians again.
  Future<void> markNotified(Iterable<String> recordIds);
}
