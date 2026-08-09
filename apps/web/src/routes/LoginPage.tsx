import { useState, type FormEvent } from 'react';
import { Link, Navigate, useLocation, useNavigate } from 'react-router-dom';

import { landingRoute } from '@warq/core';
import { EmailNotConfirmedError, resendConfirmation, signIn } from '@warq/data';

import { useSession } from '../auth/session-context.ts';
import { FullPageWait } from '../auth/RequireRole.tsx';
import { supabase } from '../lib/supabase.ts';
import { Button, Field } from '../ui/index.ts';

export function LoginPage() {
  const { session, loading, refresh } = useSession();
  const navigate = useNavigate();
  const location = useLocation();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  /** Set when the password was right but the address is unconfirmed — offers a resend. */
  const [unconfirmed, setUnconfirmed] = useState<string | null>(null);
  const [resent, setResent] = useState(false);

  if (loading) return <FullPageWait />;

  // Already signed in — go where this role belongs rather than showing a form
  // that would immediately redirect anyway.
  if (session) {
    return <Navigate to={landingRoute(session.profile.role)} replace />;
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setUnconfirmed(null);
    setResent(false);
    setSubmitting(true);

    try {
      const result = await signIn(supabase, { email, password }, 'web');
      await refresh();

      const intended = (location.state as { from?: string } | null)?.from;
      void navigate(intended ?? landingRoute(result.profile.role), { replace: true });
    } catch (cause) {
      if (cause instanceof EmailNotConfirmedError) {
        setUnconfirmed(cause.email);
      }

      setError(
        cause instanceof Error ? cause.message : 'Something went wrong signing you in. Try again.',
      );
      setSubmitting(false);
    }
  }

  async function handleResend() {
    if (!unconfirmed) return;

    try {
      await resendConfirmation(supabase, unconfirmed);
      setResent(true);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not resend the email.');
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-canvas px-6 py-12">
      <div className="w-full max-w-sm">
        <div className="mb-8 flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-field bg-accent font-display text-lg font-extrabold text-on-accent">
            W
          </div>
          <span className="font-display text-xl font-extrabold tracking-tight">Warq</span>
        </div>

        <h1 className="font-display text-[27px] leading-tight font-bold text-balance">
          Your classroom,
          <br />
          managed in minutes.
        </h1>
        <p className="mt-2.5 text-[14px] leading-relaxed text-ink-muted">
          Attendance, marks, grades and reports for teachers and institutions.
        </p>

        <form
          onSubmit={(event) => void handleSubmit(event)}
          className="mt-8 flex flex-col gap-3.5"
          noValidate
        >
          <Field
            label="Email"
            type="email"
            autoComplete="email"
            required
            value={email}
            onChange={(event) => setEmail(event.target.value)}
            placeholder="you@school.edu.pk"
          />

          <Field
            label="Password"
            type="password"
            autoComplete="current-password"
            required
            value={password}
            onChange={(event) => setPassword(event.target.value)}
          />

          {error && (
            <div
              role="alert"
              className={
                unconfirmed
                  ? 'rounded-control bg-[#D977060F] px-3.5 py-2.5 text-[13px] text-ink-base'
                  : 'rounded-control bg-[#DC26260F] px-3.5 py-2.5 text-[13px] font-semibold text-expired'
              }
            >
              <p className={unconfirmed ? 'font-semibold text-pending' : undefined}>{error}</p>

              {unconfirmed &&
                (resent ? (
                  <p className="mt-1.5 text-ink-muted">
                    Sent again to {unconfirmed}. Check the spam folder too.
                  </p>
                ) : (
                  <button
                    type="button"
                    onClick={() => void handleResend()}
                    className="mt-1.5 cursor-pointer font-bold text-accent underline underline-offset-2"
                  >
                    Send the confirmation email again
                  </button>
                ))}
            </div>
          )}

          <Button type="submit" disabled={submitting} className="mt-1 h-12 w-full">
            {submitting ? 'Signing in…' : 'Sign in'}
          </Button>
        </form>

        <div className="mt-5 flex justify-between text-[12.5px] font-bold">
          <Link to="/forgot-password" className="text-ink-muted hover:text-ink-base">
            Forgot password?
          </Link>
          <Link to="/signup" className="text-accent hover:underline">
            Create an account
          </Link>
        </div>
      </div>
    </main>
  );
}
