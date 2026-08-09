import { useMutation, useQuery, useQueryClient } from '@tanstack/react-query';

import type { AttendanceMark, CalendarDate } from '@warq/core';
import {
  addStudent,
  createAssessment,
  createClass,
  getAttendance,
  listAssessments,
  listAttendanceHistory,
  listMarks,
  listMyClasses,
  listRoster,
  listStudentContacts,
  listToday,
  saveAttendance,
  saveMarks,
} from '@warq/data';

import { supabase } from '../lib/supabase.ts';

export const teacherKeys = {
  all: ['teacher'] as const,
  today: () => [...teacherKeys.all, 'today'] as const,
  classes: () => [...teacherKeys.all, 'classes'] as const,
  roster: (classId: string) => [...teacherKeys.all, 'roster', classId] as const,
  assessments: (classId: string) => [...teacherKeys.all, 'assessments', classId] as const,
  marks: (assessmentId: string) => [...teacherKeys.all, 'marks', assessmentId] as const,
  attendance: (classId: string, date: string) =>
    [...teacherKeys.all, 'attendance', classId, date] as const,
  history: (classId: string) => [...teacherKeys.all, 'history', classId] as const,
  contacts: (studentId: string) => [...teacherKeys.all, 'contacts', studentId] as const,
};

export function useToday() {
  return useQuery({ queryKey: teacherKeys.today(), queryFn: () => listToday(supabase) });
}

export function useMyClasses() {
  return useQuery({ queryKey: teacherKeys.classes(), queryFn: () => listMyClasses(supabase) });
}

export function useRoster(classId: string | undefined) {
  return useQuery({
    queryKey: teacherKeys.roster(classId ?? 'none'),
    queryFn: () => listRoster(supabase, classId ?? ''),
    enabled: Boolean(classId),
  });
}

export function useAssessments(classId: string | undefined) {
  return useQuery({
    queryKey: teacherKeys.assessments(classId ?? 'none'),
    queryFn: () => listAssessments(supabase, classId ?? ''),
    enabled: Boolean(classId),
  });
}

export function useMarks(assessmentId: string | undefined) {
  return useQuery({
    queryKey: teacherKeys.marks(assessmentId ?? 'none'),
    queryFn: () => listMarks(supabase, assessmentId ?? ''),
    enabled: Boolean(assessmentId),
  });
}

export function useAttendance(classId: string | undefined, date: CalendarDate) {
  return useQuery({
    queryKey: teacherKeys.attendance(classId ?? 'none', date),
    queryFn: () => getAttendance(supabase, classId ?? '', date),
    enabled: Boolean(classId),
  });
}

export function useAttendanceHistory(classId: string | undefined) {
  return useQuery({
    queryKey: teacherKeys.history(classId ?? 'none'),
    queryFn: () => listAttendanceHistory(supabase, classId ?? ''),
    enabled: Boolean(classId),
  });
}

export function useStudentContacts(studentId: string | undefined) {
  return useQuery({
    queryKey: teacherKeys.contacts(studentId ?? 'none'),
    queryFn: () => listStudentContacts(supabase, studentId ?? ''),
    enabled: Boolean(studentId),
  });
}

export function useCreateClass() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: { name: string; section: string; session: string }) =>
      createClass(supabase, input),
    onSettled: () => client.invalidateQueries({ queryKey: teacherKeys.all }),
  });
}

export function useAddStudent() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      classId: string;
      fullName: string;
      rollNo: string;
      contacts?: { label: 'father' | 'mother' | 'guardian' | 'student'; phone: string }[];
    }) => addStudent(supabase, input),
    onSettled: () => client.invalidateQueries({ queryKey: teacherKeys.all }),
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
    onSettled: () => client.invalidateQueries({ queryKey: teacherKeys.all }),
  });
}

export function useSaveAttendance() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      classId: string;
      date: CalendarDate;
      entries: { studentId: string; mark: AttendanceMark }[];
    }) => saveAttendance(supabase, input),
    // A register changes today's list, the class figures and the activity feed.
    onSettled: () => client.invalidateQueries({ queryKey: teacherKeys.all }),
  });
}

export function useSaveMarks() {
  const client = useQueryClient();

  return useMutation({
    mutationFn: (input: {
      assessmentId: string;
      entries: { studentId: string; score: number | null }[];
    }) => saveMarks(supabase, input),
    onSettled: () => client.invalidateQueries({ queryKey: teacherKeys.all }),
  });
}
