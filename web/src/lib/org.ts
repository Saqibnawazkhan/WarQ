import { supabase } from './supabase'
import type { Invitation, OrgOverview, OrgTeacher } from './types'

export interface OrgClass {
  id: string
  organization_id: string | null
  teacher_id: string
  teacher_name: string | null
  name: string
  section: string | null
  session: string | null
  student_count: number
  session_count: number
  assessment_count: number
  attendance_percent: number | null
  last_session_date: string | null
}

/// What an organization administrator can see and do.
///
/// The three actions with consequences beyond one row go through database
/// functions, because each carries a rule the client cannot be trusted with:
/// invite_teacher files the invitation against the caller's own organization
/// rather than one named in the request, revoke_invitation and remove_teacher
/// refuse anything outside it, and remove_teacher deliberately leaves every
/// class, register and mark with the organization.
export const org = {
  async overview(organizationId: string): Promise<OrgOverview | null> {
    const { data, error } = await supabase
      .from('v_org_overview')
      .select('*')
      .eq('organization_id', organizationId)
      .maybeSingle()
    if (error) throw error
    return data as OrgOverview | null
  },

  async teachers(): Promise<OrgTeacher[]> {
    const { data, error } = await supabase
      .from('v_org_teachers')
      .select('*')
      .order('full_name')
    if (error) throw error
    return data as OrgTeacher[]
  },

  async classes(): Promise<OrgClass[]> {
    const { data, error } = await supabase.from('v_org_classes').select('*').order('name')
    if (error) throw error
    return data as OrgClass[]
  },

  async invitations(): Promise<Invitation[]> {
    const { data, error } = await supabase
      .from('invitations')
      .select('*')
      .order('created_at', { ascending: false })
    if (error) throw error
    return data as Invitation[]
  },

  async invite(email: string, name: string): Promise<void> {
    const address = email.trim().toLowerCase()
    const { error } = await supabase.rpc('invite_teacher', {
      teacher_email: address,
      teacher_name: name.trim() === '' ? address : name.trim(),
    })
    if (error) throw error
  },

  async revoke(invitationId: string): Promise<void> {
    const { error } = await supabase.rpc('revoke_invitation', { invitation_id: invitationId })
    if (error) throw error
  },

  async removeTeacher(teacherId: string): Promise<void> {
    const { error } = await supabase.rpc('remove_teacher', { teacher_id: teacherId })
    if (error) throw error
  },
}
