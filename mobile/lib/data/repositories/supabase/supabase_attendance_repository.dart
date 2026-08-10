import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../activity_repository.dart';
import '../attendance_repository.dart';
import 'supabase_repository_base.dart';

/// Attendance backed by Supabase.
///
/// Saving goes through the `save_attendance` function and never through direct
/// writes. A register is one decision by a teacher, and splitting it into a
/// session insert plus a row per student would let a dropped connection leave
/// half a class marked. The function is idempotent on (class_id, date), which
/// is what lets the app re-send a queued register without checking first.
///
/// `attendance_records` has no surrogate key — it is keyed by
/// (session_id, student_id) — so record ids in the app are the two joined by a
/// colon, and [markNotified] takes them apart again.
class SupabaseAttendanceRepository extends SupabaseRepositoryBase
    implements AttendanceRepository {
  SupabaseAttendanceRepository(
    super.client,
    super.bus, {
    required ActivityRepository activity,
  }) : _activity = activity;

  final ActivityRepository _activity;

  SupabaseQueryBuilder get _sessions => client.from('attendance_sessions');
  SupabaseQueryBuilder get _records => client.from('attendance_records');

  @override
  Future<AttendanceSheet> sheetFor({
    required String classId,
    required DateTime date,
    required String userId,
  }) async {
    final DateTime day = AppDate.dateOnly(date);
    final AttendanceSession? existing =
        await sessionOn(classId: classId, date: day);

    if (existing == null) {
      // Nothing saved for this date yet. The screen needs a session object to
      // render against, but it must not exist in the database until the teacher
      // actually saves — an empty register is not the same as a class that met
      // and had nobody present.
      return AttendanceSheet(
        session: AttendanceSession(
          id: '',
          classId: classId,
          date: day,
          takenByUserId: userId,
          createdAt: DateTime.now(),
        ),
        records: const <String, AttendanceRecord>{},
        isNew: true,
      );
    }

    final List<AttendanceRecord> records = await recordsForSession(existing.id);
    return AttendanceSheet(
      session: existing,
      records: <String, AttendanceRecord>{
        for (final AttendanceRecord record in records) record.studentId: record,
      },
      isNew: false,
    );
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

    final DateTime day = AppDate.dateOnly(date);
    if (day.isAfter(AppDate.today())) {
      throw const AppFailure.validation(
        'Attendance cannot be marked for a future date.',
      );
    }

    final Map<String, dynamic>? schoolClass = await read(
      () => client
          .from('classes')
          .select('id, name, organization_id')
          .eq('id', classId)
          .maybeSingle(),
    );
    if (schoolClass == null) throw const AppFailure.notFound('That class');

    // Read the previous marks before overwriting them. "Newly absent" is the
    // difference between the two, and it decides who gets a message — a student
    // already marked absent this morning must not be reported to their parents
    // again because the teacher corrected somebody else at noon.
    final AttendanceSession? before =
        await sessionOn(classId: classId, date: day);
    final bool wasUpdate = before != null;
    final Map<String, AttendanceRecord> previous = before == null
        ? const <String, AttendanceRecord>{}
        : <String, AttendanceRecord>{
            for (final AttendanceRecord record
                in await recordsForSession(before.id))
              record.studentId: record,
          };

    final AttendanceSession session = await write(
      () async {
        final Map<String, dynamic> result =
            await client.rpc<Map<String, dynamic>>(
          'save_attendance',
          params: <String, dynamic>{
            'p_class_id': classId,
            'p_date': AppDate.toIso(day),
            'p_entries': <Map<String, String>>[
              for (final MapEntry<String, AttendanceStatus> entry
                  in statuses.entries)
                <String, String>{
                  'student_id': entry.key,
                  'mark': Rows.markToDb(entry.value),
                },
            ],
          },
        );

        final String sessionId = Rows.str(result, 'session_id');

        // The note is the teacher's own, and the function has no argument for
        // it. Written straight after, on a row that now certainly exists.
        final String? note = Format.cleanOrNull(sessionNote);
        final Map<String, dynamic> row = await _sessions
            .update(<String, dynamic>{'note': note})
            .eq('id', sessionId)
            .select('*')
            .single();
        return Rows.session(row);
      },
      touches: <DataEntity>{DataEntity.attendance},
      classId: classId,
    );

    final List<String> newlyAbsent = <String>[
      for (final MapEntry<String, AttendanceStatus> entry in statuses.entries)
        if (entry.value.notifiesGuardians &&
            !(previous[entry.key]?.notified ?? false))
          entry.key,
    ];

    final int presentCount = statuses.values
        .where((AttendanceStatus s) => s == AttendanceStatus.present)
        .length;
    await _activity.record(
      actorUserId: userId,
      organizationId: Rows.strOrNull(schoolClass, 'organization_id'),
      type: wasUpdate
          ? ActivityType.attendanceUpdated
          : ActivityType.attendanceMarked,
      summary: '${wasUpdate ? 'Updated' : 'Marked'} attendance for '
          '${Rows.str(schoolClass, 'name')} on ${AppDate.format(day)}',
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
  Future<List<AttendanceSession>> sessionsForClass(String classId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _sessions
          .select('*')
          .eq('class_id', classId)
          .order('date', ascending: false);
      return rows.map(Rows.session).toList(growable: false);
    });
  }

  @override
  Future<List<AttendanceSession>> sessionsForTeacher(String teacherId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _sessions
          .select('*, classes!inner(teacher_id)')
          .eq('classes.teacher_id', teacherId)
          .order('date', ascending: false);
      return rows.map(Rows.session).toList(growable: false);
    });
  }

  @override
  Future<AttendanceSession?> sessionOn({
    required String classId,
    required DateTime date,
  }) {
    return read(() async {
      final Map<String, dynamic>? row = await _sessions
          .select('*')
          .eq('class_id', classId)
          .eq('date', AppDate.toIso(AppDate.dateOnly(date)))
          .maybeSingle();
      return row == null ? null : Rows.session(row);
    });
  }

  @override
  Future<List<AttendanceRecord>> recordsForSession(String sessionId) {
    return read(() async {
      // The class and the date live on the session, and the model carries both,
      // so the parent is embedded rather than fetched a second time.
      final List<Map<String, dynamic>> rows = await _records
          .select('*, attendance_sessions!inner(class_id, date)')
          .eq('session_id', sessionId);
      return _toRecords(rows);
    });
  }

  @override
  Future<List<AttendanceRecord>> recordsForStudent(
    String studentId, {
    String? classId,
  }) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> query = _records
          .select('*, attendance_sessions!inner(class_id, date)')
          .eq('student_id', studentId);
      if (classId != null) {
        query = query.eq('attendance_sessions.class_id', classId);
      }
      return _sortedByDate(_toRecords(await query));
    });
  }

  @override
  Future<List<AttendanceRecord>> recordsForClass(String classId) {
    return read(() async {
      final List<Map<String, dynamic>> rows = await _records
          .select('*, attendance_sessions!inner(class_id, date)')
          .eq('attendance_sessions.class_id', classId);
      return _sortedByDate(_toRecords(rows));
    });
  }

  @override
  Future<List<AttendanceRecord>> search(AttendanceQuery query) {
    return read(() async {
      PostgrestFilterBuilder<List<Map<String, dynamic>>> builder =
          _records.select('*, attendance_sessions!inner(class_id, date)');

      final Set<String>? classIds = query.classIds;
      if (classIds != null && classIds.isNotEmpty) {
        builder = builder.inFilter(
          'attendance_sessions.class_id',
          classIds.toList(),
        );
      }
      if (query.studentId != null) {
        builder = builder.eq('student_id', query.studentId!);
      }
      if (query.from != null) {
        builder = builder.gte(
          'attendance_sessions.date',
          AppDate.toIso(AppDate.dateOnly(query.from!)),
        );
      }
      if (query.to != null) {
        builder = builder.lte(
          'attendance_sessions.date',
          AppDate.toIso(AppDate.dateOnly(query.to!)),
        );
      }

      final Set<AttendanceStatus>? statuses = query.statuses;
      if (statuses != null && statuses.isNotEmpty) {
        builder = builder.inFilter(
          'mark',
          statuses.map(Rows.markToDb).toList(),
        );
      }

      return _sortedByDate(_toRecords(await builder));
    });
  }

  @override
  Future<void> deleteSession(String sessionId) {
    // The marks cascade from the session's foreign key.
    return write(
      () => _sessions.delete().eq('id', sessionId),
      touches: <DataEntity>{DataEntity.attendance},
      id: sessionId,
    );
  }

  @override
  Future<void> markNotified(Iterable<String> recordIds) async {
    // Ids arrive as 'sessionId:studentId'. Grouping them means one call per
    // session rather than one per student, which matters because a partial
    // write here shows up later as a parent messaged twice.
    final Map<String, List<String>> bySession = <String, List<String>>{};
    for (final String id in recordIds) {
      final int split = id.indexOf(':');
      if (split <= 0 || split == id.length - 1) continue;
      bySession
          .putIfAbsent(id.substring(0, split), () => <String>[])
          .add(id.substring(split + 1));
    }
    if (bySession.isEmpty) return;

    await write(
      () async {
        for (final MapEntry<String, List<String>> entry in bySession.entries) {
          await client.rpc<int>(
            'mark_absences_notified',
            params: <String, dynamic>{
              'p_session_id': entry.key,
              'p_student_ids': entry.value,
            },
          );
        }
      },
      touches: <DataEntity>{DataEntity.attendance},
    );
  }

  /// Turns embedded rows into records, taking the class and the date from the
  /// session that came back with them.
  List<AttendanceRecord> _toRecords(List<Map<String, dynamic>> rows) {
    return rows.map((Map<String, dynamic> row) {
      final Map<String, dynamic> session =
          (row['attendance_sessions'] as Map<String, dynamic>?) ??
              const <String, dynamic>{};
      return Rows.attendanceRecord(
        row,
        classId: Rows.str(session, 'class_id'),
        markedAt: Rows.dateOnly(session, 'date'),
        notified: Rows.boolean(row, 'notified'),
      );
    }).toList();
  }

  /// Newest first, which is how the history screen reads. Sorted here because
  /// the date lives on the embedded parent and PostgREST will not order by it.
  List<AttendanceRecord> _sortedByDate(List<AttendanceRecord> records) {
    records.sort((AttendanceRecord a, AttendanceRecord b) =>
        b.markedAt.compareTo(a.markedAt));
    return records;
  }
}
