import { useLocalSearchParams } from 'expo-router';
import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import {
  ATTENDANCE_MARKS,
  DEFAULT_MARK,
  formatCalendarDate,
  MARK_INITIAL,
  markLabel,
  pluralize,
  today,
  type AttendanceMark,
} from '@warq/core';

import { useAttendance, useClasses, useRoster, useSaveAttendance } from '../../lib/queries';
import { MIN_TOUCH, theme } from '../../lib/theme';
import { Button, Card, EmptyState, Loading, Text } from '../../ui';

/**
 * The register.
 *
 * Everyone starts Present, as the mockups do — a register is mostly presences,
 * so the default needing fewest taps is the right one.
 *
 * Saving works with no signal: the register is written to the phone and sent
 * later. The confirmation says which happened rather than implying success.
 */
export default function Attendance() {
  const params = useLocalSearchParams<{ class?: string }>();
  const classes = useClasses();
  const save = useSaveAttendance();
  const insets = useSafeAreaInsets();

  const rows = useMemo(() => classes.data ?? [], [classes.data]);
  const [picked, setPicked] = useState<string | null>(null);
  const classId = picked ?? params.class ?? rows[0]?.id ?? undefined;
  const date = today();

  const roster = useRoster(classId);
  const attendance = useAttendance(classId, date);

  const [edits, setEdits] = useState<Record<string, AttendanceMark> | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const saved = useMemo(() => {
    const map: Record<string, AttendanceMark> = {};
    for (const record of attendance.data?.records ?? []) map[record.student_id] = record.mark;
    return map;
  }, [attendance.data]);

  const students = roster.data ?? [];
  const current = edits ?? saved;

  const markOf = (studentId: string): AttendanceMark => current[studentId] ?? DEFAULT_MARK;

  function set(studentId: string, mark: AttendanceMark) {
    setEdits((existing) => {
      const base: Record<string, AttendanceMark> = { ...(existing ?? saved) };
      for (const student of students) base[student.id] ??= DEFAULT_MARK;
      base[studentId] = mark;
      return base;
    });
  }

  function allPresent() {
    const next: Record<string, AttendanceMark> = {};
    for (const student of students) next[student.id] = 'present';
    setEdits(next);
  }

  const tally = students.reduce(
    (counts, student) => ({ ...counts, [markOf(student.id)]: counts[markOf(student.id)] + 1 }),
    { present: 0, absent: 0, late: 0 },
  );

  function submit() {
    if (!classId) return;
    setNotice(null);

    save.mutate(
      {
        classId,
        date,
        entries: students.map((student) => ({ studentId: student.id, mark: markOf(student.id) })),
      },
      {
        onSuccess: (outcome) => {
          setEdits(null);

          if (outcome.queued) {
            setNotice(
              'Saved on this phone. It will send itself as soon as you have signal — you can close the app.',
            );
            return;
          }

          const absent = outcome.result?.absent ?? 0;
          const alertable = outcome.result?.alertable ?? 0;

          setNotice(
            absent === 0
              ? 'Register saved · everyone present'
              : alertable === 0
                ? `Register saved · ${pluralize(absent, 'absence')}, no guardian contacts on file`
                : `Register saved · ${pluralize(absent, 'absence')} · ${pluralize(alertable, 'alert')} queued`,
          );
        },
        onError: (cause) => setNotice(cause.message),
      },
    );
  }

  if (!classes.isLoading && rows.length === 0) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + 24 }]}>
        <Card>
          <EmptyState title="No classes yet" body="Create a class and add students first." />
        </Card>
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + 16 }]}>
        <View>
          <Text variant="caption" tone="muted" style={styles.eyebrow}>
            {formatCalendarDate(date).toUpperCase()}
          </Text>
          <Text variant="title">Attendance</Text>
        </View>

        <ScrollView
          horizontal
          showsHorizontalScrollIndicator={false}
          contentContainerStyle={styles.chips}
        >
          {rows.map((row) => {
            const active = row.id === classId;
            return (
              <Pressable
                key={row.id}
                accessibilityRole="button"
                accessibilityState={{ selected: active }}
                onPress={() => {
                  setEdits(null);
                  setNotice(null);
                  setPicked(row.id ?? null);
                }}
                style={[styles.chip, active && styles.chipActive]}
              >
                <Text variant="label" tone={active ? 'onAccent' : 'base'}>
                  {row.name} · {row.section}
                </Text>
              </Pressable>
            );
          })}
        </ScrollView>

        {roster.isLoading ? (
          <Loading />
        ) : students.length === 0 ? (
          <Card>
            <EmptyState
              title="No students in this class"
              body="Add students from the class page, then come back to take the register."
            />
          </Card>
        ) : (
          <>
            <Card style={styles.summary}>
              <Text variant="label" style={{ color: theme.color.status.active }}>
                {tally.present} present
              </Text>
              <Text variant="label" style={{ color: theme.color.status.expired }}>
                {tally.absent} absent
              </Text>
              <Text variant="label" style={{ color: theme.color.status.pending }}>
                {tally.late} late
              </Text>
              <Pressable onPress={allPresent} accessibilityRole="button" style={styles.allPresent}>
                <Text variant="label" tone="accent">
                  All present
                </Text>
              </Pressable>
            </Card>

            {notice && (
              <Card style={styles.notice}>
                <Text variant="caption" tone="base">
                  {notice}
                </Text>
              </Card>
            )}

            <View style={styles.list}>
              {students.map((student) => (
                <View key={student.id} style={styles.studentRow}>
                  <View style={styles.studentBody}>
                    <Text variant="body" numberOfLines={1}>
                      {student.full_name}
                    </Text>
                    <Text variant="caption" tone="muted">
                      {student.roll_no}
                    </Text>
                  </View>

                  <View style={styles.marks}>
                    {ATTENDANCE_MARKS.map((option) => {
                      const selected = markOf(student.id) === option;
                      const hex = theme.color.attendance[option];

                      return (
                        <Pressable
                          key={option}
                          accessibilityRole="radio"
                          accessibilityState={{ checked: selected }}
                          accessibilityLabel={`${markLabel(option)} for ${student.full_name}`}
                          onPress={() => set(student.id, option)}
                          style={[
                            styles.markButton,
                            {
                              backgroundColor: selected ? hex : theme.color.surface.sunken,
                              borderColor: selected ? hex : theme.color.border.input,
                            },
                          ]}
                        >
                          <Text
                            variant="label"
                            style={{ color: selected ? '#fff' : theme.color.ink.faint }}
                          >
                            {MARK_INITIAL[option]}
                          </Text>
                        </Pressable>
                      );
                    })}
                  </View>
                </View>
              ))}
            </View>
          </>
        )}
      </ScrollView>

      {students.length > 0 && (
        <View style={[styles.footer, { paddingBottom: 12 }]}>
          <Button
            label={
              save.isPending
                ? 'Saving…'
                : attendance.data?.session
                  ? 'Update register'
                  : 'Save register'
            }
            onPress={submit}
            loading={save.isPending}
          />
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.surface.canvas },
  content: { padding: 20, paddingBottom: 96, gap: 14 },
  eyebrow: { letterSpacing: 1, marginBottom: 2 },
  chips: { gap: 8, paddingRight: 20 },
  chip: {
    borderRadius: 99,
    borderWidth: 1,
    borderColor: theme.color.border.base,
    backgroundColor: theme.color.surface.raised,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  chipActive: {
    backgroundColor: theme.color.brand.accent,
    borderColor: theme.color.brand.accent,
  },
  summary: { flexDirection: 'row', alignItems: 'center', gap: 14, padding: 14 },
  allPresent: { marginLeft: 'auto' },
  notice: { backgroundColor: '#4338CA0F', borderColor: 'transparent', padding: 14 },
  list: { gap: 7 },
  studentRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 8,
    backgroundColor: theme.color.surface.raised,
    borderWidth: 1,
    borderColor: theme.color.border.base,
    borderRadius: theme.radius.xl,
    paddingLeft: 14,
    paddingRight: 8,
    paddingVertical: 8,
  },
  studentBody: { flex: 1, gap: 1 },
  marks: { flexDirection: 'row', gap: 6 },
  markButton: {
    width: MIN_TOUCH,
    height: MIN_TOUCH,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  footer: {
    position: 'absolute',
    left: 20,
    right: 20,
    bottom: 0,
  },
});
