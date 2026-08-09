/**
 * Attendance.
 *
 * Three marks, one session per class per day. Late is recorded separately from
 * present because institutions report on it separately — and, following the
 * mockups, it does not count toward the attendance percentage.
 */

export const ATTENDANCE_MARKS = ['present', 'absent', 'late'] as const;
export type AttendanceMark = (typeof ATTENDANCE_MARKS)[number];

/** The single letters shown on the P · A · L toggle. */
export const MARK_INITIAL: Readonly<Record<AttendanceMark, 'P' | 'A' | 'L'>> = {
  present: 'P',
  absent: 'A',
  late: 'L',
};

const MARK_LABEL: Readonly<Record<AttendanceMark, string>> = {
  present: 'Present',
  absent: 'Absent',
  late: 'Late',
};

/** What a student is marked as until a teacher says otherwise. */
export const DEFAULT_MARK: AttendanceMark = 'present';

export interface AttendanceTally {
  readonly present: number;
  readonly absent: number;
  readonly late: number;
}

export const EMPTY_TALLY: AttendanceTally = { present: 0, absent: 0, late: 0 };

export function isAttendanceMark(value: string): value is AttendanceMark {
  return (ATTENDANCE_MARKS as readonly string[]).includes(value);
}

export function markLabel(mark: AttendanceMark): string {
  return MARK_LABEL[mark];
}

export function tally(marks: Iterable<AttendanceMark>): AttendanceTally {
  let present = 0;
  let absent = 0;
  let late = 0;

  for (const mark of marks) {
    if (mark === 'present') present += 1;
    else if (mark === 'absent') absent += 1;
    else late += 1;
  }

  return { present, absent, late };
}

/** Total sessions counted — the denominator for every attendance figure. */
export function sessionsCounted(counts: AttendanceTally): number {
  return counts.present + counts.absent + counts.late;
}

/** Whole-number attendance percentage. An empty record is 0%, not a division by zero. */
export function attendancePercent(counts: AttendanceTally): number {
  const sessions = sessionsCounted(counts);
  if (sessions === 0) return 0;
  return Math.round((counts.present / sessions) * 100);
}

export function addTallies(a: AttendanceTally, b: AttendanceTally): AttendanceTally {
  return {
    present: a.present + b.present,
    absent: a.absent + b.absent,
    late: a.late + b.late,
  };
}

/** Rolls several students', or several classes', records into one figure. */
export function combineTallies(all: readonly AttendanceTally[]): AttendanceTally {
  return all.reduce(addTallies, EMPTY_TALLY);
}

/**
 * Average attendance across students, as a percentage.
 *
 * Each student counts once regardless of how many sessions they attended, which
 * is what a class attendance figure means to a teacher. Summing all sessions
 * instead would let one heavily-attending student mask the rest.
 */
export function averageAttendance(students: readonly AttendanceTally[]): number {
  if (students.length === 0) return 0;
  const sum = students.reduce((running, counts) => running + attendancePercent(counts), 0);
  return Math.round(sum / students.length);
}

/**
 * Students who need an absence alert sent to their guardians.
 * Only the absent ones — a late arrival is not worth a message home.
 */
export function absentees<T>(
  roster: readonly T[],
  markOf: (student: T) => AttendanceMark,
): readonly T[] {
  return roster.filter((student) => markOf(student) === 'absent');
}
