import { Link } from 'expo-router';
import { RefreshControl, ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { formatCalendarDate, pluralize, today } from '@warq/core';

import { usePendingRegisters, useToday } from '../../lib/queries';
import { useSession } from '../../lib/session';
import { theme } from '../../lib/theme';
import { Card, EmptyState, Loading, Text } from '../../ui';

/**
 * Today.
 *
 * Unmarked classes first: the reason to open this screen in the morning is to
 * find what still needs doing.
 */
export default function Today() {
  const { session } = useSession();
  const classes = useToday();
  const queue = usePendingRegisters();
  const insets = useSafeAreaInsets();

  const rows = classes.data ?? [];
  const pending = rows.filter((row) => !row.taken);
  const done = rows.filter((row) => row.taken);
  const ordered = [...pending, ...done];

  const firstName = session?.profile.full_name.split(' ')[0] ?? '';
  const waiting = queue.data ?? [];

  return (
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
      <View>
        <Text variant="caption" tone="muted" style={styles.eyebrow}>
          {formatCalendarDate(today()).toUpperCase()}
        </Text>
        <Text variant="title">Good morning{firstName ? `, ${firstName}` : ''}</Text>
      </View>

      {waiting.length > 0 && (
        <Card style={styles.queueCard}>
          <Text variant="label" tone="base">
            {pluralize(waiting.length, 'register')} waiting to sync
          </Text>
          <Text variant="caption" tone="muted" style={styles.queueBody}>
            Saved on this phone. They will send themselves as soon as you have signal — nothing is
            lost, and nothing needs doing.
          </Text>
        </Card>
      )}

      <View style={styles.stats}>
        <Stat value={String(rows.length)} label="Classes" tone={theme.color.brand.accent} />
        <Stat
          value={String(rows.reduce((sum, row) => sum + Number(row.student_count ?? 0), 0))}
          label="Students"
        />
        <Stat
          value={`${done.length}/${rows.length}`}
          label="Marked"
          tone={pending.length === 0 ? theme.color.status.active : theme.color.status.pending}
        />
      </View>

      <Card>
        <Text variant="heading" style={styles.cardTitle}>
          Today&rsquo;s register
        </Text>

        {classes.isLoading ? (
          <Loading />
        ) : ordered.length === 0 ? (
          <EmptyState
            title="No classes yet"
            body="Create a class on the Classes tab, add your students, and the register becomes a thirty-second job."
          />
        ) : (
          <View style={styles.list}>
            {ordered.map((row) => {
              const marked =
                Number(row.present ?? 0) + Number(row.absent ?? 0) + Number(row.late ?? 0);

              return (
                <Link
                  key={row.class_id}
                  href={{
                    pathname: '/(tabs)/attendance',
                    params: { class: row.class_id ?? '' },
                  }}
                  asChild
                >
                  <View style={styles.row}>
                    <View
                      style={[
                        styles.stripe,
                        {
                          backgroundColor:
                            theme.color.series[(row.color_index ?? 0) % theme.color.series.length],
                        },
                      ]}
                    />

                    <View style={styles.rowBody}>
                      <Text variant="body" numberOfLines={1} style={styles.rowTitle}>
                        {row.name}
                      </Text>
                      <Text variant="caption" tone="muted">
                        Section {row.section} ·{' '}
                        {pluralize(Number(row.student_count ?? 0), 'student')}
                      </Text>
                    </View>

                    {row.taken ? (
                      <Text variant="label" style={styles.done}>
                        ✓ {row.present}/{marked}
                      </Text>
                    ) : (
                      <View style={styles.markButton}>
                        <Text variant="label" tone="onAccent">
                          Mark
                        </Text>
                      </View>
                    )}
                  </View>
                </Link>
              );
            })}
          </View>
        )}
      </Card>
    </ScrollView>
  );
}

function Stat({ value, label, tone }: { value: string; label: string; tone?: string }) {
  return (
    <Card style={styles.stat}>
      <Text variant="stat" style={tone ? { color: tone } : undefined}>
        {value}
      </Text>
      <Text variant="caption" tone="muted">
        {label}
      </Text>
    </Card>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.surface.canvas },
  content: { padding: 20, paddingBottom: 40, gap: 16 },
  eyebrow: { letterSpacing: 1, marginBottom: 2 },
  stats: { flexDirection: 'row', gap: 10 },
  stat: { flex: 1, padding: 14, gap: 2 },
  cardTitle: { marginBottom: 10 },
  list: { gap: 8 },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 12,
    borderWidth: 1,
    borderColor: theme.color.border.subtle,
    borderRadius: theme.radius.lg,
    paddingHorizontal: 12,
    paddingVertical: 11,
  },
  stripe: { width: 8, height: 30, borderRadius: 99 },
  rowBody: { flex: 1, gap: 2 },
  rowTitle: { fontFamily: theme.font.bodyBold },
  done: { color: theme.color.status.active },
  markButton: {
    backgroundColor: theme.color.brand.accent,
    borderRadius: 99,
    paddingHorizontal: 16,
    paddingVertical: 8,
  },
  queueCard: { backgroundColor: '#D977060F', borderColor: 'transparent', gap: 4 },
  queueBody: { lineHeight: 17 },
});
