/**
 * Organization Admin data access.
 *
 * Every query here is scoped by row-level security to the caller's own
 * organization — none of them takes an organization id, because a client that
 * could name one could name someone else's.
 */

import type { WarqClient } from './client.js';
import type { Enums, Row, ViewRow } from './types.js';

export type OrgTeacher = ViewRow<'v_org_teachers'>;
export type OrgClass = ViewRow<'v_org_classes'>;
export type OrgDailyAttendance = ViewRow<'v_org_daily_attendance'>;
export type StudentPerformanceRow = ViewRow<'v_student_performance'>;
export type Invitation = Row<'invitations'>;

function unwrap<T>(data: T | null, error: { message: string } | null, what: string): T {
  if (error) throw new Error(`Could not load ${what}: ${error.message}`);
  if (data === null) throw new Error(`Could not load ${what}.`);
  return data;
}

// ── Reading ─────────────────────────────────────────────────

export async function getOrgOverview(client: WarqClient) {
  const { data, error } = await client.from('v_org_overview').select('*').maybeSingle();
  if (error) throw new Error(`Could not load the overview: ${error.message}`);
  return data;
}

export async function listOrgTeachers(client: WarqClient): Promise<OrgTeacher[]> {
  const { data, error } = await client
    .from('v_org_teachers')
    .select('*')
    .order('full_name', { ascending: true });

  return unwrap(data, error, 'teachers');
}

export async function listOrgClasses(client: WarqClient): Promise<OrgClass[]> {
  const { data, error } = await client
    .from('v_org_classes')
    .select('*')
    .order('name', { ascending: true });

  return unwrap(data, error, 'classes');
}

export async function listOrgStudents(client: WarqClient): Promise<StudentPerformanceRow[]> {
  const { data, error } = await client
    .from('v_student_performance')
    .select('*')
    .order('full_name', { ascending: true });

  return unwrap(data, error, 'students');
}

/**
 * Daily attendance, oldest first, for the bar chart.
 *
 * Days with no register are missing from the result rather than zero — a
 * holiday is not a day when nobody turned up, and drawing it as one would
 * quietly slander the whole institution.
 */
export async function listDailyAttendance(client: WarqClient): Promise<OrgDailyAttendance[]> {
  const { data, error } = await client
    .from('v_org_daily_attendance')
    .select('*')
    .order('date', { ascending: true });

  return unwrap(data, error, 'attendance history');
}

export async function listOrgActivity(
  client: WarqClient,
  options: { limit?: number; type?: Enums['activity_type'] | 'all' } = {},
) {
  const base = client
    .from('activity_logs')
    .select('*')
    .order('created_at', { ascending: false })
    .limit(options.limit ?? 100);

  const query = options.type && options.type !== 'all' ? base.eq('type', options.type) : base;

  const { data, error } = await query;
  return unwrap(data, error, 'activity');
}

export async function listInvitations(client: WarqClient): Promise<Invitation[]> {
  const { data, error } = await client
    .from('invitations')
    .select('*')
    .order('created_at', { ascending: false });

  return unwrap(data, error, 'invitations');
}

/** One class, with its roster and assessment coverage. */
export async function getClassDetail(client: WarqClient, classId: string) {
  const [details, students, assessments, sessions] = await Promise.all([
    client.from('v_org_classes').select('*').eq('id', classId).maybeSingle(),
    client
      .from('v_student_performance')
      .select('*')
      .eq('class_id', classId)
      .order('full_name', { ascending: true }),
    client
      .from('assessments')
      .select('*')
      .eq('class_id', classId)
      .order('date', { ascending: false }),
    client
      .from('attendance_sessions')
      .select('*')
      .eq('class_id', classId)
      .order('date', { ascending: false })
      .limit(30),
  ]);

  if (details.error) throw new Error(`Could not load the class: ${details.error.message}`);

  return {
    details: details.data,
    students: students.data ?? [],
    assessments: assessments.data ?? [],
    sessions: sessions.data ?? [],
  };
}

// ── Actions ─────────────────────────────────────────────────

export interface InviteResult {
  readonly invitation: Invitation;
  /** The link to send. Built by the caller, since only it knows the site address. */
  readonly link: string;
}

export async function inviteTeacher(
  client: WarqClient,
  input: { email: string; fullName: string; sendVia: 'email' | 'whatsapp' },
  siteUrl: string,
): Promise<InviteResult> {
  const { data, error } = await client.rpc('invite_teacher', {
    teacher_email: input.email,
    teacher_name: input.fullName,
    send_via: input.sendVia,
  });

  if (error) throw new Error(error.message);
  if (!data) throw new Error('The invitation was not created.');

  return {
    invitation: data,
    link: `${siteUrl.replace(/\/$/, '')}/join/${data.token}`,
  };
}

export async function revokeInvitation(client: WarqClient, invitationId: string): Promise<void> {
  const { error } = await client.rpc('revoke_invitation', { invitation_id: invitationId });
  if (error) throw new Error(error.message);
}

export async function removeTeacher(client: WarqClient, teacherId: string): Promise<void> {
  const { error } = await client.rpc('remove_teacher', { teacher_id: teacherId });
  if (error) throw new Error(error.message);
}
