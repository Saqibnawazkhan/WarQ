import { useState, type FormEvent } from 'react';
import { Link, useNavigate, useParams } from 'react-router-dom';

import { landingRoute } from '@warq/core';

import { useSession } from '../auth/session-context.ts';
import { supabase } from '../lib/supabase.ts';
import { Button, Card, Field } from '../ui/index.ts';

/**
 * Accepting an invitation.
 *
 * A token in the URL is a credential, so the whole exchange happens in the
 * database: `accept_invitation` checks the token is live, unexpired, and issued
 * to the address of whoever is signed in. A link forwarded to a colleague does
 * nothing for them.
 *
 * The invitee may or may not already have an account, so this page handles both
 * without asking them to work out which they are.
 */
export function JoinPage() {
  const { token } = useParams<{ token: string }>();
  const { session, refresh } = useSession();
  const navigate = useNavigate();

  const [fullName, setFullName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function accept() {
    const { error: rpcError } = await supabase.rpc('accept_invitation', {
      invitation_token: token ?? '',
    });

    if (rpcError) throw new Error(rpcError.message);

    await refresh();
    void navigate(landingRoute('teacher'), { replace: true });
  }

  /** Already signed in — just exchange the token. */
  async function handleAcceptOnly() {
    setError(null);
    setBusy(true);

    try {
      await accept();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'That invitation could not be accepted.');
      setBusy(false);
    }
  }

  /** Not signed in — create the account, then exchange the token. */
  async function handleSignUp(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setBusy(true);

    try {
      const { error: signUpError } = await supabase.auth.signUp({
        email: email.trim().toLowerCase(),
        password,
        // No signup_kind: an invited teacher gets no organization and no
        // subscription until the token is exchanged, so an unused invitation
        // leaves nothing behind.
        options: { data: { full_name: fullName.trim() } },
      });

      if (signUpError) {
        throw new Error(
          /already registered/i.test(signUpError.message)
            ? 'You already have an account. Sign in first, then open this link again.'
            : signUpError.message,
        );
      }

      const { data } = await supabase.auth.getSession();

      if (!data.session) {
        // Email confirmation is switched on, so there is no session to accept
        // with yet. Say what happens next rather than failing silently.
        setError(
          'Account created. Confirm your email address, sign in, then open this link again to join.',
        );
        setBusy(false);
        return;
      }

      await accept();
    } catch (cause) {
      setError(cause instanceof Error ? cause.message : 'That invitation could not be accepted.');
      setBusy(false);
    }
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-canvas px-6 py-12">
      <div className="w-full max-w-sm">
        <div className="mb-7 flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-field bg-accent font-display text-lg font-extrabold text-on-accent">
            W
          </div>
          <span className="font-display text-xl font-extrabold tracking-tight">Warq</span>
        </div>

        <h1 className="font-display text-[26px] font-bold text-balance">You have been invited</h1>
        <p className="mt-2 text-[14px] leading-relaxed text-ink-muted">
          Accepting adds you to the organization that invited you, as a teacher.
        </p>

        {session ? (
          <Card className="mt-6">
            <p className="text-[13px] leading-relaxed text-ink-base">
              Signed in as <strong>{session.profile.email}</strong>. The invitation must have been
              sent to this address.
            </p>

            {error && <ErrorNote>{error}</ErrorNote>}

            <Button
              onClick={() => void handleAcceptOnly()}
              disabled={busy}
              className="mt-3.5 w-full py-3"
            >
              {busy ? 'Joining…' : 'Accept invitation'}
            </Button>
          </Card>
        ) : (
          <form
            onSubmit={(event) => void handleSignUp(event)}
            className="mt-6 flex flex-col gap-3.5"
            noValidate
          >
            <Field
              label="Full name"
              required
              autoComplete="name"
              value={fullName}
              onChange={(event) => setFullName(event.target.value)}
            />
            <Field
              label="Email"
              type="email"
              required
              autoComplete="email"
              value={email}
              onChange={(event) => setEmail(event.target.value)}
              hint="Use the address the invitation was sent to."
            />
            <Field
              label="Password"
              type="password"
              required
              minLength={8}
              autoComplete="new-password"
              value={password}
              onChange={(event) => setPassword(event.target.value)}
              hint="At least 8 characters."
            />

            {error && <ErrorNote>{error}</ErrorNote>}

            <Button type="submit" disabled={busy} className="mt-1 h-12 w-full">
              {busy ? 'Joining…' : 'Create account and join'}
            </Button>
          </form>
        )}

        <p className="mt-5 text-center text-[12.5px] font-bold">
          <Link to="/login" className="text-accent hover:underline">
            Already have an account? Sign in
          </Link>
        </p>
      </div>
    </main>
  );
}

function ErrorNote({ children }: { children: React.ReactNode }) {
  return (
    <p
      role="alert"
      className="mt-3 rounded-control bg-[#DC26260F] px-3.5 py-2.5 text-[13px] font-semibold text-expired"
    >
      {children}
    </p>
  );
}
