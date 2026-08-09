import { describe, expect, it } from 'vitest';

import {
  addDays,
  addMonths,
  addYears,
  daysBetween,
  daysInMonth,
  formatCalendarDate,
  isCalendarDate,
  parseCalendarDate,
  toCalendarDate,
  today,
} from '../src/index.js';

describe('isCalendarDate', () => {
  it('accepts well-formed dates that exist', () => {
    expect(isCalendarDate('2026-08-08')).toBe(true);
    expect(isCalendarDate('2028-02-29')).toBe(true);
  });

  it('rejects dates that do not exist', () => {
    expect(isCalendarDate('2026-02-30')).toBe(false);
    expect(isCalendarDate('2026-13-01')).toBe(false);
    expect(isCalendarDate('2026-00-10')).toBe(false);
  });

  it('rejects anything that is not a plain calendar date', () => {
    expect(isCalendarDate('2026-8-8')).toBe(false);
    expect(isCalendarDate('08/08/2026')).toBe(false);
    expect(isCalendarDate('2026-08-08T00:00:00Z')).toBe(false);
    expect(isCalendarDate('')).toBe(false);
  });
});

describe('parseCalendarDate', () => {
  it('splits a date into its parts', () => {
    expect(parseCalendarDate('2026-08-08')).toEqual({ year: 2026, month: 8, day: 8 });
  });

  it('throws on a date that does not exist, rather than silently rolling over', () => {
    expect(() => parseCalendarDate('2026-02-30')).toThrow(RangeError);
  });
});

describe('daysBetween', () => {
  it('counts forward and backward from the mockup date', () => {
    expect(daysBetween('2026-08-08', '2026-08-15')).toBe(7);
    expect(daysBetween('2026-08-08', '2026-08-02')).toBe(-6);
    expect(daysBetween('2026-08-08', '2026-08-08')).toBe(0);
  });

  it('crosses a year boundary', () => {
    expect(daysBetween('2026-08-08', '2027-08-08')).toBe(365);
  });

  it('is unaffected by daylight saving, because arithmetic runs in UTC', () => {
    // Northern-hemisphere clock changes: late March and late October.
    expect(daysBetween('2026-03-28', '2026-03-30')).toBe(2);
    expect(daysBetween('2026-10-24', '2026-10-26')).toBe(2);
  });
});

describe('addMonths', () => {
  it('advances whole months', () => {
    expect(addMonths('2026-08-08', 1)).toBe('2026-09-08');
    expect(addMonths('2026-08-08', 6)).toBe('2027-02-08');
  });

  it('clamps to the end of a shorter month instead of skipping into the next', () => {
    expect(addMonths('2026-01-31', 1)).toBe('2026-02-28');
    expect(addMonths('2028-01-31', 1)).toBe('2028-02-29');
    expect(addMonths('2026-05-31', 1)).toBe('2026-06-30');
  });

  it('goes backwards across a year boundary', () => {
    expect(addMonths('2026-01-15', -1)).toBe('2025-12-15');
    expect(addMonths('2026-01-15', -13)).toBe('2024-12-15');
  });
});

describe('addYears and addDays', () => {
  it('advances a year', () => {
    expect(addYears('2026-08-08', 1)).toBe('2027-08-08');
  });

  it('clamps 29 February in a non-leap target year', () => {
    expect(addYears('2028-02-29', 1)).toBe('2029-02-28');
  });

  it('advances days across a month end', () => {
    expect(addDays('2026-08-30', 3)).toBe('2026-09-02');
    expect(addDays('2026-01-01', -1)).toBe('2025-12-31');
  });
});

describe('daysInMonth', () => {
  it('knows February in ordinary and leap years', () => {
    expect(daysInMonth(2026, 2)).toBe(28);
    expect(daysInMonth(2028, 2)).toBe(29);
    expect(daysInMonth(2026, 8)).toBe(31);
  });
});

describe('formatCalendarDate', () => {
  it('renders the format used throughout the mockups', () => {
    expect(formatCalendarDate('2026-08-08')).toBe('8 Aug 2026');
    expect(formatCalendarDate('2027-01-10')).toBe('10 Jan 2027');
  });

  it('falls back to an em dash when there is no date', () => {
    expect(formatCalendarDate(null)).toBe('—');
    expect(formatCalendarDate(null, 'No expiry')).toBe('No expiry');
  });
});

describe('today and toCalendarDate', () => {
  it('reads the UTC fields of a supplied clock', () => {
    expect(today(new Date('2026-08-08T23:30:00Z'))).toBe('2026-08-08');
    expect(toCalendarDate(new Date('2026-01-01T00:00:00Z'))).toBe('2026-01-01');
  });
});
