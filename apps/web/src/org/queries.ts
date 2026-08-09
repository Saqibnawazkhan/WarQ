import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import {
  getClassDetail,
  getOrgOverview,
  inviteTeacher,
  listDailyAttendance,
  listInvitations,
  listOrgActivity,
  listOrgClasses,
  listOrgStudents,
  listOrgTeachers,
  removeTeacher,
  revokeInvitation,
  type ActivityFilter,
} from '@warq/data';

import { supabase } from '../lib/supabase.ts';

export const orgKeys = {
  all: ['org'] as const,
  overview: () => [...orgKeys.all, 'overview'] as const,
  teachers: () => [...orgKeys.all, 'teachers'] as const,
  classes: () => [...orgKeys.all, 'classes'] as const,
  classDetail: (id: string) => [...orgKeys.all, 'class', id] as const,
  students: () => [...orgKeys.all, 'students'] as const,
  attendance: () => [...orgKeys.all, 'attendance'] as const,
  invitations: () => [...orgKeys.all, 'invitations'] as const,
  activity: (filter: ActivityFilter) => [...orgKeys.all, 'activity', filter] as const,
};

export function useOrgOverview() {
  return useQuery({ queryKey: orgKeys.overview(), queryFn: () => getOrgOverview(supabase) });
}

export function useOrgTeachers() {
  return useQuery({ queryKey: orgKeys.teachers(), queryFn: () => listOrgTeachers(supabase) });
}

export function useOrgClasses() {
  return useQuery({ queryKey: orgKeys.classes(), queryFn: () => listOrgClasses(supabase) });
}

export function useOrgStudents() {
  return useQuery({ queryKey: orgKeys.students(), queryFn: () => listOrgStudents(supabase) });
}

export function useDailyAttendance() {
  return useQuery({ queryKey: orgKeys.attendance(), queryFn: () => listDailyAttendance(supabase) });
}

export function useInvitations() {
  return useQuery({ queryKey: orgKeys.invitations(), queryFn: () => listInvitations(supabase) });
}

export function useOrgActivity(filter: ActivityFilter) {
  return useQuery({
    queryKey: orgKeys.activity(filter),
    queryFn: () => listOrgActivity(supabase, { type: filter, limit: 150 }),
  });
}

export function useClassDetail(classId: string | undefined) {
  return useQuery({
    queryKey: orgKeys.classDetail(classId ?? 'none'),
    queryFn: () => getClassDetail(supabase, classId ?? ''),
    enabled: Boolean(classId),
  });
}

export function useInviteTeacher() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: { email: string; fullName: string; sendVia: 'email' | 'whatsapp' }) =>
      inviteTeacher(supabase, input, window.location.origin),
    onSettled: () => client.invalidateQueries({ queryKey: orgKeys.all }),
  });
}

export function useRevokeInvitation() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (invitationId: string) => revokeInvitation(supabase, invitationId),
    onSettled: () => client.invalidateQueries({ queryKey: orgKeys.invitations() }),
  });
}

export function useRemoveTeacher() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (teacherId: string) => removeTeacher(supabase, teacherId),
    // Removing a teacher changes the teacher list, the counts and the activity
    // feed, so the whole organization scope is refetched rather than guessed at.
    onSettled: () => client.invalidateQueries({ queryKey: orgKeys.all }),
  });
}
