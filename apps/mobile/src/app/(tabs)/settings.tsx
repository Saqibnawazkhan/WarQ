import { router } from 'expo-router';
import { ScrollView, StyleSheet, View } from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { formatCalendarDate, planLabel, roleLabel } from '@warq/core';

import { usePendingRegisters } from '../../lib/queries';
import { useSession } from '../../lib/session';
import { appVersion } from '../../lib/supabase';
import { theme } from '../../lib/theme';
import { Button, Card, StatusPill, Text } from '../../ui';

export default function Settings() {
  const { session, signOut } = useSession();
  const queue = usePendingRegisters();
  const insets = useSafeAreaInsets();

  if (!session) return null;

  const { profile, organization, subscription } = session;
  const waiting = queue.data ?? [];

  return (
    <ScrollView
      style={styles.screen}
      contentContainerStyle={[styles.content, { paddingTop: insets.top + 16 }]}
    >
      <Text variant="title">Account</Text>

      <Card>
        <Row label="Name" value={profile.full_name} />
        <Row label="Email" value={profile.email} />
        <Row label="Role" value={roleLabel(profile.role)} />
        <Row label="Organization" value={organization?.name ?? 'Independent'} last />
      </Card>

      {subscription && (
        <Card>
          <Text variant="heading" style={styles.cardTitle}>
            Subscription
          </Text>
          <Row label="Plan" value={subscription.plan ? planLabel(subscription.plan) : '—'} />
          <Row
            label="Expires"
            value={
              subscription.plan === 'permanent'
                ? 'No expiry'
                : formatCalendarDate(subscription.ends_at)
            }
          />
          <View style={styles.statusRow}>
            <Text variant="label" tone="muted">
              Status
            </Text>
            {subscription.status ? <StatusPill status={subscription.status} /> : null}
          </View>
        </Card>
      )}

      <Card>
        <Text variant="heading" style={styles.cardTitle}>
          Offline registers
        </Text>
        <Text variant="caption" tone="muted" style={styles.body}>
          {waiting.length === 0
            ? 'Everything is synced. Registers taken without signal are saved here until they can be sent.'
            : `${waiting.length} waiting to send. They will go automatically as soon as you have signal.`}
        </Text>
        {waiting.length > 0 && (
          <Button
            label="Try sending now"
            variant="secondary"
            onPress={() => void queue.refetch()}
            style={styles.retry}
          />
        )}
      </Card>

      <Button
        label="Sign out"
        variant="danger"
        onPress={() => {
          void signOut().then(() => router.replace('/sign-in'));
        }}
      />

      <Text variant="caption" tone="faint" style={styles.version}>
        Warq {appVersion}
      </Text>
    </ScrollView>
  );
}

function Row({ label, value, last }: { label: string; value: string; last?: boolean }) {
  return (
    <View style={[styles.row, !last && styles.rowDivider]}>
      <Text variant="label" tone="muted">
        {label}
      </Text>
      <Text variant="label" style={styles.rowValue} numberOfLines={1}>
        {value}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  screen: { flex: 1, backgroundColor: theme.color.surface.canvas },
  content: { padding: 20, paddingBottom: 40, gap: 12 },
  cardTitle: { marginBottom: 8 },
  row: { flexDirection: 'row', justifyContent: 'space-between', gap: 16, paddingVertical: 10 },
  rowDivider: { borderBottomWidth: 1, borderBottomColor: theme.color.border.subtle },
  rowValue: { flexShrink: 1, textAlign: 'right' },
  statusRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    alignItems: 'center',
    paddingTop: 10,
  },
  body: { lineHeight: 17 },
  retry: { marginTop: 12 },
  version: { textAlign: 'center', marginTop: 8 },
});
