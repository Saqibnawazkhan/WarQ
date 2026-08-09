import { describe, expect, it } from 'vitest';

import {
  aggregate,
  classAverage,
  DEFAULT_GRADE_SCALE,
  gradeFor,
  isValidGradeScale,
  percentage,
  type GradeBand,
  type ScoreLine,
} from '../src/index.js';

/** Software Engineering · A — the assessment totals from the mobile mockup. */
const TOTALS = [20, 20, 10, 50] as const;

function linesFor(scores: readonly (number | null)[]): ScoreLine[] {
  return scores.map((score, index) => ({ score, total: TOTALS[index] ?? 0 }));
}

describe('gradeFor — the bands drawn in the mockups', () => {
  it.each([
    [100, 'A+'],
    [90, 'A+'],
    [89, 'A'],
    [80, 'A'],
    [79, 'B'],
    [70, 'B'],
    [69, 'C'],
    [60, 'C'],
    [59, 'D'],
    [50, 'D'],
    [49, 'F'],
    [0, 'F'],
  ])('%i%% earns %s', (percent, grade) => {
    expect(gradeFor(percent)).toBe(grade);
  });

  it('clamps a percentage that lands outside 0–100', () => {
    expect(gradeFor(140)).toBe('A+');
    expect(gradeFor(-10)).toBe('F');
  });

  it('honours a scale an organization has customised', () => {
    const lenient: GradeBand[] = [
      { grade: 'A', min: 70 },
      { grade: 'B', min: 55 },
      { grade: 'F', min: 0 },
    ];
    expect(gradeFor(72, lenient)).toBe('A');
    expect(gradeFor(60, lenient)).toBe('B');
    expect(gradeFor(54, lenient)).toBe('F');
  });
});

describe('isValidGradeScale', () => {
  it('accepts the default', () => {
    expect(isValidGradeScale(DEFAULT_GRADE_SCALE)).toBe(true);
  });

  it('rejects a scale with a gap at the bottom, which would leave 0–49 ungraded', () => {
    expect(
      isValidGradeScale([
        { grade: 'A', min: 80 },
        { grade: 'B', min: 50 },
      ]),
    ).toBe(false);
  });

  it('rejects bands that do not descend', () => {
    expect(
      isValidGradeScale([
        { grade: 'A', min: 50 },
        { grade: 'B', min: 80 },
        { grade: 'F', min: 0 },
      ]),
    ).toBe(false);
  });

  it('rejects an empty scale', () => {
    expect(isValidGradeScale([])).toBe(false);
  });
});

describe('percentage', () => {
  it('rounds to a whole number', () => {
    expect(percentage(39, 50)).toBe(78);
    expect(percentage(1, 3)).toBe(33);
  });

  it('returns zero rather than dividing by zero', () => {
    expect(percentage(0, 0)).toBe(0);
    expect(percentage(5, 0)).toBe(0);
  });
});

describe('aggregate — real students from the mockup roster', () => {
  it('Zainab Bibi · 19+20+10+48 of 100 · A+', () => {
    expect(aggregate(linesFor([19, 20, 10, 48]))).toMatchObject({
      obtained: 97,
      total: 100,
      percent: 97,
      grade: 'A+',
      marked: 4,
      pending: 0,
    });
  });

  it('Ahmed Khan · 14+16+8+39 of 100 · B', () => {
    expect(aggregate(linesFor([14, 16, 8, 39]))).toMatchObject({
      obtained: 77,
      percent: 77,
      grade: 'B',
    });
  });

  it('Usman Tariq · 12+10+5+26 of 100 · D', () => {
    expect(aggregate(linesFor([12, 10, 5, 26]))).toMatchObject({
      obtained: 53,
      percent: 53,
      grade: 'D',
    });
  });

  it('leaves unmarked work out of both sides, so a student is not failed for it', () => {
    const partial = aggregate(linesFor([18, 17, null, null]));
    expect(partial).toMatchObject({
      obtained: 35,
      total: 40,
      percent: 88,
      grade: 'A',
      marked: 2,
      pending: 2,
    });
  });

  it('reports a student with nothing marked as ungraded rather than failing', () => {
    const none = aggregate(linesFor([null, null, null, null]));
    expect(none).toMatchObject({ obtained: 0, total: 0, marked: 0, pending: 4 });
  });
});

describe('classAverage', () => {
  it('averages the marked scores as a percentage of the total', () => {
    expect(classAverage([14, 18, 20, 16], 20)).toBe(85);
  });

  it('ignores students who have not been marked', () => {
    expect(classAverage([10, null, null, 20], 20)).toBe(75);
  });

  it('is null when nobody has been marked, which is not the same as zero', () => {
    expect(classAverage([null, null], 20)).toBeNull();
    expect(classAverage([], 20)).toBeNull();
  });
});
