import { useState, type FormEvent } from 'react';
import { Link } from 'react-router-dom';

import { planLabel, SUBSCRIPTION_PLANS, type SubscriptionPlan } from '@warq/core';

import { supabase } from '../lib/supabase.ts';
import { cx } from '../lib/cx.ts';
import { Button, Chip, Field } from '../ui/index.ts';

type AccountKind = 'organization' | 'individual_teacher';

const KINDS: readonly { value: AccountKind; label: string; blurb: string }[] = [
  {
    value: 'organization',
    label: 'Organization',
    blurb: 'A school, college or academy with several teachers.',
  },
  {
    value: 'individual_teacher',
    label: 'Individual teacher',
    blurb: 'You teach your own classes and manage them yourself.',
  },
];

export function SignUpPage() {
  const [kind, setKind] = useState<AccountKind>('organization');
  const [plan, setPlan] = useState<SubscriptionPlan>('monthly');
  const [form, setForm] = useState({
    fullName: '',
    organizationName: '',
    city: '',
    email: '',
    phone: '',
    password: '',
  });
  const [error, setError] = useState<string | null>(null);
  const [submitting, setSubmitting] = useState(false);
  const [done, setDone] = useState(false);

  function set(field: keyof typeof form) {
    return (event: { target: { value: string } }) =>
      setForm((current) => ({ ...current, [field]: event.target.value }));
  }

  async function handleSubmit(event: FormEvent) {
    event.preventDefault();
    setError(null);
    setSubmitting(true);

    const { error: signUpError } = await supabase.auth.signUp({
      email: form.email.trim().toLowerCase(),
      password: form.password,
      options: {
        // The database trigger reads this and creates the profile, the
        // organization and the pending subscription in one transaction.
        data: {
          signup_kind: kind,
          full_name: form.fullName.trim(),
          phone: form.phone.trim(),
          plan,
          ...(kind === 'organization'
            ? {
                organization_name: form.organizationName.trim(),
                city: form.city.trim(),
              }
            : {}),
        },
      },
    });

    if (signUpError) {
      setError(
        /already registered/i.test(signUpError.message)
          ? 'An account already exists for that email address. Sign in instead.'
          : signUpError.message,
      );
      setSubmitting(false);
      return;
    }

    setDone(true);
  }

  if (done) {
    return (
      <main className="flex min-h-screen items-center justify-center bg-canvas px-6 py-12">
        <div className="w-full max-w-md text-center">
          <div className="mx-auto flex size-12 items-center justify-center rounded-tile bg-[#16A34A1A] font-display text-xl font-bold text-active">
            ✓
          </div>
          <h1 className="mt-5 font-display text-2xl font-bold">Request received</h1>
          <p className="mt-3 leading-relaxed text-ink-base">
            {kind === 'organization'
              ? `${form.organizationName.trim()} has been submitted for approval.`
              : 'Your teacher account has been submitted for approval.'}{' '}
            Warq reviews new accounts before activating them — you will get an email when it is
            approved.
          </p>
          <p className="mt-3 text-[13px] text-ink-muted">
            If your email needs confirming, check your inbox first.
          </p>
          <Link
            to="/login"
            className="mt-6 inline-flex rounded-control bg-accent px-4 py-2.5 text-[13px] font-bold text-on-accent"
          >
            Back to sign in
          </Link>
        </div>
      </main>
    );
  }

  return (
    <main className="flex min-h-screen items-center justify-center bg-canvas px-6 py-12">
      <div className="w-full max-w-md">
        <div className="mb-7 flex items-center gap-3">
          <div className="flex size-10 items-center justify-center rounded-field bg-accent font-display text-lg font-extrabold text-on-accent">
            W
          </div>
          <span className="font-display text-xl font-extrabold tracking-tight">Warq</span>
        </div>

        <h1 className="font-display text-[26px] font-bold text-balance">Create an account</h1>
        <p className="mt-2 text-[14px] text-ink-muted">
          Teachers joining an existing organization should use their invitation link instead.
        </p>

        <fieldset className="mt-6">
          <legend className="mb-2 text-[12.5px] font-bold text-ink-base">Account type</legend>
          <div className="grid grid-cols-2 gap-2">
            {KINDS.map((option) => (
              <button
                key={option.value}
                type="button"
                aria-pressed={kind === option.value}
                onClick={() => setKind(option.value)}
                className={cx(
                  'rounded-tile border p-3 text-left transition-colors',
                  kind === option.value
                    ? 'border-accent bg-raised'
                    : 'border-line bg-raised hover:border-line-hover',
                )}
              >
                <span className="block text-[13.5px] font-bold">{option.label}</span>
                <span className="mt-1 block text-[11.5px] leading-snug text-ink-muted">
                  {option.blurb}
                </span>
              </button>
            ))}
          </div>
        </fieldset>

        <form
          onSubmit={(event) => void handleSubmit(event)}
          className="mt-5 flex flex-col gap-3.5"
          noValidate
        >
          {kind === 'organization' && (
            <>
              <Field
                label="Organization name"
                required
                value={form.organizationName}
                onChange={set('organizationName')}
                placeholder="Punjab College of IT"
              />
              <Field
                label="City"
                required
                value={form.city}
                onChange={set('city')}
                placeholder="Lahore"
              />
            </>
          )}

          <Field
            label={kind === 'organization' ? 'Your name' : 'Full name'}
            required
            autoComplete="name"
            value={form.fullName}
            onChange={set('fullName')}
          />

          <Field
            label="Email"
            type="email"
            required
            autoComplete="email"
            value={form.email}
            onChange={set('email')}
          />

          <Field
            label="Phone"
            type="tel"
            autoComplete="tel"
            value={form.phone}
            onChange={set('phone')}
            placeholder="0300 1234567"
          />

          <Field
            label="Password"
            type="password"
            required
            minLength={8}
            autoComplete="new-password"
            value={form.password}
            onChange={set('password')}
            hint="At least 8 characters."
          />

          <fieldset>
            <legend className="mb-2 text-[12.5px] font-bold text-ink-base">Plan</legend>
            <div className="flex flex-wrap gap-2">
              {SUBSCRIPTION_PLANS.map((option) => (
                <Chip
                  key={option}
                  label={planLabel(option)}
                  selected={plan === option}
                  onSelect={() => setPlan(option)}
                />
              ))}
            </div>
            <p className="mt-2 text-[12px] text-ink-muted">
              Nothing is charged now. Warq approves the account before it becomes active.
            </p>
          </fieldset>

          {error && (
            <p
              role="alert"
              className="rounded-control bg-[#DC26260F] px-3.5 py-2.5 text-[13px] font-semibold text-expired"
            >
              {error}
            </p>
          )}

          <Button type="submit" disabled={submitting} className="mt-1 h-12 w-full">
            {submitting ? 'Submitting…' : 'Request an account'}
          </Button>
        </form>

        <p className="mt-5 text-center text-[12.5px] font-bold">
          <Link to="/login" className="text-accent hover:underline">
            Already have an account? Sign in
          </Link>
        </p>
      </div>
    </main>
  );
}
