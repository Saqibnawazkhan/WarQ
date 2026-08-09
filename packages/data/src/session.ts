/**
 * Signing in, signing out, and finding out who is signed in.
 *
 * The platform rule from the access matrix is applied here, in the client, and
 * again by the database policies. This layer exists to give a person a sentence
 * they can act on; the database layer exists because a person is not the only
 * thing that makes requests.
 */

import { canUsePlatform, isUserRole, platformDenialReason, type Platform } from '@warq/core';

import type { WarqClient } from './client.js';
import type { EffectiveSubscription, Organization, Profile, WarqSession } from './types.js';

/** Raised when the credentials are fine but the role may not use this platform. */
export class PlatformNotPermittedError extends Error {
  override readonly name = 'PlatformNotPermittedError';

  constructor(message: string) {
    super(message);
  }
}

/**
 * Raised when the password was right but the address has never been confirmed.
 *
 * Distinguished from a wrong password deliberately. Collapsing the two would
 * tell someone their password is wrong when it is not, and they would reset it
 * repeatedly without ever getting in. Naming it is not a disclosure risk either:
 * the password was already correct, so the person asking is the account holder.
 */
export class EmailNotConfirmedError extends Error {
  override readonly name = 'EmailNotConfirmedError';
  readonly email: string;

  constructor(email: string) {
    super('Confirm your email address first. Open the link Warq sent you, then sign in again.');
    this.email = email;
  }
}

interface RawSession {
  profile: Profile;
  organization: Organization | null;
  subscription: EffectiveSubscription | null;
  has_access: boolean;
}

/**
 * The current session, or null when nobody is signed in.
 *
 * One `me()` call rather than four queries — worth the RPC on a phone in a
 * classroom, where every round trip is felt.
 */
export async function getSession(client: WarqClient): Promise<WarqSession | null> {
  const { data, error } = await client.rpc('me');

  if (error) {
    throw new Error(`Could not load your account: ${error.message}`);
  }

  if (!data) return null;

  const raw = data as unknown as RawSession;

  return {
    profile: raw.profile,
    organization: raw.organization,
    subscription: raw.subscription,
    hasAccess: raw.has_access,
  };
}

/**
 * Signs in and returns the session.
 *
 * A role that may not use this platform is signed straight back out, so no
 * usable token is left behind on the device.
 */
export async function signIn(
  client: WarqClient,
  credentials: { email: string; password: string },
  platform: Platform,
): Promise<WarqSession> {
  const email = credentials.email.trim().toLowerCase();

  const { error } = await client.auth.signInWithPassword({
    email,
    password: credentials.password,
  });

  if (error) {
    // The password was right; only the address is unverified. Say so, because
    // otherwise the only remedy anyone will try is resetting a password that
    // was never wrong.
    if (error.code === 'email_not_confirmed') {
      throw new EmailNotConfirmedError(email);
    }

    // Everything else is deliberately indistinguishable. "No such account" and
    // "wrong password" must read identically, or the form becomes a way to
    // discover which addresses are registered.
    throw new Error('That email address and password do not match an account.');
  }

  const session = await getSession(client);

  if (!session) {
    await client.auth.signOut();
    throw new Error('Your account is not set up yet. Contact your administrator.');
  }

  const { role } = session.profile;

  if (!isUserRole(role)) {
    await client.auth.signOut();
    throw new Error('Your account has no role assigned. Contact your administrator.');
  }

  if (!canUsePlatform(role, platform)) {
    await client.auth.signOut();
    throw new PlatformNotPermittedError(
      platformDenialReason(role, platform) ?? 'This account cannot sign in here.',
    );
  }

  return session;
}

export async function signOut(client: WarqClient): Promise<void> {
  const { error } = await client.auth.signOut();
  if (error) {
    throw new Error(`Could not sign you out: ${error.message}`);
  }
}

/** Sends the confirmation email again. For someone who lost or never got the first one. */
export async function resendConfirmation(client: WarqClient, email: string): Promise<void> {
  const { error } = await client.auth.resend({
    type: 'signup',
    email: email.trim().toLowerCase(),
  });

  if (error) {
    throw new Error(`Could not send the confirmation email: ${error.message}`);
  }
}

export async function requestPasswordReset(
  client: WarqClient,
  email: string,
  redirectTo: string,
): Promise<void> {
  const { error } = await client.auth.resetPasswordForEmail(email.trim().toLowerCase(), {
    redirectTo,
  });

  // Deliberately not surfaced to the caller as a failure for an unknown address —
  // the confirmation message is the same either way, so the form cannot be used
  // to discover who has an account.
  if (error && !/user not found/i.test(error.message)) {
    throw new Error(`Could not send the reset link: ${error.message}`);
  }
}
