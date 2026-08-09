/**
 * Teacher data access.
 *
 * Reads are ordinary queries scoped by row-level security to the caller's own
 * classes. Writes go through database functions, because each one is a single
 * decision — a register is taken or it is not — and splitting it across two
 * requests would let a dropped connection leave half of it saved.
 */

import type { AttendanceMark, CalendarDate } from '@warq/core';

import type { WarqClient } from './client.js';
import type { Row, ViewRow } from './types.js';

export type TeacherToday = ViewRow<'v_teacher_today'>;
export type TeacherClass = ViewRow<'v_org_classes'>;
export type Student = Row<'students'>;
export type StudentContact = Row<'student_contacts'>;
export type Assessment = Row<'assessments'>;
export type Mark = Row<'marks'>;
export type AttendanceSession = Row<'attendance_sessions'>;
export type AttendanceRecord = Row<'attendance_records'>;

function unwrap<T>(data: T | null, error: { message: string } | null, what: string): T {
  if (error) throw new Error(`Could not load ${what}: ${error.message}`);
  if (data === null) throw new Error(`Could not load ${what}.`);
  return data;
}

// ── Reading ─────────────────────────────────────────────────

export async function listToday(client: WarqClient): Promise<TeacherToday[]> {
  const { data, error } = await client
    .from('v_teacher_today')
    .select('*')
    .order('name', { ascending: true });

  return unwrap(data, error, "today's classes");
}

export async function listMyClasses(client: WarqClient): Promise<TeacherClass[]> {
  const { data, error } = await client
    .from('v_org_classes')
    .select('*')
    .order('name', { ascending: true });

  return unwrap(data, error, 'your classes');
}

export async function listRoster(client: WarqClient, classId: string): Promise<Student[]> {
  const { data, error } = await client
    .from('students')
    .select('*')
    .eq('class_id', classId)
    .order('full_name', { ascending: true });

  return unwrap(data, error, 'the roster');
}

export async function listAssessments(client: WarqClient, classId: string): Promise<Assessment[]> {
  const { data, error } = await client
    .from('assessments')
    .select('*')
    .eq('class_id', classId)
    .order('date', { ascending: true });

  return unwrap(data, error, 'assessments');
}

export async function listMarks(client: WarqClient, assessmentId: string): Promise<Mark[]> {
  const { data, error } = await client.from('marks').select('*').eq('assessment_id', assessmentId);
  return unwrap(data, error, 'marks');
}

/** The register for one class on one day, or null if it has not been taken. */
export async function getAttendance(
  client: WarqClient,
  classId: string,
  date: CalendarDate,
): Promise<{ session: AttendanceSession | null; records: AttendanceRecord[] }> {
  const { data: session, error } = await client
    .from('attendance_sessions')
    .select('*')
    .eq('class_id', classId)
    .eq('date', date)
    .maybeSingle();

  if (error) throw new Error(`Could not load the register: ${error.message}`);
  if (!session) return { session: null, records: [] };

  const { data: records } = await client
    .from('attendance_records')
    .select('*')
    .eq('session_id', session.id);

  return { session, records: records ?? [] };
}

export async function listAttendanceHistory(client: WarqClient, classId: string) {
  const { data, error } = await client
    .from('attendance_sessions')
    .select('*, attendance_records(mark)')
    .eq('class_id', classId)
    .order('date', { ascending: false })
    .limit(60);

  return unwrap(data, error, 'the attendance history');
}

export async function listStudentContacts(
  client: WarqClient,
  studentId: string,
): Promise<StudentContact[]> {
  const { data, error } = await client
    .from('student_contacts')
    .select('*')
    .eq('student_id', studentId);

  return unwrap(data, error, 'contacts');
}

// ── Writing ─────────────────────────────────────────────────

export async function createClass(
  client: WarqClient,
  input: { name: string; section: string; session: string },
) {
  const { data, error } = await client.rpc('create_class', {
    class_name: input.name,
    class_section: input.section,
    class_session: input.session,
  });

  if (error) throw new Error(error.message);
  return data;
}

export async function addStudent(
  client: WarqClient,
  input: {
    classId: string;
    fullName: string;
    rollNo: string;
    contacts?: { label: 'father' | 'mother' | 'guardian' | 'student'; phone: string }[];
  },
): Promise<Student> {
  const { data, error } = await client
    .from('students')
    .insert({ class_id: input.classId, full_name: input.fullName, roll_no: input.rollNo })
    .select()
    .single();

  if (error) {
    throw new Error(
      /students_roll_unique/.test(error.message)
        ? `Roll number ${input.rollNo} is already used in this class.`
        : error.message,
    );
  }

  if (input.contacts?.length) {
    const { error: contactError } = await client.from('student_contacts').insert(
      input.contacts.map((contact) => ({
        student_id: data.id,
        label: contact.label,
        phone: contact.phone,
      })),
    );

    // The student exists either way; a bad phone number should not undo that.
    if (contactError) {
      throw new Error(
        `${input.fullName} was added, but the contact was not saved: ${contactError.message}`,
      );
    }
  }

  return data;
}

export async function createAssessment(
  client: WarqClient,
  input: {
    classId: string;
    name: string;
    type: 'quiz' | 'assignment' | 'midterm' | 'final' | 'project' | 'lab';
    date: CalendarDate;
    totalMarks: number;
  },
): Promise<Assessment> {
  const { data, error } = await client
    .from('assessments')
    .insert({
      class_id: input.classId,
      name: input.name,
      type: input.type,
      date: input.date,
      total_marks: input.totalMarks,
    })
    .select()
    .single();

  if (error) {
    throw new Error(
      /assessments_unique_name/.test(error.message)
        ? `This class already has an assessment called "${input.name}".`
        : error.message,
    );
  }

  return data;
}

export interface SaveAttendanceResult {
  readonly sessionId: string;
  readonly absent: number;
  /** Absentees whose guardians have opted into alerts. */
  readonly alertable: number;
}

export async function saveAttendance(
  client: WarqClient,
  input: {
    classId: string;
    date: CalendarDate;
    entries: { studentId: string; mark: AttendanceMark }[];
  },
): Promise<SaveAttendanceResult> {
  const { data, error } = await client.rpc('save_attendance', {
    p_class_id: input.classId,
    p_date: input.date,
    p_entries: input.entries.map((entry) => ({
      student_id: entry.studentId,
      mark: entry.mark,
    })),
  });

  if (error) throw new Error(error.message);

  const result = data as { session_id: string; absent: number; alertable: number };

  return {
    sessionId: result.session_id,
    absent: result.absent,
    alertable: result.alertable,
  };
}

export async function saveMarks(
  client: WarqClient,
  input: { assessmentId: string; entries: { studentId: string; score: number | null }[] },
): Promise<{ marked: number }> {
  const { data, error } = await client.rpc('save_marks', {
    p_assessment_id: input.assessmentId,
    p_entries: input.entries.map((entry) => ({
      student_id: entry.studentId,
      score: entry.score,
    })),
  });

  if (error) throw new Error(error.message);

  return data as { marked: number };
}
