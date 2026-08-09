/**
 * Roles and platform access.
 *
 * The access matrix is the product rule, stated once. Route guards, the session
 * guard and the database policies all read it from here, so they cannot drift
 * apart from each other.
 */

export const USER_ROLES = ['main_admin', 'org_admin', 'teacher'] as const;
export type UserRole = (typeof USER_ROLES)[number];

export const PLATFORMS = ['web', 'mobile'] as const;
export type Platform = (typeof PLATFORMS)[number];

/**
 * Which platforms each role may sign in on.
 *
 * The Main Admin manages the whole SaaS estate from a desk and is deliberately
 * confined to the web dashboard; the mobile app has no administrator surface.
 */
const PLATFORM_ACCESS: Readonly<Record<UserRole, readonly Platform[]>> = {
  main_admin: ['web'],
  org_admin: ['web', 'mobile'],
  teacher: ['web', 'mobile'],
};

/** Where each role lands after signing in. */
const LANDING_ROUTE: Readonly<Record<UserRole, string>> = {
  main_admin: '/admin',
  org_admin: '/org',
  teacher: '/teacher',
};

const ROLE_LABEL: Readonly<Record<UserRole, string>> = {
  main_admin: 'Main Admin',
  org_admin: 'Organization Admin',
  teacher: 'Teacher',
};

export function isUserRole(value: string): value is UserRole {
  return (USER_ROLES as readonly string[]).includes(value);
}

export function isPlatform(value: string): value is Platform {
  return (PLATFORMS as readonly string[]).includes(value);
}

export function allowedPlatforms(role: UserRole): readonly Platform[] {
  return PLATFORM_ACCESS[role];
}

export function canUsePlatform(role: UserRole, platform: Platform): boolean {
  return PLATFORM_ACCESS[role].includes(platform);
}

export function landingRoute(role: UserRole): string {
  return LANDING_ROUTE[role];
}

export function roleLabel(role: UserRole): string {
  return ROLE_LABEL[role];
}

/**
 * The message shown when a sign-in is refused on platform grounds, or `null`
 * when the combination is allowed. Errors say what to do next, not just what broke.
 */
export function platformDenialReason(role: UserRole, platform: Platform): string | null {
  if (canUsePlatform(role, platform)) return null;
  if (role === 'main_admin' && platform === 'mobile') {
    return 'The Main Admin dashboard is web only. Sign in at the web address on a computer.';
  }
  return `${roleLabel(role)} accounts cannot sign in on ${platform}.`;
}

/** Org Admins and Teachers belong to an organization; individual teachers do not. */
export function requiresOrganization(role: UserRole): boolean {
  return role === 'org_admin';
}
