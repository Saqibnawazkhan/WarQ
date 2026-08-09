/**
 * Marks and grades.
 *
 * The default bands are the ones drawn in the mockups. They are a default and
 * not a law: institutions grade differently, so a scale is stored per
 * organization and passed in wherever a grade is computed.
 */

export const GRADES = ['A+', 'A', 'B', 'C', 'D', 'F'] as const;
export type Grade = (typeof GRADES)[number];

export interface GradeBand {
  readonly grade: Grade;
  /** Lowest percentage, inclusive, that earns this grade. */
  readonly min: number;
}

/** Highest band first — `gradeFor` takes the first match. */
export const DEFAULT_GRADE_SCALE: readonly GradeBand[] = [
  { grade: 'A+', min: 90 },
  { grade: 'A', min: 80 },
  { grade: 'B', min: 70 },
  { grade: 'C', min: 60 },
  { grade: 'D', min: 50 },
  { grade: 'F', min: 0 },
];

export function isGrade(value: string): value is Grade {
  return (GRADES as readonly string[]).includes(value);
}

/**
 * A scale is usable when it descends without gaps and bottoms out at zero, so
 * every percentage from 0 to 100 lands in exactly one band.
 */
export function isValidGradeScale(scale: readonly GradeBand[]): boolean {
  if (scale.length === 0) return false;

  const last = scale[scale.length - 1];
  if (!last || last.min !== 0) return false;

  return scale.every((band, index) => {
    if (band.min < 0 || band.min > 100) return false;
    if (index === 0) return true;
    const previous = scale[index - 1];
    return previous !== undefined && previous.min > band.min;
  });
}

/** The grade a percentage earns. Values outside 0–100 are clamped. */
export function gradeFor(
  percent: number,
  scale: readonly GradeBand[] = DEFAULT_GRADE_SCALE,
): Grade {
  const clamped = Math.min(100, Math.max(0, percent));
  for (const band of scale) {
    if (clamped >= band.min) return band.grade;
  }
  // Unreachable for a valid scale; the floor band is the honest fallback.
  return 'F';
}

/** A whole-number percentage. A total of zero scores zero rather than dividing by it. */
export function percentage(score: number, total: number): number {
  if (total <= 0) return 0;
  return Math.round((score / total) * 100);
}

/** One assessment's contribution to a student's record. `null` means not yet marked. */
export interface ScoreLine {
  readonly score: number | null;
  readonly total: number;
}

export interface Aggregate {
  readonly obtained: number;
  readonly total: number;
  readonly percent: number;
  readonly grade: Grade;
  /** How many assessments have been marked so far. */
  readonly marked: number;
  /** How many are still outstanding. */
  readonly pending: number;
}

/**
 * Rolls a student's marks into an overall figure.
 *
 * Unmarked assessments are left out of both sides of the fraction. A student is
 * not failed for work the teacher has not graded yet.
 */
export function aggregate(
  lines: readonly ScoreLine[],
  scale: readonly GradeBand[] = DEFAULT_GRADE_SCALE,
): Aggregate {
  let obtained = 0;
  let total = 0;
  let marked = 0;

  for (const line of lines) {
    if (line.score === null) continue;
    obtained += line.score;
    total += line.total;
    marked += 1;
  }

  const percent = percentage(obtained, total);

  return {
    obtained,
    total,
    percent,
    grade: gradeFor(percent, scale),
    marked,
    pending: lines.length - marked,
  };
}

/** Class average for one assessment, as a percentage. `null` when nobody is marked. */
export function classAverage(scores: readonly (number | null)[], total: number): number | null {
  const marked = scores.filter((score): score is number => score !== null);
  if (marked.length === 0 || total <= 0) return null;

  const sum = marked.reduce((running, score) => running + score / total, 0);
  return Math.round((sum / marked.length) * 100);
}
