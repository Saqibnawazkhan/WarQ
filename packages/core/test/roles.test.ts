import { describe, expect, it } from 'vitest';

import {
  allowedPlatforms,
  canUsePlatform,
  isPlatform,
  isUserRole,
  landingRoute,
  PLATFORMS,
  platformDenialReason,
  requiresOrganization,
  roleLabel,
  USER_ROLES,
  type Platform,
  type UserRole,
} from '../src/index.js';

/** The access matrix, restated from the specification rather than from the code. */
const MATRIX: Record<UserRole, Record<Platform, boolean>> = {
  main_admin: { web: true, mobile: false },
  org_admin: { web: true, mobile: true },
  teacher: { web: true, mobile: true },
};

describe('platform access matrix', () => {
  for (const role of USER_ROLES) {
    for (const platform of PLATFORMS) {
      const expected = MATRIX[role][platform];
      it(`${role} on ${platform} → ${expected ? 'allowed' : 'blocked'}`, () => {
        expect(canUsePlatform(role, platform)).toBe(expected);
      });
    }
  }

  it('confines the Main Admin to the web dashboard', () => {
    expect(allowedPlatforms('main_admin')).toEqual(['web']);
  });

  it('gives Org Admins and Teachers both platforms', () => {
    expect(allowedPlatforms('org_admin')).toEqual(['web', 'mobile']);
    expect(allowedPlatforms('teacher')).toEqual(['web', 'mobile']);
  });
});

describe('platformDenialReason', () => {
  it('says nothing when the combination is allowed', () => {
    expect(platformDenialReason('teacher', 'mobile')).toBeNull();
    expect(platformDenialReason('main_admin', 'web')).toBeNull();
  });

  it('tells a Main Admin on a phone what to do instead', () => {
    const reason = platformDenialReason('main_admin', 'mobile');
    expect(reason).toBe(
      'The Main Admin dashboard is web only. Sign in at the web address on a computer.',
    );
  });
});

describe('landingRoute', () => {
  it('sends each role to its own dashboard', () => {
    expect(landingRoute('main_admin')).toBe('/admin');
    expect(landingRoute('org_admin')).toBe('/org');
    expect(landingRoute('teacher')).toBe('/teacher');
  });

  it('never sends two roles to the same place', () => {
    const routes = USER_ROLES.map(landingRoute);
    expect(new Set(routes).size).toBe(USER_ROLES.length);
  });
});

describe('guards', () => {
  it('recognises known roles and platforms and rejects the rest', () => {
    expect(isUserRole('teacher')).toBe(true);
    expect(isUserRole('superuser')).toBe(false);
    expect(isPlatform('mobile')).toBe(true);
    expect(isPlatform('desktop')).toBe(false);
  });

  it('requires an organization only for an Org Admin', () => {
    expect(requiresOrganization('org_admin')).toBe(true);
    // A teacher may be independent — the individual-teacher subscription path.
    expect(requiresOrganization('teacher')).toBe(false);
    expect(requiresOrganization('main_admin')).toBe(false);
  });

  it('labels every role for display', () => {
    expect(USER_ROLES.map(roleLabel)).toEqual(['Main Admin', 'Organization Admin', 'Teacher']);
  });
});
