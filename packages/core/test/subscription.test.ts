import { describe, expect, it } from 'vitest';

import {
  approve,
  daysRemaining,
  effectiveStatus,
  hasAccess,
  periodEnd,
  reactivate,
  reminderDueToday,
  renew,
  suspend,
  type Subscription,
} from '../src/index.js';

/** The date the mockups are drawn on. Every expectation below is read off them. */
const TODAY = '2026-08-08';

function sub(partial: Partial<Subscription>): Subscription {
  return {
    plan: 'monthly',
    status: 'active',
    startsAt: '2026-07-15',
    endsAt: '2026-08-15',
    ...partial,
  };
}

describe('effectiveStatus — reproduces every badge in the Main Admin mockup', () => {
  it('Punjab College of IT · yearly to Aug 2027 · Active', () => {
    const status = effectiveStatus(
      sub({ plan: 'yearly', startsAt: '2025-08-08', endsAt: '2027-08-08' }),
      TODAY,
    );
    expect(status).toBe('active');
  });

  it('The Educators Academy · monthly, 7 days out · Expiring Soon', () => {
    expect(effectiveStatus(sub({ endsAt: '2026-08-15' }), TODAY)).toBe('expiring_soon');
  });

  it('Iqra Model School · monthly, ended 6 days ago · Expired', () => {
    expect(effectiveStatus(sub({ endsAt: '2026-08-02' }), TODAY)).toBe('expired');
  });

  it('Al-Huda Girls College · permanent · Active with no expiry', () => {
    const permanent = sub({ plan: 'permanent', startsAt: '2025-05-20', endsAt: null });
    expect(effectiveStatus(permanent, TODAY)).toBe('active');
    expect(daysRemaining(permanent, TODAY)).toBeNull();
  });

  it('Superior Science Academy · awaiting approval · Pending', () => {
    expect(effectiveStatus(sub({ status: 'pending', startsAt: null, endsAt: null }), TODAY)).toBe(
      'pending',
    );
  });

  it('Cornerstone Tuition Centre · payment failed · Suspended', () => {
    expect(effectiveStatus(sub({ status: 'suspended', endsAt: '2026-07-12' }), TODAY)).toBe(
      'suspended',
    );
  });

  it('Kashif Mahmood · individual teacher, 10 days out · Expiring Soon', () => {
    expect(effectiveStatus(sub({ endsAt: '2026-08-18' }), TODAY)).toBe('expiring_soon');
  });

  it('Junaid Akram · individual teacher, 24 days out · still Active', () => {
    expect(effectiveStatus(sub({ endsAt: '2026-09-01' }), TODAY)).toBe('active');
  });
});

describe('effectiveStatus — boundaries', () => {
  it('expires the day after the end date, not on it', () => {
    expect(effectiveStatus(sub({ endsAt: TODAY }), TODAY)).toBe('expiring_soon');
    expect(effectiveStatus(sub({ endsAt: '2026-08-07' }), TODAY)).toBe('expired');
  });

  it('warns from exactly a fortnight out', () => {
    expect(effectiveStatus(sub({ endsAt: '2026-08-22' }), TODAY)).toBe('expiring_soon');
    expect(effectiveStatus(sub({ endsAt: '2026-08-23' }), TODAY)).toBe('active');
  });

  it('an administrator decision outranks the calendar', () => {
    const lapsedButSuspended = sub({ status: 'suspended', endsAt: '2020-01-01' });
    expect(effectiveStatus(lapsedButSuspended, TODAY)).toBe('suspended');
  });

  it('refuses to grant unbounded access to a dated plan with no end date', () => {
    expect(effectiveStatus(sub({ status: 'active', endsAt: null }), TODAY)).toBe('pending');
  });
});

describe('hasAccess', () => {
  it('lets a warned customer keep working, and stops everyone else', () => {
    expect(hasAccess('active')).toBe(true);
    expect(hasAccess('expiring_soon')).toBe(true);
    expect(hasAccess('pending')).toBe(false);
    expect(hasAccess('expired')).toBe(false);
    expect(hasAccess('suspended')).toBe(false);
  });
});

describe('periodEnd', () => {
  it('advances a month, a year, or never', () => {
    expect(periodEnd('monthly', TODAY)).toBe('2026-09-08');
    expect(periodEnd('yearly', TODAY)).toBe('2027-08-08');
    expect(periodEnd('permanent', TODAY)).toBeNull();
  });

  it('clamps rather than skipping a month', () => {
    expect(periodEnd('monthly', '2026-01-31')).toBe('2026-02-28');
    expect(periodEnd('monthly', '2028-01-31')).toBe('2028-02-29');
  });
});

describe('renew', () => {
  it('runs from the current end date so early renewal loses no days', () => {
    const renewed = renew(sub({ plan: 'yearly', endsAt: '2027-08-08' }), TODAY);
    expect(renewed.endsAt).toBe('2028-08-08');
    expect(renewed.status).toBe('active');
  });

  it('restarts from today when the subscription has already lapsed', () => {
    const renewed = renew(sub({ endsAt: '2026-08-02' }), TODAY);
    expect(renewed.endsAt).toBe('2026-09-08');
  });

  it('leaves a permanent plan without an end date', () => {
    const renewed = renew(sub({ plan: 'permanent', endsAt: null }), TODAY);
    expect(renewed.endsAt).toBeNull();
    expect(renewed.status).toBe('active');
  });
});

describe('approve, suspend, reactivate', () => {
  it('approving a pending request starts the first period today', () => {
    const approved = approve(
      sub({ plan: 'yearly', status: 'pending', startsAt: null, endsAt: null }),
      TODAY,
    );
    expect(approved).toMatchObject({ status: 'active', startsAt: TODAY, endsAt: '2027-08-08' });
  });

  it('suspending then reactivating restores access without touching the dates', () => {
    const original = sub({ endsAt: '2026-08-15' });
    const restored = reactivate(suspend(original));
    expect(restored.status).toBe('active');
    expect(restored.endsAt).toBe(original.endsAt);
    expect(effectiveStatus(restored, TODAY)).toBe('expiring_soon');
  });
});

describe('reminderDueToday', () => {
  it('fires on the scheduled day and stays silent on every other day', () => {
    expect(reminderDueToday(sub({ endsAt: '2026-08-15' }), TODAY)).toBe(7);
    expect(reminderDueToday(sub({ endsAt: '2026-08-11' }), TODAY)).toBe(3);
    expect(reminderDueToday(sub({ endsAt: '2026-08-14' }), TODAY)).toBeNull();
  });

  it('honours the offsets the Main Admin has switched off', () => {
    const seven = sub({ endsAt: '2026-08-15' });
    expect(reminderDueToday(seven, TODAY, [30, 15, 1])).toBeNull();
    expect(reminderDueToday(seven, TODAY, [30, 15, 7, 3, 1])).toBe(7);
  });

  it('does not chase a subscription that has already expired or is suspended', () => {
    expect(reminderDueToday(sub({ endsAt: '2026-08-02' }), TODAY)).toBeNull();
    expect(reminderDueToday(sub({ status: 'suspended', endsAt: '2026-08-15' }), TODAY)).toBeNull();
  });

  it('never chases a permanent plan', () => {
    expect(reminderDueToday(sub({ plan: 'permanent', endsAt: null }), TODAY)).toBeNull();
  });
});
