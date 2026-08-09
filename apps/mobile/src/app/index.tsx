import { Redirect } from 'expo-router';
import { View } from 'react-native';

import { canUsePlatform } from '@warq/core';

import { useSession } from '../lib/session';
import { Loading } from '../ui';
import { theme } from '../lib/theme';

/**
 * The gate.
 *
 * Sends a signed-in teacher to their classes and everyone else to sign in.
 * A Main Admin cannot reach here — the session guard refuses to mint them a
 * mobile session — but the check is repeated rather than assumed, because an
 * app that trusts an earlier layer is one change away from trusting nothing.
 */
export default function Index() {
  const { session, loading } = useSession();

  if (loading) {
    return (
      <View
        style={{ flex: 1, justifyContent: 'center', backgroundColor: theme.color.surface.canvas }}
      >
        <Loading label="Signing you in…" />
      </View>
    );
  }

  if (!session) return <Redirect href="/sign-in" />;

  if (!canUsePlatform(session.profile.role, 'mobile')) {
    return <Redirect href="/sign-in" />;
  }

  return <Redirect href="/(tabs)" />;
}
