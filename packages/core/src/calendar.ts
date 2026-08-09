/**
 * Calendar dates.
 *
 * Attendance, term dates and subscription periods are calendar facts, not
 * instants: a subscription that ends on 15 August ends on that date in Lahore
 * and in London alike. They are stored and passed around as `YYYY-MM-DD`
 * strings, and all arithmetic runs in UTC so a daylight-saving shift can never
 * move a date by a day.
 */

/** An ISO calendar date, `YYYY-MM-DD`. Never a timestamp. */
export type CalendarDate = string;

const PATTERN = /^\d{4}-\d{2}-\d{2}$/;

const MONTH_NAMES = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
] as const;

const MS_PER_DAY = 86_400_000;

export interface DateParts {
  readonly year: number;
  readonly month: number;
  readonly day: number;
}

/** True when the value is a well-formed date that actually exists. */
export function isCalendarDate(value: string): boolean {
  if (!PATTERN.test(value)) return false;
  const parts = splitParts(value);
  if (!parts) return false;
  return toCalendarDate(toUtc(parts)) === value;
}

function splitParts(value: string): DateParts | null {
  const [rawYear, rawMonth, rawDay] = value.split('-');
  if (rawYear === undefined || rawMonth === undefined || rawDay === undefined) return null;

  const year = Number(rawYear);
  const month = Number(rawMonth);
  const day = Number(rawDay);
  if (!Number.isInteger(year) || !Number.isInteger(month) || !Number.isInteger(day)) return null;

  return { year, month, day };
}

/** Parses a date, throwing on anything malformed or non-existent. */
export function parseCalendarDate(value: CalendarDate): DateParts {
  const parts = splitParts(value);
  if (!parts || !isCalendarDate(value)) {
    throw new RangeError(`Not a calendar date: ${value}`);
  }
  return parts;
}

function toUtc({ year, month, day }: DateParts): Date {
  return new Date(Date.UTC(year, month - 1, day));
}

/** Renders a `Date` as a calendar date, reading its UTC fields. */
export function toCalendarDate(date: Date): CalendarDate {
  const year = String(date.getUTCFullYear()).padStart(4, '0');
  const month = String(date.getUTCMonth() + 1).padStart(2, '0');
  const day = String(date.getUTCDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

/**
 * Whole days from `from` to `to`. Negative when `to` is in the past.
 * `daysBetween('2026-08-08', '2026-08-15')` is 7.
 */
export function daysBetween(from: CalendarDate, to: CalendarDate): number {
  const a = toUtc(parseCalendarDate(from)).getTime();
  const b = toUtc(parseCalendarDate(to)).getTime();
  return Math.round((b - a) / MS_PER_DAY);
}

export function addDays(date: CalendarDate, days: number): CalendarDate {
  const base = toUtc(parseCalendarDate(date));
  base.setUTCDate(base.getUTCDate() + days);
  return toCalendarDate(base);
}

/**
 * Adds whole months, clamping to the end of the target month.
 * 31 January plus one month is 28 February — never 3 March. A subscription
 * bought on the 31st must not silently skip a month.
 */
export function addMonths(date: CalendarDate, months: number): CalendarDate {
  const { year, month, day } = parseCalendarDate(date);
  const zeroBased = month - 1 + months;
  const targetYear = year + Math.floor(zeroBased / 12);
  const targetMonth = ((zeroBased % 12) + 12) % 12;
  const lastDay = daysInMonth(targetYear, targetMonth + 1);
  return toCalendarDate(new Date(Date.UTC(targetYear, targetMonth, Math.min(day, lastDay))));
}

export function addYears(date: CalendarDate, years: number): CalendarDate {
  return addMonths(date, years * 12);
}

/** Days in a one-based month. Handles leap years. */
export function daysInMonth(year: number, month: number): number {
  return new Date(Date.UTC(year, month, 0)).getUTCDate();
}

/** `2026-08-08` → `8 Aug 2026`, the format used throughout the mockups. */
export function formatCalendarDate(date: CalendarDate | null, fallback = '—'): string {
  if (date === null) return fallback;
  const { year, month, day } = parseCalendarDate(date);
  return `${day} ${MONTH_NAMES[month - 1] ?? '???'} ${year}`;
}

/** Today, as a calendar date, in UTC. Pass a clock in tests rather than mocking `Date`. */
export function today(now: Date = new Date()): CalendarDate {
  return toCalendarDate(now);
}
