import { describe, expect, it } from 'vitest';

import {
  calendarDateSchema,
  initials,
  inviteTeacherSchema,
  organizationRequestSchema,
  pluralize,
  possessive,
  saveAttendanceSchema,
  saveMarksSchema,
  seriesIndex,
  signInSchema,
} from '../src/index.js';

const UUID = '3f2504e0-4f89-41d3-9a0c-0305e82c3301';

describe('calendarDateSchema', () => {
  it('accepts a real date', () => {
    expect(calendarDateSchema.parse('2026-08-08')).toBe('2026-08-08');
  });

  it('rejects a date that does not exist, with a message a person can act on', () => {
    const result = calendarDateSchema.safeParse('2026-02-30');
    expect(result.success).toBe(false);
    if (!result.success) {
      expect(result.error.issues[0]?.message).toBe('Use a real date in YYYY-MM-DD form.');
    }
  });
});

describe('signInSchema', () => {
  it('normalises the email and keeps the platform the client declared', () => {
    const parsed = signInSchema.parse({
      email: '  Admin@EduManager.PK ',
      password: 'correct-horse',
      platform: 'web',
    });
    expect(parsed.email).toBe('admin@edumanager.pk');
    expect(parsed.platform).toBe('web');
  });

  it('rejects a short password', () => {
    const result = signInSchema.safeParse({
      email: 'a@b.pk',
      password: 'short',
      platform: 'web',
    });
    expect(result.success).toBe(false);
  });

  it('rejects an unknown platform', () => {
    const result = signInSchema.safeParse({
      email: 'a@b.pk',
      password: 'correct-horse',
      platform: 'desktop',
    });
    expect(result.success).toBe(false);
  });
});

describe('organizationRequestSchema', () => {
  it('accepts a request shaped like the mockup fixtures', () => {
    const parsed = organizationRequestSchema.parse({
      organizationName: 'Superior Science Academy',
      city: 'Multan',
      adminName: 'Tahir Jamil',
      email: 'ssa.multan@outlook.com',
      phone: '061 4552 118',
      plan: 'yearly',
    });
    expect(parsed.organizationName).toBe('Superior Science Academy');
    expect(parsed.plan).toBe('yearly');
  });

  it('rejects a phone number containing letters', () => {
    const result = organizationRequestSchema.safeParse({
      organizationName: 'Iqra Model School',
      city: 'Faisalabad',
      adminName: 'Bushra Anwar',
      email: 'iqra.fsd@gmail.com',
      phone: 'call me',
      plan: 'monthly',
    });
    expect(result.success).toBe(false);
  });
});

describe('inviteTeacherSchema', () => {
  it('accepts both delivery channels the mockups offer', () => {
    for (const sendVia of ['email', 'whatsapp'] as const) {
      const parsed = inviteTeacherSchema.parse({
        fullName: 'Farhan Saeed',
        email: 'farhan.saeed@pcit.edu.pk',
        sendVia,
      });
      expect(parsed.sendVia).toBe(sendVia);
    }
  });
});

describe('saveAttendanceSchema', () => {
  it('accepts a roll call', () => {
    const parsed = saveAttendanceSchema.parse({
      classId: UUID,
      date: '2026-08-08',
      entries: [{ studentId: UUID, mark: 'absent' }],
    });
    expect(parsed.entries).toHaveLength(1);
  });

  it('rejects an empty roll call, which would silently wipe a session', () => {
    const result = saveAttendanceSchema.safeParse({
      classId: UUID,
      date: '2026-08-08',
      entries: [],
    });
    expect(result.success).toBe(false);
  });
});

describe('saveMarksSchema', () => {
  it('treats a blank box as unmarked rather than as a zero', () => {
    const parsed = saveMarksSchema.parse({
      assessmentId: UUID,
      entries: [{ studentId: UUID, score: null }],
    });
    expect(parsed.entries[0]?.score).toBeNull();
  });

  it('rejects a negative score', () => {
    const result = saveMarksSchema.safeParse({
      assessmentId: UUID,
      entries: [{ studentId: UUID, score: -1 }],
    });
    expect(result.success).toBe(false);
  });
});

describe('text helpers', () => {
  it('builds avatar initials the way the mockups do', () => {
    expect(initials('Ayesha Rehman')).toBe('AR');
    expect(initials('Zeeshan Haider')).toBe('ZH');
    expect(initials('Punjab College of IT', 2)).toBe('PC');
    expect(initials('Ali')).toBe('A');
    expect(initials('   ')).toBe('');
  });

  it('forms a possessive for absence alerts', () => {
    expect(possessive('Sara Malik')).toBe('Sara Malik’s');
    expect(possessive('Ms Jones')).toBe('Ms Jones’');
  });

  it('pluralises counts', () => {
    expect(pluralize(1, 'absence alert')).toBe('1 absence alert');
    expect(pluralize(3, 'absence alert')).toBe('3 absence alerts');
    expect(pluralize(2, 'class', 'classes')).toBe('2 classes');
  });

  it('assigns a stable series colour to a class', () => {
    const first = seriesIndex('software-engineering-a', 6);
    expect(first).toBe(seriesIndex('software-engineering-a', 6));
    expect(first).toBeGreaterThanOrEqual(0);
    expect(first).toBeLessThan(6);
  });
});
