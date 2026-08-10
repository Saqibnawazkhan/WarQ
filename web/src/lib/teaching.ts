import { supabase } from './supabase'
import type {
  Assessment,
  AttendanceMark,
  AttendanceRecord,
  AttendanceSession,
  ClassAttendance,
  Mark,
  SchoolClass,
  Student,
  StudentPerformance,
  TeacherToday,
} from './types'

/// Everything the teacher screens read and write.
///
/// Kept together rather than spread through the pages so the web app and the
/// mobile app can be checked against each other: each call here has a
/// counterpart in mobile/lib/data/repositories/supabase/, hits the same view or
/// function, and must mean the same thing. Where the mobile app goes through a
/// database function rather than a direct write, so does this.

export const teaching = {
  // ── Classes ───────────────────────────────────────────────

  async classes(teacherId: string): Promise<SchoolClass[]> {
    const { data, error } = await supabase
      .from('classes')
      .select('*')
      .eq('teacher_id', teacherId)
      .is('archived_at', null)
    if (error) throw error

    // "Most recently touched" is not an ordering PostgREST can express, so it
    // is done here, exactly as the mobile app does.
    return (data as SchoolClass[]).sort(
      (a, b) =>
        new Date(b.updated_at ?? b.created_at).getTime() -
        new Date(a.updated_at ?? a.created_at).getTime(),
    )
  },

  async classById(classId: string): Promise<SchoolClass | null> {
    const { data, error } = await supabase
      .from('classes')
      .select('*')
      .eq('id', classId)
      .maybeSingle()
    if (error) throw error
    return data as SchoolClass | null
  },

  async createClass(fields: {
    name: string
    subject?: string
    section?: string
    session?: string
    description?: string
  }): Promise<SchoolClass> {
    // The function takes the organization from the caller's own profile, picks
    // the colour and writes the activity entry. Only the name is required.
    const { data, error } = await supabase.rpc('create_class', {
      class_name: fields.name.trim(),
      class_section: blankToNull(fields.section),
      class_session: blankToNull(fields.session),
      class_subject: blankToNull(fields.subject),
      class_description: blankToNull(fields.description),
    })
    if (error) throw error
    return data as SchoolClass
  },

  async updateClass(
    classId: string,
    fields: {
      name: string
      subject?: string
      section?: string
      session?: string
      description?: string
    },
  ): Promise<void> {
    const { error } = await supabase
      .from('classes')
      .update({
        name: fields.name.trim(),
        subject: blankToNull(fields.subject),
        section: blankToNull(fields.section),
        session: blankToNull(fields.session),
        description: blankToNull(fields.description),
        updated_at: new Date().toISOString(),
      })
      .eq('id', classId)
    if (error) throw error
  },

  async deleteClass(classId: string): Promise<void> {
    // Enrolments, registers and assessments cascade from the foreign key.
    // Students survive: they belong to the teacher, not to the class.
    const { error } = await supabase.from('classes').delete().eq('id', classId)
    if (error) throw error
  },

  async today(): Promise<TeacherToday[]> {
    const { data, error } = await supabase.from('v_teacher_today').select('*')
    if (error) throw error
    return data as TeacherToday[]
  },

  async classStats(): Promise<ClassAttendance[]> {
    const { data, error } = await supabase.from('v_class_attendance').select('*')
    if (error) throw error
    return data as ClassAttendance[]
  },

  // ── Students ──────────────────────────────────────────────

  /// Students currently in the class, A to Z.
  ///
  /// Two steps because PostgREST can filter a parent by its children but not
  /// while also excluding children that have been detached, and somebody who
  /// left the class must not appear on today's register.
  async roster(classId: string): Promise<Student[]> {
    const ids = await activeStudentIds(classId)
    if (ids.length === 0) return []

    const { data, error } = await supabase
      .from('students')
      .select('*, student_contacts(*)')
      .in('id', ids)
    if (error) throw error

    return (data as Student[]).sort((a, b) =>
      a.full_name.localeCompare(b.full_name, undefined, { sensitivity: 'base' }),
    )
  },

  async allStudents(teacherId: string): Promise<Student[]> {
    const { data, error } = await supabase
      .from('students')
      .select('*, student_contacts(*)')
      .eq('teacher_id', teacherId)
    if (error) throw error
    return (data as Student[]).sort((a, b) =>
      a.full_name.localeCompare(b.full_name, undefined, { sensitivity: 'base' }),
    )
  },

  /// Creates the student and, when a class is given, enrols them.
  /// Only the name is required — roll numbers and every phone number optional.
  async createStudent(
    teacherId: string,
    organizationId: string | null,
    fields: StudentFields,
    classId?: string,
  ): Promise<Student> {
    const { data, error } = await supabase
      .from('students')
      .insert({
        teacher_id: teacherId,
        organization_id: organizationId,
        full_name: fields.full_name.trim(),
        ...optionalStudentFields(fields),
      })
      .select('id')
      .single()
    if (error) throw error

    const id = (data as { id: string }).id
    await writeContacts(id, fields)
    if (classId !== undefined) await teaching.enrol(classId, id)

    const created = await teaching.studentById(id)
    if (created === null) throw new Error('The student could not be read back.')
    return created
  },

  async updateStudent(studentId: string, fields: StudentFields): Promise<void> {
    const { error } = await supabase
      .from('students')
      .update({
        full_name: fields.full_name.trim(),
        ...optionalStudentFields(fields),
        updated_at: new Date().toISOString(),
      })
      .eq('id', studentId)
    if (error) throw error
    await writeContacts(studentId, fields)
  },

  async studentById(studentId: string): Promise<Student | null> {
    const { data, error } = await supabase
      .from('students')
      .select('*, student_contacts(*)')
      .eq('id', studentId)
      .maybeSingle()
    if (error) throw error
    return data as Student | null
  },

  async deleteStudent(studentId: string): Promise<void> {
    const { error } = await supabase.from('students').delete().eq('id', studentId)
    if (error) throw error
  },

  async enrol(classId: string, studentId: string): Promise<void> {
    const { data, error } = await supabase
      .from('class_students')
      .select('id, unenrolled_at')
      .eq('class_id', classId)
      .eq('student_id', studentId)
      .maybeSingle()
    if (error) throw error

    const existing = data as { id: string; unenrolled_at: string | null } | null

    // Already in the class: leave the original enrolment date alone rather than
    // claiming they joined again today.
    if (existing !== null && existing.unenrolled_at === null) return

    // A returning student reuses their row, which is what the unique
    // (class_id, student_id) index requires.
    if (existing !== null) {
      const { error: revive } = await supabase
        .from('class_students')
        .update({ unenrolled_at: null, enrolled_at: new Date().toISOString() })
        .eq('id', existing.id)
      if (revive) throw revive
      return
    }

    const { error: insert } = await supabase
      .from('class_students')
      .insert({ class_id: classId, student_id: studentId })
    if (insert) throw insert
  },

  /// Soft detach, so last term's registers and marks stay readable.
  async unenrol(classId: string, studentId: string): Promise<void> {
    const { error } = await supabase
      .from('class_students')
      .update({ unenrolled_at: new Date().toISOString() })
      .eq('class_id', classId)
      .eq('student_id', studentId)
      .is('unenrolled_at', null)
    if (error) throw error
  },

  // ── Attendance ────────────────────────────────────────────

  async sessionOn(classId: string, date: string): Promise<AttendanceSession | null> {
    const { data, error } = await supabase
      .from('attendance_sessions')
      .select('*')
      .eq('class_id', classId)
      .eq('date', date)
      .maybeSingle()
    if (error) throw error
    return data as AttendanceSession | null
  },

  async records(sessionId: string): Promise<AttendanceRecord[]> {
    const { data, error } = await supabase
      .from('attendance_records')
      .select('*')
      .eq('session_id', sessionId)
    if (error) throw error
    return data as AttendanceRecord[]
  },

  /// Saves or corrects a register. Idempotent on (class, date), so saving twice
  /// corrects the record rather than duplicating it.
  async saveAttendance(
    classId: string,
    date: string,
    marks: Record<string, AttendanceMark>,
  ): Promise<{ session_id: string; absent: number; alertable: number }> {
    const { data, error } = await supabase.rpc('save_attendance', {
      p_class_id: classId,
      p_date: date,
      p_entries: Object.entries(marks).map(([student_id, mark]) => ({ student_id, mark })),
    })
    if (error) throw error
    return data as { session_id: string; absent: number; alertable: number }
  },

  async sessions(classId: string): Promise<AttendanceSession[]> {
    const { data, error } = await supabase
      .from('attendance_sessions')
      .select('*')
      .eq('class_id', classId)
      .order('date', { ascending: false })
    if (error) throw error
    return data as AttendanceSession[]
  },

  // ── Assessments and marks ─────────────────────────────────

  async assessments(classId: string): Promise<Assessment[]> {
    const { data, error } = await supabase
      .from('assessments')
      .select('*')
      .eq('class_id', classId)
      .order('date', { ascending: false })
    if (error) throw error
    return data as Assessment[]
  },

  async assessmentById(id: string): Promise<Assessment | null> {
    const { data, error } = await supabase
      .from('assessments')
      .select('*')
      .eq('id', id)
      .maybeSingle()
    if (error) throw error
    return data as Assessment | null
  },

  async createAssessment(fields: {
    class_id: string
    name: string
    type: string
    date: string
    total_marks: number
    // Explicitly `| undefined`: exactOptionalPropertyTypes is on, and callers
    // pass these through from optional form fields.
    custom_type_label?: string | undefined
    description?: string | undefined
  }): Promise<Assessment> {
    const { data, error } = await supabase
      .from('assessments')
      .insert({
        class_id: fields.class_id,
        name: fields.name.trim(),
        type: fields.type,
        date: fields.date,
        total_marks: fields.total_marks,
        custom_type_label: blankToNull(fields.custom_type_label),
        description: blankToNull(fields.description),
      })
      .select('*')
      .single()
    if (error) throw error
    return data as Assessment
  },

  async deleteAssessment(id: string): Promise<void> {
    const { error } = await supabase.from('assessments').delete().eq('id', id)
    if (error) throw error
  },

  async marks(assessmentId: string): Promise<Mark[]> {
    const { data, error } = await supabase
      .from('marks')
      .select('*')
      .eq('assessment_id', assessmentId)
    if (error) throw error
    return data as Mark[]
  },

  /// A cleared box removes the mark rather than storing a zero: not marked yet
  /// and scored nothing are different answers, and only one of them counts
  /// against the student.
  async saveMarks(
    assessmentId: string,
    entries: { student_id: string; score: number | null; absent: boolean; remarks: string | null }[],
  ): Promise<{ marked: number }> {
    const { data, error } = await supabase.rpc('save_marks', {
      p_assessment_id: assessmentId,
      p_entries: entries,
    })
    if (error) throw error
    return data as { marked: number }
  },

  async performance(classId: string): Promise<StudentPerformance[]> {
    const { data, error } = await supabase
      .from('v_student_performance')
      .select('*')
      .eq('class_id', classId)
    if (error) throw error
    return (data as StudentPerformance[]).sort((a, b) =>
      a.full_name.localeCompare(b.full_name, undefined, { sensitivity: 'base' }),
    )
  },
}

export interface StudentFields {
  full_name: string
  roll_no?: string
  email?: string
  address?: string
  guardian_name?: string
  notes?: string
  father_phone?: string
  mother_phone?: string
  student_phone?: string
}

async function activeStudentIds(classId: string): Promise<string[]> {
  const { data, error } = await supabase
    .from('class_students')
    .select('student_id')
    .eq('class_id', classId)
    .is('unenrolled_at', null)
  if (error) throw error
  return (data as { student_id: string }[]).map((row) => row.student_id)
}

function optionalStudentFields(fields: StudentFields) {
  return {
    roll_no: blankToNull(fields.roll_no),
    email: blankToNull(fields.email),
    address: blankToNull(fields.address),
    guardian_name: blankToNull(fields.guardian_name),
    notes: blankToNull(fields.notes),
  }
}

/// Numbers live one row per relation, so a cleared number is a deleted row
/// rather than an empty string. That is what lets "has nobody to call" be
/// answered with a join, which is how absence alerts find their recipients.
async function writeContacts(studentId: string, fields: StudentFields): Promise<void> {
  const numbers: [string, string | null][] = [
    ['father', blankToNull(fields.father_phone)],
    ['mother', blankToNull(fields.mother_phone)],
    ['student', blankToNull(fields.student_phone)],
  ]

  const present = numbers.filter(([, phone]) => phone !== null)
  const cleared = numbers.filter(([, phone]) => phone === null).map(([label]) => label)

  if (present.length > 0) {
    const { error } = await supabase.from('student_contacts').upsert(
      present.map(([label, phone]) => ({ student_id: studentId, label, phone })),
      { onConflict: 'student_id,label' },
    )
    if (error) throw error
  }

  if (cleared.length > 0) {
    const { error } = await supabase
      .from('student_contacts')
      .delete()
      .eq('student_id', studentId)
      .in('label', cleared)
    if (error) throw error
  }
}

/// Blank becomes null rather than an empty string, so "not provided" has one
/// representation and the length checks never see whitespace.
function blankToNull(value: string | undefined): string | null {
  const trimmed = value?.trim() ?? ''
  return trimmed === '' ? null : trimmed
}
