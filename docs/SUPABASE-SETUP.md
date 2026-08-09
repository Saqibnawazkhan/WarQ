# Supabase — one-time setup

Warq keeps everything in one Supabase project: Postgres with row-level security,
authentication, realtime and file storage. This is how to provision it.

Roughly five minutes. The region is the only choice that cannot be undone.

---

## 1. Create the project

1. **[supabase.com](https://supabase.com)** → **Start your project** → **Continue with GitHub**.
   Use the account that owns `Saqibnawazkhan/WarQ`.
2. Create an organization if prompted — name `Warq`, type **Personal**, plan **Free**.
3. **New project**, then:

| Field                 | Value                                             | Notes                                                                                                                 |
| --------------------- | ------------------------------------------------- | --------------------------------------------------------------------------------------------------------------------- |
| **Name**              | `warq`                                            |                                                                                                                       |
| **Database password** | Generate one, then store it in a password manager | Shown once. Needed for migrations and direct connections. Recoverable only by resetting it under Settings → Database. |
| **Region**            | **South Asia (Mumbai) · `ap-south-1`**            | Closest to Pakistan. **Permanent** — changing it later means a new project and a data migration.                      |
| **Plan**              | Free                                              | 500 MB database, 1 GB storage, 50k monthly active users. More than enough through M10.                                |

Provisioning takes a minute or two.

---

## 2. Collect the credentials

**Project Settings** (gear, bottom left) → **API Keys**.

Supabase currently shows two generations of key. **Warq uses the newer pair.**

| Generation                         | Keys                                      | Status                                                        |
| ---------------------------------- | ----------------------------------------- | ------------------------------------------------------------- |
| **Current — use these**            | `sb_publishable_…` and `sb_secret_…`      | Rotatable individually, revocable, no session disruption      |
| Legacy — under **Legacy API keys** | `anon` / `public` and `service_role` JWTs | Deprecated. Rotating them means rotating the whole JWT secret |

| Value               | Goes in                                                                                             | Sensitivity                                                         |
| ------------------- | --------------------------------------------------------------------------------------------------- | ------------------------------------------------------------------- |
| **Project URL**     | `SUPABASE_URL`, `VITE_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_URL`                                     | Public                                                              |
| **Publishable key** | `SUPABASE_PUBLISHABLE_KEY`, `VITE_SUPABASE_PUBLISHABLE_KEY`, `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` | Public by design — it ships inside the web bundle and the phone app |
| **Secret key**      | `SUPABASE_SECRET_KEY` — **worker only**                                                             | **Secret.** Bypasses row-level security entirely                    |

### On the publishable key being public

It is not a password, and Supabase's own dashboard says it can be shared
publicly. Every request it makes is still filtered by row-level security, so it
can only reach rows the signed-in user is allowed to reach. Shipping it in a
client is the intended design — which is exactly why the policies in
[`RBAC.md`](RBAC.md) have to be right.

### On the secret key

It bypasses row-level security completely. Anyone holding it can read every
student record in every organization on the platform.

It belongs in exactly two places: your local `.env`, and the Railway worker's
environment variables. Never in the web app, never in the mobile app, never in a
commit, never pasted into a chat or an issue.

### Disabling the legacy keys

There is a **Disable JWT-based API keys** button on that page. It is the right
end state, but leave it until M1 is running against the new keys — turning it off
first only makes a failure harder to diagnose. Once the app works, disable them.

---

## 3. Wire it up locally

```bash
cp .env.example .env
```

Fill in the values. `.env` is gitignored, so it cannot reach GitHub.

---

## 4. Connect the CLI

The CLI is a project dependency — no global install. Two commands, run once:

```bash
npx supabase login          # opens a browser; approve, then close the tab
npm run db:link             # asks for the database password from step 1
```

`db:link` is pinned to this project's ref. The **project ref** is the subdomain
of the project URL: for `https://abcdefgh.supabase.co`, it is `abcdefgh`.

Afterwards:

| Command               | Does                                                        |
| --------------------- | ----------------------------------------------------------- |
| `npm run db:push:dry` | Shows which migrations _would_ apply. Always safe.          |
| `npm run db:push`     | Applies pending migrations to the linked project.           |
| `npm run db:seed`     | Applies migrations **and** loads the mockup fixtures.       |
| `npm run db:diff`     | Shows drift between local migrations and the remote schema. |
| `npm run db:types`    | Regenerates the TypeScript types from the live schema.      |

> **`db:DANGER:reset` drops every table and rebuilds from scratch.** It is named
> that way so it cannot be run by muscle memory. Only for a development project
> you are willing to lose.

---

## 5. Deployment environments

The same three values go into each host, with the secret key confined to the
worker.

| Host        | Variables                                                          |
| ----------- | ------------------------------------------------------------------ |
| **Vercel**  | `VITE_SUPABASE_URL`, `VITE_SUPABASE_PUBLISHABLE_KEY`               |
| **Railway** | `SUPABASE_URL`, `SUPABASE_SECRET_KEY`                              |
| **Expo**    | `EXPO_PUBLIC_SUPABASE_URL`, `EXPO_PUBLIC_SUPABASE_PUBLISHABLE_KEY` |

---

## Free-tier notes

- A project **pauses after 7 days without activity.** One click in the dashboard restores it; no data is lost.
- **Two free projects per organization** — room for a `warq-staging` alongside production later, at no cost.
- Backups are limited on the free plan. Before the first real institution's data lands, move to Pro or set up scheduled `pg_dump` exports.
