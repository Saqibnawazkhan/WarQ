/**
 * The offline attendance queue.
 *
 * Classrooms lose signal — thick walls, basements, a school on the edge of
 * coverage. A teacher standing in front of thirty students should not have to
 * care. So a register is written to the device first and sent when it can be.
 *
 * This is only safe because `save_attendance` is idempotent: the session is
 * keyed on (class_id, date) and each mark on (session_id, student_id), so
 * sending the same register twice corrects it rather than duplicating it. The
 * queue can therefore retry blindly, without asking the server what it already
 * has — which is exactly the question it cannot ask when it has no signal.
 */

import AsyncStorage from '@react-native-async-storage/async-storage';

import type { AttendanceMark, CalendarDate } from '@warq/core';
import { saveAttendance, type SaveAttendanceResult, type WarqClient } from '@warq/data';

const STORAGE_KEY = 'warq.attendance.queue.v1';

export interface PendingRegister {
  readonly classId: string;
  readonly date: CalendarDate;
  readonly entries: { studentId: string; mark: AttendanceMark }[];
  /** Milliseconds since the epoch, for showing how long it has been waiting. */
  readonly queuedAt: number;
}

export interface SaveOutcome {
  readonly queued: boolean;
  readonly result: SaveAttendanceResult | null;
}

async function readQueue(): Promise<PendingRegister[]> {
  const raw = await AsyncStorage.getItem(STORAGE_KEY);
  if (!raw) return [];

  try {
    const parsed: unknown = JSON.parse(raw);
    return Array.isArray(parsed) ? (parsed as PendingRegister[]) : [];
  } catch {
    // Corrupt storage should cost one register, not every future one.
    await AsyncStorage.removeItem(STORAGE_KEY);
    return [];
  }
}

async function writeQueue(queue: readonly PendingRegister[]): Promise<void> {
  await AsyncStorage.setItem(STORAGE_KEY, JSON.stringify(queue));
}

/**
 * One register per class per day in the queue.
 *
 * A teacher who corrects a register while still offline should end up with the
 * corrected version queued, not both versions racing to the server.
 */
function replace(queue: readonly PendingRegister[], entry: PendingRegister): PendingRegister[] {
  return [
    ...queue.filter((item) => !(item.classId === entry.classId && item.date === entry.date)),
    entry,
  ];
}

/**
 * Saves a register, or queues it if that fails.
 *
 * Any failure queues — not just an obviously offline one. A request that times
 * out on a bad connection is indistinguishable from one that never left, and
 * losing a register is far worse than sending it twice.
 */
export async function queueOrSaveAttendance(
  client: WarqClient,
  input: {
    classId: string;
    date: CalendarDate;
    entries: { studentId: string; mark: AttendanceMark }[];
  },
): Promise<SaveOutcome> {
  try {
    const result = await saveAttendance(client, input);
    return { queued: false, result };
  } catch (cause) {
    // A refusal by the database is a real answer and must not be retried
    // forever: a suspended subscription or someone else's class will never
    // succeed, however many times it is sent.
    if (isPermanentFailure(cause)) throw cause;

    const queue = await readQueue();
    await writeQueue(replace(queue, { ...input, queuedAt: Date.now() }));

    return { queued: true, result: null };
  }
}

function isPermanentFailure(cause: unknown): boolean {
  if (!(cause instanceof Error)) return false;

  return /subscription is not active|your own class|future date|permission|denied/i.test(
    cause.message,
  );
}

/**
 * Sends everything waiting, and returns what is still stuck.
 *
 * Called whenever the app comes back into focus, which is the moment a teacher
 * is most likely to have walked somewhere with signal.
 */
export async function flushQueue(client: WarqClient): Promise<PendingRegister[]> {
  const queue = await readQueue();
  if (queue.length === 0) return [];

  const stillPending: PendingRegister[] = [];

  for (const entry of queue) {
    try {
      await saveAttendance(client, {
        classId: entry.classId,
        date: entry.date,
        entries: entry.entries,
      });
    } catch (cause) {
      // A permanent refusal is dropped rather than retried until the end of
      // time; anything else waits for the next attempt.
      if (!isPermanentFailure(cause)) stillPending.push(entry);
    }
  }

  await writeQueue(stillPending);
  return stillPending;
}

export async function clearQueue(): Promise<void> {
  await AsyncStorage.removeItem(STORAGE_KEY);
}
