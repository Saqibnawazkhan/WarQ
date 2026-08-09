import { describe, expect, it } from 'vitest';

import {
  absentees,
  attendancePercent,
  averageAttendance,
  combineTallies,
  EMPTY_TALLY,
  MARK_INITIAL,
  sessionsCounted,
  tally,
  type AttendanceMark,
} from '../src/index.js';

describe('tally', () => {
  it('counts a roll call', () => {
    const marks: AttendanceMark[] = ['present', 'present', 'absent', 'late', 'present'];
    expect(tally(marks)).toEqual({ present: 3, absent: 1, late: 1 });
  });

  it('counts an empty roll call as nothing, not as an error', () => {
    expect(tally([])).toEqual(EMPTY_TALLY);
  });
});

describe('attendancePercent — students from the mockup roster', () => {
  it('Ahmed Khan · 38 present, 5 absent, 1 late · 86%', () => {
    expect(attendancePercent({ present: 38, absent: 5, late: 1 })).toBe(86);
  });

  it('Zainab Bibi · perfect record · 100%', () => {
    expect(attendancePercent({ present: 44, absent: 0, late: 0 })).toBe(100);
  });

  it('Usman Tariq · 35 present, 8 absent, 1 late · 80%', () => {
    expect(attendancePercent({ present: 35, absent: 8, late: 1 })).toBe(80);
  });

  it('counts late against the percentage, as the mockups do', () => {
    expect(attendancePercent({ present: 9, absent: 0, late: 1 })).toBe(90);
  });

  it('is zero for a student with no sessions, rather than dividing by zero', () => {
    expect(attendancePercent(EMPTY_TALLY)).toBe(0);
  });
});

describe('sessionsCounted', () => {
  it('adds all three marks', () => {
    expect(sessionsCounted({ present: 38, absent: 5, late: 1 })).toBe(44);
  });
});

describe('combineTallies', () => {
  it('rolls several records into one', () => {
    expect(
      combineTallies([
        { present: 10, absent: 1, late: 0 },
        { present: 8, absent: 2, late: 1 },
      ]),
    ).toEqual({ present: 18, absent: 3, late: 1 });
  });

  it('returns an empty tally for no records', () => {
    expect(combineTallies([])).toEqual(EMPTY_TALLY);
  });
});

describe('averageAttendance', () => {
  it('gives every student equal weight, so one keen student cannot mask the class', () => {
    const heavyAttender = { present: 100, absent: 0, late: 0 };
    const strugglers = [
      { present: 5, absent: 5, late: 0 },
      { present: 5, absent: 5, late: 0 },
    ];
    expect(averageAttendance([heavyAttender, ...strugglers])).toBe(67);
  });

  it('is zero for an empty class', () => {
    expect(averageAttendance([])).toBe(0);
  });
});

describe('absentees', () => {
  const roster = [
    { id: 's1', mark: 'present' as AttendanceMark },
    { id: 's9', mark: 'absent' as AttendanceMark },
    { id: 's4', mark: 'late' as AttendanceMark },
  ];

  it('selects only the absent, because a late arrival is not worth a message home', () => {
    expect(absentees(roster, (student) => student.mark).map((s) => s.id)).toEqual(['s9']);
  });
});

describe('MARK_INITIAL', () => {
  it('matches the P · A · L toggle', () => {
    expect(MARK_INITIAL).toEqual({ present: 'P', absent: 'A', late: 'L' });
  });
});
