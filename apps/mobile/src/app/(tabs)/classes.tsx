import { Link } from 'expo-router';
import { useState } from 'react';
import { Modal, RefreshControl, ScrollView, StyleSheet, TextInput, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { formatCalendarDate, pluralize } from '@warq/core';

import { useClasses, useCreateClass } from '../../lib/queries';
import { theme } from '../../lib/theme';
import { Button, Card, EmptyState, Loading, Text } from '../../ui';

export default function Classes() {
  const classes = useClasses();
  const insets = useSafeAreaInsets();
  const [creating, setCreating] = useState(false);

  const rows = classes.data ?? [];

  return (
    <>
      <ScrollView
        style={styles.screen}
        contentContainerStyle={[styles.content, { paddingTop: insets.top + 16 }]}
        refreshControl={
          <RefreshControl
            refreshing={classes.isFetching}
            onRefresh={() => void classes.refetch()}
            tintColor={theme.color.brand.accent}
          />
        }
      >
        <View style={styles.header}>
          <Text variant="title">Classes</Text>
          <Button label="+ New" onPress={() => setCreating(true)} style={styles.newButton} />
        </View>

        {classes.isLoading ? (
          <Loading />
        ) : rows.length === 0 ? (
          <Card>
            <EmptyState
              title="No classes yet"
              body="A class holds your students, their registers and their marks. Create one to begin."
            />
          </Card>
        ) : (
          rows.map((row) => (
            <Link key={row.id} href={`/class/${row.id ?? ''}`} asChild>
              <Card style={styles.classCard}>
                <View
                  style={[
                    styles.stripe,
                    {
                      backgroundColor:
                        theme.color.series[(row.color_index ?? 0) % theme.color.series.length],
                    },
                  ]}
                />

                <View style={styles.classBody}>
                  <Text variant="heading" numberOfLines={1}>
                    {row.name}
                  </Text>
                  <Text variant="caption" tone="muted">
                    Section {row.section} · Session {row.session}
                  </Text>

                  <View style={styles.facts}>
                    <Text variant="caption" tone="base">
                      {pluralize(Number(row.student_count ?? 0), 'student')}
                    </Text>
                    <Text variant="caption" tone="base">
                      {(row.session_count ?? 0) === 0
                        ? 'no registers'
                        : `${row.attendance_percent ?? 0}% attendance`}
                    </Text>
                    <Text variant="caption" tone="base">
                      {pluralize(Number(row.assessment_count ?? 0), 'assessment')}
                    </Text>
                  </View>

                  <Text variant="caption" tone="faint" style={styles.lastSeen}>
                    {row.last_session_date
                      ? `Last register ${formatCalendarDate(row.last_session_date)}`
                      : 'No register taken yet'}
                  </Text>
                </View>
              </Card>
            </Link>
          ))
        )}
      </ScrollView>

      <NewClassSheet open={creating} onClose={() => setCreating(false)} />
    </>
  );
}

function NewClassSheet({ open, onClose }: { open: boolean; onClose: () => void }) {
  const create = useCreateClass();

  const [name, setName] = useState('');
  const [section, setSection] = useState('');
  const [session, setSession] = useState(String(new Date().getUTCFullYear()));
  const [error, setError] = useState<string | null>(null);

  function submit() {
    setError(null);

    create.mutate(
      { name, section, session },
      {
        onSuccess: () => {
          setName('');
          setSection('');
          onClose();
        },
        onError: (cause) => setError(cause.message),
      },
    );
  }

  return (
    <Modal visible={open} animationType="slide" transparent onRequestClose={onClose}>
      <View style={styles.scrim}>
        <View style={styles.sheet}>
          <View style={styles.grabber} />
          <Text variant="heading" style={styles.sheetTitle}>
            New class
          </Text>

          <SheetField
            label="Class name"
            value={name}
            onChangeText={setName}
            placeholder="Software Engineering"
          />
          <SheetField label="Section" value={section} onChangeText={setSection} placeholder="A" />
          <SheetField label="Session" value={session} onChangeText={setSession} />

          {error && (
            <Text variant="caption" tone="danger">
              {error}
            </Text>
          )}

          <View style={styles.sheetActions}>
            <Button
              label={create.isPending ? 'Creating…' : 'Create class'}
              onPress={submit}
              loading={create.isPending}
              style={styles.flex}
            />
            <Button label="Cancel" variant="secondary" onPress={onClose} />
          </View>
        </View>
      </View>
    </Modal>
  );
}

function SheetField({
  label,
  ...rest
}: { label: string } & React.ComponentProps<typeof TextInput>) {
  return (
    <View style={styles.field}>
      <Text variant="label" tone="base">
        {label}
      </Text>
      <TextInput
        {...rest}
        accessibilityLabel={label}
        placeholderTextColor={theme.color.ink.faint}
        style={styles.input}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.surface.canvas },
  content: { padding: 20, paddingBottom: 40, gap: 12 },
  header: { flexDirection: 'row', alignItems: 'center', justifyContent: 'space-between' },
  newButton: { paddingHorizontal: 16, minHeight: 40 },
  classCard: { flexDirection: 'row', gap: 12 },
  stripe: { width: 8, borderRadius: 99 },
  classBody: { flex: 1, gap: 3 },
  facts: { flexDirection: 'row', flexWrap: 'wrap', gap: 12, marginTop: 6 },
  lastSeen: { marginTop: 4 },
  scrim: { flex: 1, backgroundColor: 'rgba(23,23,58,0.4)', justifyContent: 'flex-end' },
  sheet: {
    backgroundColor: theme.color.surface.raised,
    borderTopLeftRadius: theme.radius['4xl'],
    borderTopRightRadius: theme.radius['4xl'],
    padding: 20,
    paddingBottom: 34,
    gap: 12,
  },
  grabber: {
    width: 36,
    height: 4,
    borderRadius: 99,
    backgroundColor: theme.color.border.input,
    alignSelf: 'center',
    marginBottom: 6,
  },
  sheetTitle: { marginBottom: 2 },
  field: { gap: 6 },
  input: {
    height: 50,
    borderRadius: theme.radius.lg,
    borderWidth: 1,
    borderColor: theme.color.border.input,
    backgroundColor: theme.color.surface.sunken,
    paddingHorizontal: 15,
    fontFamily: theme.font.body,
    fontSize: 15,
    color: theme.color.ink.strong,
  },
  sheetActions: { flexDirection: 'row', gap: 10, marginTop: 6 },
  flex: { flex: 1 },
});
