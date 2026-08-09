import '../../../core/error/failure.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../activity_repository.dart';
import '../attendance_repository.dart';

/// On-device implementation of [AttendanceRepository].
class LocalAttendanceRepository implements AttendanceRepository {
  LocalAttendanceRepository(this._db, {required ActivityRepository activity})
      : _activity = activity;

  final LocalDatabase _db;
  final ActivityRepository _activity;

  @override
  Future<AttendanceSheet> sheetFor({
    required String classId,
    required DateTime date,
    required String userId,
  }) async {
    final DateTime day = AppDate.dateOnly(date);
    final AttendanceSession? existing = _findSession(classId, day);

    if (existing == null) {
      return AttendanceSheet(
        session: AttendanceSession(
          id: IdGenerator.generate('ses'),
          classId: classId,
          date: day,
          takenByUserId: userId,
          createdAt: DateTime.now(),
        ),
        records: const <String, AttendanceRecord>{},
        isNew: true,
      );
    }

    final Map<String, AttendanceRecord> records = <String, AttendanceRecord>{
      for (final AttendanceRecord record in _db.attendanceRecords
          .where((AttendanceRecord r) => r.sessionId == existing.id))
        record.studentId: record,
    };
    return AttendanceSheet(session: existing, records: records, isNew: false);
  }

  @override
  Future<AttendanceSaveResult> save({
    required String classId,
    required DateTime date,
    required String userId,
    required Map<String, AttendanceStatus> statuses,
    Map<String, String?> notes = const <String, String?>{},
    String? sessionNote,
  }) async {
    if (statuses.isEmpty) {
      throw const AppFailure.validation(
        'Add at least one student to this class before marking attendance.',
      );
    }
    final SchoolClass? schoolClass = _db.classes.byId(classId);
    if (schoolClass == null) throw const AppFailure.notFound('That class');

    final DateTime day = AppDate.dateOnly(date);
    if (day.isAfter(AppDate.today())) {
      throw const AppFailure.validation(
        'Attendance cannot be marked for a future date.',
      );
    }

    final AttendanceSession? existing = _findSession(classId, day);
    final bool wasUpdate = existing != null;

    final AttendanceSession session = existing?.copyWith(
          note: Format.cleanOrNull(sessionNote),
          clearNote: Format.cleanOrNull(sessionNote) == null,
          updatedAt: DateTime.now(),
        ) ??
        AttendanceSession(
          id: IdGenerator.generate('ses'),
          classId: classId,
          date: day,
          takenByUserId: userId,
          createdAt: DateTime.now(),
          note: Format.cleanOrNull(sessionNote),
        );

    // Existing records are keyed by student so re-saving preserves the
    // `notified` flag and does not re-message guardians.
    final Map<String, AttendanceRecord> previous = <String, AttendanceRecord>{
      for (final AttendanceRecord record in _db.attendanceRecords
          .where((AttendanceRecord r) => r.sessionId == session.id))
        record.studentId: record,
    };

    final List<AttendanceRecord> toWrite = <AttendanceRecord>[];
    final List<String> newlyAbsent = <String>[];
    final DateTime now = DateTime.now();

    statuses.forEach((String studentId, AttendanceStatus status) {
      final AttendanceRecord? before = previous[studentId];
      final bool becameAbsent = status.notifiesGuardians &&
          (before == null || !before.notified);

      toWrite.add(
        AttendanceRecord(
          id: before?.id ?? IdGenerator.generate('atr'),
          sessionId: session.id,
          classId: classId,
          studentId: studentId,
          status: status,
          markedAt: now,
          note: Format.cleanOrNull(notes[studentId]),
          notified: before?.notified ?? false,
        ),
      );
      if (becameAbsent) newlyAbsent.add(studentId);
    });

    // Students removed from the class since the last save leave stale rows.
    final Set<String> current = statuses.keys.toSet();
    final Iterable<String> orphaned = previous.keys.where(
      (String studentId) => !current.contains(studentId),
    );
    for (final String studentId in orphaned) {
      await _db.attendanceRecords.delete(previous[studentId]!.id);
    }

    await _db.attendanceSessions.put(session);
    await _db.attendanceRecords.putAll(toWrite);
    _db.bus.emit(DataEntity.attendance, classId: classId);

    final AppUser? actor = _db.users.byId(userId);
    final int presentCount = statuses.values
        .where((AttendanceStatus s) => s == AttendanceStatus.present)
        .length;
    await _activity.record(
      actorUserId: userId,
      actorName: actor?.displayName,
      organizationId: schoolClass.organizationId,
      type: wasUpdate ? ActivityType.attendanceUpdated : ActivityType.attendanceMarked,
      summary: '${wasUpdate ? 'Updated' : 'Marked'} attendance for '
          '${schoolClass.name} on ${AppDate.format(day)}',
      detail: '$presentCount of ${statuses.length} present',
      entityType: 'attendanceSession',
      entityId: session.id,
      classId: classId,
    );

    return AttendanceSaveResult(
      session: session,
      newlyAbsentStudentIds: newlyAbsent,
      wasUpdate: wasUpdate,
    );
  }

  @override
  Future<List<AttendanceSession>> sessionsForClass(String classId) async {
    final List<AttendanceSession> items = _db.attendanceSessions
        .where((AttendanceSession s) => s.classId == classId)
        .toList()
      ..sort((AttendanceSession a, AttendanceSession b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Future<List<AttendanceSession>> sessionsForTeacher(String teacherId) async {
    final Set<String> classIds = _db.classes
        .where((SchoolClass c) => c.teacherId == teacherId)
        .map((SchoolClass c) => c.id)
        .toSet();
    final List<AttendanceSession> items = _db.attendanceSessions
        .where((AttendanceSession s) => classIds.contains(s.classId))
        .toList()
      ..sort((AttendanceSession a, AttendanceSession b) => b.date.compareTo(a.date));
    return items;
  }

  @override
  Future<AttendanceSession?> sessionOn({
    required String classId,
    required DateTime date,
  }) async =>
      _findSession(classId, AppDate.dateOnly(date));

  @override
  Future<List<AttendanceRecord>> recordsForSession(String sessionId) async {
    return _db.attendanceRecords
        .where((AttendanceRecord r) => r.sessionId == sessionId)
        .toList(growable: false);
  }

  @override
  Future<List<AttendanceRecord>> recordsForStudent(
    String studentId, {
    String? classId,
  }) async {
    return _db.attendanceRecords
        .where((AttendanceRecord r) =>
            r.studentId == studentId && (classId == null || r.classId == classId))
        .toList(growable: false);
  }

  @override
  Future<List<AttendanceRecord>> recordsForClass(String classId) async {
    return _db.attendanceRecords
        .where((AttendanceRecord r) => r.classId == classId)
        .toList(growable: false);
  }

  @override
  Future<List<AttendanceRecord>> search(AttendanceQuery query) async {
    final Map<String, AttendanceSession> sessions = <String, AttendanceSession>{
      for (final AttendanceSession s in _db.attendanceSessions.all) s.id: s,
    };

    final List<AttendanceRecord> matches = _db.attendanceRecords.where(
      (AttendanceRecord record) {
        if (query.classIds != null &&
            query.classIds!.isNotEmpty &&
            !query.classIds!.contains(record.classId)) {
          return false;
        }
        if (query.studentId != null && record.studentId != query.studentId) {
          return false;
        }
        if (query.statuses != null &&
            query.statuses!.isNotEmpty &&
            !query.statuses!.contains(record.status)) {
          return false;
        }
        final AttendanceSession? session = sessions[record.sessionId];
        if (session == null) return false;
        return AppDate.isWithin(session.date, query.from, query.to);
      },
    ).toList();

    matches.sort((AttendanceRecord a, AttendanceRecord b) {
      final DateTime aDate = sessions[a.sessionId]?.date ?? a.markedAt;
      final DateTime bDate = sessions[b.sessionId]?.date ?? b.markedAt;
      return bDate.compareTo(aDate);
    });
    return matches;
  }

  @override
  Future<void> deleteSession(String sessionId) async {
    final AttendanceSession? session = _db.attendanceSessions.byId(sessionId);
    if (session == null) return;
    await _db.attendanceRecords
        .deleteWhere((AttendanceRecord r) => r.sessionId == sessionId);
    await _db.attendanceSessions.delete(sessionId);
    _db.bus.emit(DataEntity.attendance, classId: session.classId);
  }

  @override
  Future<void> markNotified(Iterable<String> recordIds) async {
    final Set<String> wanted = recordIds.toSet();
    if (wanted.isEmpty) return;
    final List<AttendanceRecord> updated = _db.attendanceRecords
        .where((AttendanceRecord r) => wanted.contains(r.id))
        .map((AttendanceRecord r) => r.copyWith(notified: true))
        .toList(growable: false);
    if (updated.isEmpty) return;
    await _db.attendanceRecords.putAll(updated);
  }

  AttendanceSession? _findSession(String classId, DateTime day) {
    return _db.attendanceSessions.firstWhereOrNull(
      (AttendanceSession s) =>
          s.classId == classId && AppDate.isSameDay(s.date, day),
    );
  }
}
