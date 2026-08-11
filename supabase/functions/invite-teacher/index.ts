// Warq · invite-teacher
//
// Creates an account for an invited teacher and emails them the password.
//
// This cannot be a database function. Creating an auth user needs the
// service-role key, and that key bypasses row-level security entirely — it can
// never go anywhere a browser or a phone could read it. So it lives here, as a
// secret on the edge function, and the function is the only thing that holds
// it.
//
// The caller is still an ordinary signed-in organization admin. Their own token
// is used for the permission-checked half of the work, so this function grants
// nobody anything the database would not have granted them anyway:
//
//   1. invite_teacher() runs AS THE CALLER. It refuses anyone who is not an
//      org admin, refuses an organization whose subscription has lapsed, and
//      refuses an address already in the organization. If it raises, nothing
//      else here happens.
//   2. Only then does the service-role client create the account.
//
// Doing it in that order means the privileged step is never reached without the
// unprivileged one having already said yes.

import { createClient } from 'jsr:@supabase/supabase-js@2'

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
}

function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  })
}

/// A password a person has to type once, from a phone, possibly out loud to
/// somebody. No look-alike characters, no symbols that move around on a mobile
/// keyboard, and long enough that the alphabet being small does not matter.
function temporaryPassword(): string {
  const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZabcdefghijkmnopqrstuvwxyz23456789'
  const bytes = new Uint8Array(14)
  crypto.getRandomValues(bytes)
  return Array.from(bytes, (b) => alphabet[b % alphabet.length]).join('')
}

function escapeHtml(value: string): string {
  return value
    .replace(/&/g, '&amp;')
    .replace(/</g, '&lt;')
    .replace(/>/g, '&gt;')
    .replace(/"/g, '&quot;')
}

function emailBody(
  teacherName: string,
  organizationName: string,
  email: string,
  password: string,
): string {
  const name = escapeHtml(teacherName)
  const org = escapeHtml(organizationName)
  return `<!doctype html>
<html>
  <body style="margin:0;padding:24px;background:#f7f7fb;font-family:ui-sans-serif,system-ui,-apple-system,'Segoe UI',Roboto,sans-serif;color:#14142b">
    <div style="max-width:520px;margin:0 auto;background:#fff;border:1px solid #e8e8f0;border-radius:16px;padding:32px">
      <div style="font-size:20px;font-weight:700;letter-spacing:-0.02em;margin-bottom:20px">WarQ</div>

      <p style="font-size:16px;margin:0 0 16px">Hello ${name},</p>

      <p style="margin:0 0 20px;line-height:1.6">
        <strong>${org}</strong> has added you to WarQ, where you will take
        attendance, record marks and produce reports for your classes.
      </p>

      <div style="background:#f7f7fb;border:1px solid #e8e8f0;border-radius:12px;padding:18px;margin-bottom:20px">
        <div style="font-size:12px;text-transform:uppercase;letter-spacing:0.06em;color:#7a7a95;margin-bottom:10px">Sign in with</div>
        <div style="margin-bottom:8px"><strong>Email</strong><br>${escapeHtml(email)}</div>
        <div><strong>Temporary password</strong><br>
          <code style="font-family:ui-monospace,monospace;font-size:17px;letter-spacing:0.06em">${password}</code>
        </div>
      </div>

      <p style="margin:0 0 20px;line-height:1.6">
        WarQ will ask you to choose your own password the first time you sign
        in. Until you do, the one above is the only thing that works — so please
        sign in soon, and delete this email once you have.
      </p>

      <p style="margin:0;color:#7a7a95;font-size:13px;line-height:1.6">
        If you were not expecting this, you can ignore it. Nobody can see your
        classes until you sign in and set a password of your own.
      </p>
    </div>
  </body>
</html>`
}

Deno.serve(async (request: Request) => {
  if (request.method === 'OPTIONS') return new Response('ok', { headers: CORS })
  if (request.method !== 'POST') return json({ error: 'Use POST.' }, 405)

  const url = Deno.env.get('SUPABASE_URL')
  const anonKey = Deno.env.get('SUPABASE_ANON_KEY')
  const serviceKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')
  const resendKey = Deno.env.get('RESEND_API_KEY')
  const from = Deno.env.get('INVITE_FROM_EMAIL') ?? 'WarQ <onboarding@resend.dev>'

  if (!url || !anonKey || !serviceKey) {
    return json({ error: 'The invite function is not configured.' }, 500)
  }

  const authorization = request.headers.get('Authorization')
  if (!authorization) return json({ error: 'Please sign in again.' }, 401)

  let email: string
  let fullName: string
  try {
    const body = await request.json()
    email = String(body.email ?? '').trim().toLowerCase()
    fullName = String(body.full_name ?? '').trim()
  } catch {
    return json({ error: 'Malformed request.' }, 400)
  }

  if (email === '') return json({ error: 'An email address is required.' }, 400)
  if (fullName === '') fullName = email

  // Step one, as the caller. Every rule about who may invite whom lives in the
  // database and is enforced here, before anything privileged happens.
  const asCaller = createClient(url, anonKey, {
    global: { headers: { Authorization: authorization } },
  })

  const { data: invitation, error: inviteError } = await asCaller.rpc('invite_teacher', {
    teacher_email: email,
    teacher_name: fullName,
  })

  if (inviteError) {
    // P0001 is a message written for a person to read ("Ali is already in your
    // organization."), so it is passed through rather than replaced.
    const status = inviteError.code === 'P0001' ? 400 : 403
    return json({ error: inviteError.message }, status)
  }

  const { data: me } = await asCaller.rpc('me')
  const organizationName = me?.organization?.name ?? 'Your organization'

  // Step two, privileged. The account is created already confirmed: the address
  // was chosen by their own administrator, not typed by a stranger, so making
  // them prove they can read their mail proves nothing — and the password is in
  // that mailbox regardless.
  const admin = createClient(url, serviceKey, {
    auth: { autoRefreshToken: false, persistSession: false },
  })

  const password = temporaryPassword()
  const { data: created, error: createError } = await admin.auth.admin.createUser({
    email,
    password,
    email_confirm: true,
    user_metadata: { full_name: fullName, signup_kind: 'invited_teacher' },
  })

  if (createError || !created.user) {
    // The invitation row is left in place: it is what lets the teacher join by
    // registering themselves, which is the fallback when this fails.
    return json(
      {
        error:
          createError?.message?.includes('already')
            ? 'That address already has a WarQ account. Ask them to sign in with it, or invite a different address.'
            : 'The invitation was recorded but the account could not be created.',
      },
      400,
    )
  }

  // fn_handle_new_user has already run on the row above: it found the pending
  // invitation, put the teacher in the organization and marked the invitation
  // accepted. All that is left is the flag that forces the password change.
  await admin
    .from('profiles')
    .update({ must_change_password: true })
    .eq('id', created.user.id)

  if (!resendKey) {
    // The account exists and works; only the delivery is missing. Say exactly
    // that, and hand the password back so the admin can pass it on rather than
    // being left with an account nobody can get into.
    return json({
      ok: true,
      emailed: false,
      password,
      invitation_id: invitation?.id ?? null,
      message:
        'Account created, but no email service is configured — give them this password yourself.',
    })
  }

  const sent = await fetch('https://api.resend.com/emails', {
    method: 'POST',
    headers: {
      Authorization: `Bearer ${resendKey}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      from,
      to: [email],
      subject: `${organizationName} has added you to WarQ`,
      html: emailBody(fullName, organizationName, email, password),
    }),
  })

  if (!sent.ok) {
    const detail = await sent.text()
    return json({
      ok: true,
      emailed: false,
      password,
      invitation_id: invitation?.id ?? null,
      message:
        'Account created, but the email could not be sent — give them this password yourself.',
      detail,
    })
  }

  // The password is deliberately NOT returned once it has been emailed: it
  // belongs to the teacher's mailbox, and echoing it into the admin's browser
  // would put a second copy somewhere it was never needed.
  return json({
    ok: true,
    emailed: true,
    invitation_id: invitation?.id ?? null,
    message: `Invitation sent to ${email}.`,
  })
})
