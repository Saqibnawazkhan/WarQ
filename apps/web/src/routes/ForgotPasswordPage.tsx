import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';

import { requestPasswordReset } from '@warq/data';

import { supabase } from '../lib/supabase.ts';
import { Button, Field } from '../ui/index.ts';

export function ForgotPasswordPage() {
  const [email, setEmail] = useState('');
  const [sent, setSent] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);

    try {
      await requestPasswordReset(supabase, email, `${window.location.origin}/reset-password`);
      setSent(true);
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'Could not send the reset link.');
      setSubmitting(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-canvas px-6 py-12">
      <div className="w-full max-w-sm">
        <h1 className="font-display text-2xl font-bold">Reset your password</h1>

        {sent ? (
          <>
            {/*
              Deliberately says "if there is an account" rather than confirming
              one exists. Otherwise this form becomes a way to discover which
              addresses are registered.
            */}
            <p className="mt-3 leading-relaxed text-ink-base">
              If there is a Warq account for <strong>{email}</strong>, a reset link is on its way.
              The link is valid for one hour.
            </p>
            <p className="mt-3 text-[13px] text-ink-muted">
              Nothing arrived? Check the spam folder, then try again.
            </p>
          </>
        ) : (
          <>
            <p className="mt-2 text-[14px] text-ink-muted">
              Enter your email address and we will send you a link to set a new one.
            </p>

            <form
              onSubmit={(event) => void handleSubmit(event)}
              className="mt-6 flex flex-col gap-3.5"
              noValidate
            >
              <Field
                label="Email"
                type="email"
                required
                autoComplete="email"
                value={email}
                onChange={(event) => setEmail(event.target.value)}
              />

              {error && (
                <p
                  role="alert"
                  className="rounded-control bg-[#DC26260F] px-3.5 py-2.5 text-[13px] font-semibold text-expired"
                >
                  {error}
                </p>
              )}

              <Button type="submit" disabled={submitting} className="mt-1 h-12 w-full">
                {submitting ? 'Sending…' : 'Send reset link'}
              </Button>
            </form>
          </>
        )}

        <p className="mt-6 text-center text-[12.5px] font-bold">
          <Link to="/login" className="text-accent hover:underline">
            Back to sign in
          </Link>
        </p>
      </div>
    </main>
  );
}
