import { router, useLocalSearchParams } from 'expo-router';
import { useState } from 'react';
import { Pressable, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { formatCalendarDate, pluralize } from '@warq/core';

import { useAssessments, useClasses, useRoster } from '../../lib/queries';
import { theme } from '../../lib/theme';
import { Button, Card, EmptyState, Loading, Text } from '../../ui';

/**
 * One class: its roster and its assessments.
 *
 * Read-mostly on a phone. Adding students is a sit-down job better done on a
 * laptop, so it is not duplicated here — the register and the mark sheet, which
 * are done standing up, are what the phone is for.
 */
export default function ClassDetail() {
  const { classId } = useLocalSearchParams<{ classId: string }>();
  const classes = useClasses();
  const roster = useRoster(classId);
  const assessments = useAssessments(classId);
  const insets = useSafeAreaInsets();

  const [tab, setTab] = useState<'students' | 'assessments'>('students');

  const cls = classes.data?.find((row) => row.id === classId);
  const students = roster.data ?? [];
  const papers = assessments.data ?? [];

  if (classes.isLoading) return <Loading />;

  if (!cls) {
    return (
      <View style={[styles.screen, { paddingTop: insets.top + 24, padding: 20 }]}>
        <Card>
          <EmptyState title="Class not found" body="It may have been archived or removed." />
        </Card>
      </View>
    );
  }

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + 12 }]}
    >
      <Pressable onPress={() => router.back()} accessibilityRole="button">
        <Text variant="label" tone="accent">
          ← Classes
        </Text>
      </Pressable>

      <View>
        <Text variant="title">{cls.name}</Text>
        <Text variant="caption" tone="muted">
          Section {cls.section} · Session {cls.session} · {pluralize(students.length, 'student')}
        </Text>
      </View>

      <View style={styles.tabs}>
        {(
          [
            ['students', `Students (${students.length})`],
            ['assessments', `Assessments (${papers.length})`],
          ] as const
        ).map(([value, label]) => (
          <Pressable
            key={value}
            accessibilityRole="tab"
            accessibilityState={{ selected: tab === value }}
            onPress={() => setTab(value)}
            style={[styles.tab, tab === value && styles.tabActive]}
          >
            <Text variant="label" tone={tab === value ? 'strong' : 'muted'}>
              {label}
            </Text>
          </Pressable>
        ))}
      </View>

      {tab === 'students' ? (
        students.length === 0 ? (
          <Card>
            <EmptyState
              title="No students yet"
              body="Add your roster on the web dashboard — it is a lot faster with a keyboard."
            />
          </Card>
        ) : (
          <View style={styles.list}>
            {students.map((student) => (
              <Card key={student.id} style={styles.listRow}>
                <View style={styles.listBody}>
                  <Text variant="body">{student.full_name}</Text>
                  <Text variant="caption" tone="muted">
                    {student.roll_no}
                  </Text>
                </View>
              </Card>
            ))}
          </View>
        )
      ) : papers.length === 0 ? (
        <Card>
          <EmptyState
            title="No assessments yet"
            body="Create one on the web dashboard, then enter marks here."
          />
        </Card>
      ) : (
        <View style={styles.list}>
          {papers.map((paper) => (
            <Card key={paper.id} style={styles.listRow}>
              <View style={styles.listBody}>
                <Text variant="body">{paper.name}</Text>
                <Text variant="caption" tone="muted">
                  {paper.type} · {formatCalendarDate(paper.date)} · out of {paper.total_marks}
                </Text>
              </View>
            </Card>
          ))}
        </View>
      )}

      <Button
        label="Take the register"
        onPress={() =>
          router.push({ pathname: '/(tabs)/attendance', params: { class: classId ?? '' } })
        }
        style={styles.action}
      />
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.surface.canvas },
  content: { padding: 20, paddingBottom: 40, gap: 14 },
  tabs: {
    flexDirection: 'row',
    gap: 20,
    borderBottomWidth: 1,
    borderBottomColor: theme.color.border.base,
  },
  tab: { paddingBottom: 10, borderBottomWidth: 2, borderBottomColor: 'transparent' },
  tabActive: { borderBottomColor: theme.color.brand.accent },
  list: { gap: 8 },
  listRow: { flexDirection: 'row', alignItems: 'center', padding: 14 },
  listBody: { flex: 1, gap: 2 },
  action: { marginTop: 6 },
});
