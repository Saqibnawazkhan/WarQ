/**
 * The delivery plan, mirrored from `docs/PLAN.md`.
 * Shown on the home page so the live preview always says where the build is.
 */

export type MilestoneState = 'done' | 'building' | 'planned';

export interface Milestone {
  readonly code: string;
  readonly title: string;
  readonly summary: string;
  readonly lands: string;
  readonly state: MilestoneState;
}

export const MILESTONES: readonly Milestone[] = [
  {
    code: 'M0',
    title: 'Foundation',
    summary:
      'Monorepo, shared tokens and domain logic, linting, tests, continuous integration and deploy wiring.',
    lands: 'Repo',
    state: 'done',
  },
  {
    code: 'M1',
    title: 'Schema, security and authentication',
    summary:
      'Postgres schema with row-level security, seeded from the mockup fixtures, plus sign-up, sign-in and role-based routing.',
    lands: 'Supabase',
    state: 'planned',
  },
  {
    code: 'M2',
    title: 'Main Admin dashboard',
    summary:
      'Organizations, individual teachers, subscriptions, pending requests, expiring subscriptions, notifications, activity and reports.',
    lands: 'Web',
    state: 'planned',
  },
  {
    code: 'M3',
    title: 'Organization Admin dashboard',
    summary:
      'Teachers and invitations, classes, students, attendance and marks review, organization reports and activity.',
    lands: 'Web',
    state: 'planned',
  },
  {
    code: 'M4',
    title: 'Teacher dashboard',
    summary:
      'The teacher surface on a laptop: classes, roster, attendance, marks entry, student performance and reports.',
    lands: 'Web',
    state: 'planned',
  },
  {
    code: 'M5',
    title: 'Mobile — Teacher',
    summary:
      'Attendance with offline capture, marks entry with live grading, class detail, student performance and notifications.',
    lands: 'Mobile',
    state: 'planned',
  },
  {
    code: 'M6',
    title: 'Mobile — Organization Admin',
    summary: 'Organization dashboard, teachers and invitations, classes and the activity feed.',
    lands: 'Mobile',
    state: 'planned',
  },
  {
    code: 'M7',
    title: 'Notifications and lifecycle automation',
    summary:
      'Scheduled subscription transitions, expiry reminders, absence alerts to guardians, and email and WhatsApp delivery.',
    lands: 'Worker',
    state: 'planned',
  },
  {
    code: 'M8',
    title: 'Reports and PDF generation',
    summary: 'Student, class, organization and platform reports, rendered server-side and stored.',
    lands: 'Worker',
    state: 'planned',
  },
  {
    code: 'M9',
    title: 'Realtime cross-platform sync',
    summary: 'Web and mobile stay in step through per-organization realtime channels.',
    lands: 'All',
    state: 'planned',
  },
  {
    code: 'M10',
    title: 'Hardening and release',
    summary:
      'Policy tests, end-to-end coverage, security review, accessibility pass and store builds.',
    lands: 'All',
    state: 'planned',
  },
];
