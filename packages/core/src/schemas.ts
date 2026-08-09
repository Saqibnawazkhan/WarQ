/**
 * Runtime validation.
 *
 * Every boundary — a form submit, an API payload, a row read back from the
 * database — passes through one of these. TypeScript types are erased at
 * runtime; these are not.
 */

import { z } from 'zod';

import { ATTENDANCE_MARKS } from './attendance.js';
import { isCalendarDate } from './calendar.js';
import { GRADES } from './grading.js';
import { PLATFORMS, USER_ROLES } from './roles.js';
import {
  ADMINISTRATIVE_STATUSES,
  SUBSCRIPTION_PLANS,
  SUBSCRIPTION_STATUSES,
} from './subscription.js';

export const calendarDateSchema = z
  .string()
  .refine(isCalendarDate, { message: 'Use a real date in YYYY-MM-DD form.' });

export const userRoleSchema = z.enum(USER_ROLES);
export const platformSchema = z.enum(PLATFORMS);
export const subscriptionPlanSchema = z.enum(SUBSCRIPTION_PLANS);
export const subscriptionStatusSchema = z.enum(SUBSCRIPTION_STATUSES);
export const administrativeStatusSchema = z.enum(ADMINISTRATIVE_STATUSES);
export const attendanceMarkSchema = z.enum(ATTENDANCE_MARKS);
export const gradeSchema = z.enum(GRADES);

const emailSchema = z
  .string()
  .trim()
  .min(1, 'Enter an email address.')
  .pipe(z.email('That email address does not look right.'))
  .transform((value) => value.toLowerCase());

const personNameSchema = z
  .string()
  .trim()
  .min(2, 'Enter a full name.')
  .max(120, 'That name is too long.');

/** Pakistani mobile numbers are written many ways; store the digits, display as typed. */
const phoneSchema = z
  .string()
  .trim()
  .regex(/^[\d\s+()-]{7,20}$/, 'Enter a phone number, digits and spaces only.');

export const signInSchema = z.object({
  email: emailSchema,
  password: z.string().min(8, 'Passwords are at least 8 characters.'),
  platform: platformSchema,
});
export type SignInInput = z.infer<typeof signInSchema>;

export const organizationRequestSchema = z.object({
  organizationName: z.string().trim().min(2, 'Enter the organization name.').max(160),
  city: z.string().trim().min(2, 'Enter a city.').max(80),
  adminName: personNameSchema,
  email: emailSchema,
  phone: phoneSchema,
  plan: subscriptionPlanSchema,
});
export type OrganizationRequestInput = z.infer<typeof organizationRequestSchema>;

export const individualTeacherRequestSchema = z.object({
  fullName: personNameSchema,
  email: emailSchema,
  phone: phoneSchema.optional(),
  plan: subscriptionPlanSchema,
});
export type IndividualTeacherRequestInput = z.infer<typeof individualTeacherRequestSchema>;

export const inviteTeacherSchema = z.object({
  fullName: personNameSchema,
  email: emailSchema,
  sendVia: z.enum(['email', 'whatsapp']),
});
export type InviteTeacherInput = z.infer<typeof inviteTeacherSchema>;

export const classSchema = z.object({
  name: z.string().trim().min(2, 'Name the class.').max(120),
  section: z.string().trim().min(1, 'Enter a section.').max(16),
  session: z.string().trim().min(4, 'Enter the session, for example 2026.').max(32),
});
export type ClassInput = z.infer<typeof classSchema>;

export const studentContactSchema = z.object({
  label: z.enum(['father', 'mother', 'guardian', 'student']),
  phone: phoneSchema,
  receivesAlerts: z.boolean().default(true),
});

export const studentSchema = z.object({
  fullName: personNameSchema,
  rollNo: z.string().trim().min(1, 'Enter a roll number.').max(32),
  contacts: z.array(studentContactSchema).max(4).default([]),
});
export type StudentInput = z.infer<typeof studentSchema>;

export const assessmentSchema = z.object({
  name: z.string().trim().min(1, 'Name the assessment.').max(80),
  type: z.enum(['quiz', 'assignment', 'midterm', 'final', 'project', 'lab']),
  date: calendarDateSchema,
  totalMarks: z.number().int().positive('Total marks must be more than zero.').max(1000),
});
export type AssessmentInput = z.infer<typeof assessmentSchema>;

export const attendanceEntrySchema = z.object({
  studentId: z.uuid(),
  mark: attendanceMarkSchema,
});

export const saveAttendanceSchema = z.object({
  classId: z.uuid(),
  date: calendarDateSchema,
  entries: z.array(attendanceEntrySchema).min(1, 'Mark at least one student.'),
});
export type SaveAttendanceInput = z.infer<typeof saveAttendanceSchema>;

/** A blank box means "not marked yet", which is different from a zero. */
export const markEntrySchema = z.object({
  studentId: z.uuid(),
  score: z.number().min(0, 'Marks cannot be negative.').nullable(),
});

export const saveMarksSchema = z.object({
  assessmentId: z.uuid(),
  entries: z.array(markEntrySchema),
});
export type SaveMarksInput = z.infer<typeof saveMarksSchema>;

export const gradeBandSchema = z.object({
  grade: gradeSchema,
  min: z.number().min(0).max(100),
});

export const reminderScheduleSchema = z.object({
  days: z.array(z.number().int().positive().max(365)).max(8),
});
export type ReminderScheduleInput = z.infer<typeof reminderScheduleSchema>;
