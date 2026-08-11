# Edge functions

## `invite-teacher`

Creates an account for an invited teacher and emails them a temporary password.

### Why it exists

Creating an auth user requires the **service-role key**, which bypasses row-level
security completely. That key can never reach a browser or a phone, so this work
cannot live in the app or in a database function called from one. It lives here,
where the key is a secret held by the function.

The function is not a way round the rules. It does the permission-checked half
of the work **as the caller**, using their own token:

1. `invite_teacher()` runs as the signed-in organization admin. It refuses
   anyone who is not one, refuses an organization whose subscription has lapsed,
   and refuses an address already on the staff. If that raises, nothing else
   happens.
2. Only then does the service-role client create the account.

The privileged step is unreachable without the unprivileged one having agreed.

### About the password

Emailing a password puts it somewhere nobody can take it back from: mail is not
encrypted at rest, it stays in the mailbox for years, and whoever reads that
mailbox later can sign in. That exposure cannot be removed, so it is bounded —
`profiles.must_change_password` is set, and the apps send the teacher to the
change-password screen and nowhere else until they have chosen their own.

The password is returned to the caller **only** when the email could not be
sent. Once it has been delivered it belongs in the teacher's mailbox and
nowhere else.

## Setting it up

Three things, once.

### 1. An email service

Supabase's built-in mailer is rate-limited to a handful of messages an hour and
is explicitly not for production — a school inviting its staff would hit the
limit on the first morning.

[Resend](https://resend.com) is the default here: free for 3,000 messages a
month, and it will send from `onboarding@resend.dev` immediately, with no DNS to
configure, so you can test before you own a domain.

Create an account, make an API key, and keep it to hand.

### 2. Deploy the function

```
npm install -g supabase
supabase login
supabase link --project-ref befjsognpcqxuhqfmlpe
supabase functions deploy invite-teacher
```

### 3. Give it the secrets

```
supabase secrets set RESEND_API_KEY=re_your_key_here
```

`SUPABASE_URL`, `SUPABASE_ANON_KEY` and `SUPABASE_SERVICE_ROLE_KEY` are provided
to every function automatically — do not set them yourself, and never put the
service-role key in this repository.

Once you own a domain and have verified it with Resend, point the sender at it
so the mail comes from you rather than from Resend's shared address:

```
supabase secrets set INVITE_FROM_EMAIL="WarQ <invites@yourdomain.com>"
```

## Without the key

The function still works: it creates the account and returns the password to the
administrator with a message saying the email could not be sent, so they can
pass it on themselves. Nobody is left with an account they cannot get into.
