import { useMemo, useState } from 'react';
import { Pressable, ScrollView, StyleSheet, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { classAverage, formatCalendarDate, gradeFor, percentage } from '@warq/core';
import { tint } from '@warq/tokens';

import { useAssessments, useClasses, useMarks, useRoster, useSaveMarks } from '../../lib/queries';
import { theme } from '../../lib/theme';
import { Button, Card, EmptyState, Loading, Text } from '../../ui';

/**
 * Marks entry.
 *
 * The grade beside each box updates as you type, so a mistyped mark shows itself
 * immediately. An empty box means not marked — stored as nothing, and left out
 * of the student's total. A zero means they sat it and scored none.
 */
export default function Marks() {
  const classes = useClasses();
  const save = useSaveMarks();
  const insets = useSafeAreaInsets();

  const classRows = useMemo(() => classes.data ?? [], [classes.data]);
  const [pickedClass, setPickedClass] = useState<string | null>(null);
  const classId = pickedClass ?? classRows[0]?.id ?? undefined;

  const assessments = useAssessments(classId);
  const papers = useMemo(() => assessments.data ?? [], [assessments.data]);
  const [pickedPaper, setPickedPaper] = useState<string | null>(null);
  const assessmentId = pickedPaper ?? papers[0]?.id;

  const paper = papers.find((row) => row.id === assessmentId);
  const roster = useRoster(classId);
  const marks = useMarks(assessmentId);

  const [edits, setEdits] = useState<Record<string, string> | null>(null);
  const [notice, setNotice] = useState<string | null>(null);

  const saved = useMemo(() => {
    const map: Record<string, string> = {};
    for (const mark of marks.data ?? []) {
      map[mark.student_id] = mark.score === null ? '' : String(mark.score);
    }
    return map;
  }, [marks.data]);

  const students = roster.data ?? [];
  const current = edits ?? saved;
  const total = Number(paper?.total_marks ?? 0);

  const sheet = students.map((student) => {
    const raw = (current[student.id] ?? '').trim();
    const score = raw === '' ? null : Number(raw);
    const pct = score === null ? null : percentage(score, total);

    return {
      student,
      raw,
      score,
      grade: pct === null ? null : gradeFor(pct),
      over: score !== null && score > total,
    };
  });

  const average = classAverage(
    sheet.map((row) => row.score),
    total,
  );

  function submit() {
    if (!assessmentId) return;
    setNotice(null);

    if (sheet.some((row) => row.over || (row.score !== null && !Number.isFinite(row.score)))) {
      setNotice(`A mark is above the total of ${total}. Check it before saving.`);
      return;
    }

    save.mutate(
      {
        assessmentId,
        entries: sheet.map((row) => ({ studentId: row.student.id, score: row.score })),
      },
      {
        onSuccess: (result) => {
          setEdits(null);
          setNotice(`Saved · ${result.marked} of ${students.length} marked`);
        },
        onError: (cause) => setNotice(cause.message),
      },
    );
  }

  if (!classes.isLoading && classRows.length === 0) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + 24, padding: 20 }]}>
        <Card>
          <EmptyState title="No classes yet" body="Create a class and add students first." />
        </Card>
      </View>
    );
  }

  return (
    <View style={styles.screen}>
      <ScrollView contentContainerStyle={[styles.content, { paddingTop: insets.top + 16 }]}>
        <Text variant="title">Marks</Text>

        <ChipRow
          items={classRows.map((row) => ({
            id: row.id ?? '',
            label: `${row.name ?? 'Class'} · ${row.section ?? ''}`,
          }))}
          selected={classId}
          onSelect={(id) => {
            setEdits(null);
            setNotice(null);
            setPickedPaper(null);
            setPickedClass(id);
          }}
        />

        {papers.length === 0 ? (
          <Card>
            <EmptyState
              title="No assessments yet"
              body="Create one from the class page, then enter marks against it here."
            />
          </Card>
        ) : (
          <>
            <ChipRow
              items={papers.map((row) => ({ id: row.id, label: row.name }))}
              selected={assessmentId}
              onSelect={(id) => {
                setEdits(null);
                setNotice(null);
                setPickedPaper(id);
              }}
            />

            {paper && (
              <Text variant="caption" tone="muted">
                {paper.type} · {formatCalendarDate(paper.date)} · out of {paper.total_marks} · class
                average {average === null ? '—' : `${average}%`}
              </Text>
            )}

            {notice && (
              <Card style={styles.notice}>
                <Text variant="caption" tone="base">
                  {notice}
                </Text>
              </Card>
            )}

            {roster.isLoading ? (
              <Loading />
            ) : (
              <View style={styles.list}>
                {sheet.map(({ student, raw, grade, over }) => (
                  <View key={student.id} style={styles.row}>
                    <View style={styles.rowBody}>
                      <Text variant="body" numberOfLines={1}>
                        {student.full_name}
                      </Text>
                      <Text variant="caption" tone="muted">
                        {student.roll_no}
                      </Text>
                    </View>

                    <TextInput
                      value={raw}
                      onChangeText={(value) =>
                        setEdits((existing) => ({ ...(existing ?? saved), [student.id]: value }))
                      }
                      keyboardType="numeric"
                      placeholder="—"
                      placeholderTextColor={theme.color.ink.faint}
                      accessibilityLabel={`Mark for ${student.full_name}, out of ${total}`}
                      style={[styles.input, over && styles.inputOver]}
                    />

                    <View
                      style={[
                        styles.gradeChip,
                        {
                          backgroundColor: tint(
                            grade ? theme.color.grade[grade] : theme.color.grade.none,
                            '1A',
                          ),
                        },
                      ]}
                    >
                      <Text
                        variant="label"
                        style={{
                          color: grade ? theme.color.grade[grade] : theme.color.grade.none,
                        }}
                      >
                        {grade ?? '—'}
                      </Text>
                    </View>
                  </View>
                ))}
              </View>
            )}
          </>
        )}
      </ScrollView>

      {papers.length > 0 && students.length > 0 && (
        <View style={styles.footer}>
          <Button
            label={save.isPending ? 'Saving…' : 'Save marks'}
            onPress={submit}
            loading={save.isPending}
          />
        </View>
      )}
    </View>
  );
}

function ChipRow({
  items,
  selected,
  onSelect,
}: {
  items: { id: string; label: string }[];
  selected: string | undefined;
  onSelect: (id: string) => void;
}) {
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.chips}
    >
      {items.map((item) => {
        const active = item.id === selected;
        return (
          <Pressable
            key={item.id}
            accessibilityRole="button"
            accessibilityState={{ selected: active }}
            onPress={() => onSelect(item.id)}
            style={[styles.chip, active && styles.chipActive]}
          >
            <Text variant="label" tone={active ? 'onAccent' : 'base'}>
              {item.label}
            </Text>
          </Pressable>
        );
      })}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.surface.canvas },
  content: { padding: 20, paddingBottom: 96, gap: 12 },
  chips: { gap: 8, paddingRight: 20 },
  chip: {
    borderRadius: 99,
    borderWidth: 1,
    borderColor: theme.color.border.base,
    backgroundColor: theme.color.surface.raised,
    paddingHorizontal: 14,
    paddingVertical: 9,
  },
  chipActive: { backgroundColor: theme.color.brand.accent, borderColor: theme.color.brand.accent },
  notice: { backgroundColor: '#4338CA0F', borderColor: 'transparent', padding: 14 },
  list: { gap: 7 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 10,
    backgroundColor: theme.color.surface.raised,
    borderWidth: 1,
    borderColor: theme.color.border.base,
    borderRadius: theme.radius.xl,
    paddingLeft: 14,
    paddingRight: 10,
    paddingVertical: 8,
  },
  rowBody: { flex: 1, gap: 1 },
  input: {
    width: 62,
    height: 42,
    borderRadius: theme.radius.md,
    borderWidth: 1,
    borderColor: theme.color.border.input,
    backgroundColor: theme.color.surface.sunken,
    textAlign: 'center',
    fontFamily: theme.font.bodyBold,
    fontSize: 15,
    color: theme.color.ink.strong,
  },
  inputOver: { borderColor: theme.color.status.expired, color: theme.color.status.expired },
  gradeChip: {
    width: 44,
    paddingVertical: 6,
    borderRadius: theme.radius.xs,
    alignItems: 'center',
  },
  footer: { position: 'absolute', left: 20, right: 20, bottom: 12 },
});
