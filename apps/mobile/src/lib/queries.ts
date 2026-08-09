/**
 * Query hooks, over the same `@warq/data` functions the web app uses.
 *
 * Nothing here knows how to talk to Postgres — that lives once, in the shared
 * package, so a change to how marks are saved cannot apply on one platform and
 * not the other.
 */

import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import type { AttendanceMark, CalendarDate } from '@warq/core';
import {
  createAssessment,
  createClass,
  getAttendance,
  listAssessments,
  listMarks,
  listMyClasses,
  listRoster,
  listStudentContacts,
  listToday,
  saveMarks,
} from '@warq/data';

import { flushQueue, queueOrSaveAttendance, type PendingRegister } from './attendance-queue';
import { supabase } from './supabase';

export const keys = {
  all: ['teacher'] as const,
  today: () => [...keys.all, 'today'] as const,
  classes: () => [...keys.all, 'classes'] as const,
  roster: (classId: string) => [...keys.all, 'roster', classId] as const,
  assessments: (classId: string) => [...keys.all, 'assessments', classId] as const,
  marks: (assessmentId: string) => [...keys.all, 'marks', assessmentId] as const,
  attendance: (classId: string, date: string) =>
    [...keys.all, 'attendance', classId, date] as const,
  contacts: (studentId: string) => [...keys.all, 'contacts', studentId] as const,
  queue: () => [...keys.all, 'queue'] as const,
};

export function useToday() {
  return useQuery({ queryKey: keys.today(), queryFn: () => listToday(supabase) });
}

export function useClasses() {
  return useQuery({ queryKey: keys.classes(), queryFn: () => listMyClasses(supabase) });
}

export function useRoster(classId: string | undefined) {
  return useQuery({
    queryKey: keys.roster(classId ?? 'none'),
    queryFn: () => listRoster(supabase, classId ?? ''),
    enabled: Boolean(classId),
  });
}

export function useAssessments(classId: string | undefined) {
  return useQuery({
    queryKey: keys.assessments(classId ?? 'none'),
    queryFn: () => listAssessments(supabase, classId ?? ''),
    enabled: Boolean(classId),
  });
}

export function useMarks(assessmentId: string | undefined) {
  return useQuery({
    queryKey: keys.marks(assessmentId ?? 'none'),
    queryFn: () => listMarks(supabase, assessmentId ?? ''),
    enabled: Boolean(assessmentId),
  });
}

export function useAttendance(classId: string | undefined, date: CalendarDate) {
  return useQuery({
    queryKey: keys.attendance(classId ?? 'none', date),
    queryFn: () => getAttendance(supabase, classId ?? '', date),
    enabled: Boolean(classId),
  });
}

export function useStudentContacts(studentId: string | undefined) {
  return useQuery({
    queryKey: keys.contacts(studentId ?? 'none'),
    queryFn: () => listStudentContacts(supabase, studentId ?? ''),
    enabled: Boolean(studentId),
  });
}

export function useCreateClass() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: { name: string; section: string; session: string }) =>
      createClass(supabase, input),
    onSettled: () => client.invalidateQueries({ queryKey: keys.all }),
  });
}

export function useCreateAssessment() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      classId: string;
      name: string;
      type: 'quiz' | 'assignment' | 'midterm' | 'final' | 'project' | 'lab';
      date: CalendarDate;
      totalMarks: number;
    }) => createAssessment(supabase, input),
    onSettled: () => client.invalidateQueries({ queryKey: keys.all }),
  });
}

/**
 * Saves a register, falling back to the on-device queue when the network is not
 * there. The caller gets told which happened so the confirmation can be honest.
 */
export function useSaveAttendance() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      classId: string;
      date: CalendarDate;
      entries: { studentId: string; mark: AttendanceMark }[];
    }) => queueOrSaveAttendance(supabase, input),
    onSettled: () => client.invalidateQueries({ queryKey: keys.all }),
  });
}

export function useSaveMarks() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      assessmentId: string;
      entries: { studentId: string; score: number | null }[];
    }) => saveMarks(supabase, input),
    onSettled: () => client.invalidateQueries({ queryKey: keys.all }),
  });
}

/** Registers waiting to reach the server. */
export function usePendingRegisters() {
  return useQuery<PendingRegister[]>({
    queryKey: keys.queue(),
    queryFn: () => flushQueue(supabase),
    // Retried whenever the app is opened or a screen is focused, which is when a
    // teacher is most likely to have signal again.
    refetchOnMount: 'always',
    staleTime: 0,
  });
}
