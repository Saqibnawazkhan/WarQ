import { router } from 'expo-router';
import { useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  ScrollView,
  StyleSheet,
  TextInput,
  View,
} from 'react-native';
import { useSafeAreaInsets } from 'react-native-safe-area-context';

import { EmailNotConfirmedError, signIn } from '@warq/data';

import { useSession } from '../lib/session';
import { supabase } from '../lib/supabase';
import { theme } from '../lib/theme';
import { Button, Text } from '../ui';

export default function SignIn() {
  const { refresh } = useSession();
  const insets = useSafeAreaInsets();

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState<string | null>(null);
  const [busy, setBusy] = useState(false);

  async function submit() {
    setError(null);
    setBusy(true);

    try {
      await signIn(supabase, { email, password }, 'mobile');
      await refresh();
      router.replace('/(tabs)');
    } catch (cause) {
      setError(
        cause instanceof EmailNotConfirmedError || cause instanceof Error
          ? cause.message
          : 'Something went wrong signing you in.',
      );
      setBusy(false);
    }
  }

  return (
    <KeyboardAvoidingView
      style={styles.flex}
      behavior={Platform.OS === 'ios' ? 'padding' : undefined}
    >
      <ScrollView
        contentContainerStyle={[styles.content, { paddingTop: insets.top + 48 }]}
        keyboardShouldPersistTaps="handled"
      >
        <View style={styles.brand}>
          <View style={styles.logo}>
            <Text variant="stat" tone="onAccent" style={styles.logoLetter}>
              W
            </Text>
          </View>
          <Text variant="title" style={styles.wordmark}>
            Warq
          </Text>
        </View>

        <Text variant="title" style={styles.headline}>
          Your classroom,{'\n'}managed in minutes.
        </Text>
        <Text variant="body" tone="muted" style={styles.blurb}>
          Attendance, marks, grades and reports — in your pocket.
        </Text>

        <View style={styles.form}>
          <Field
            label="Email"
            value={email}
            onChangeText={setEmail}
            placeholder="you@school.edu.pk"
            keyboardType="email-address"
            autoCapitalize="none"
            autoComplete="email"
          />
          <Field
            label="Password"
            value={password}
            onChangeText={setPassword}
            secureTextEntry
            autoComplete="current-password"
          />

          {error && (
            <View style={styles.error} accessibilityRole="alert">
              <Text variant="label" tone="danger">
                {error}
              </Text>
            </View>
          )}

          <Button
            label={busy ? 'Signing in…' : 'Sign in'}
            onPress={() => void submit()}
            loading={busy}
          />
        </View>

        <Text variant="caption" tone="muted" style={styles.footnote}>
          Platform administrators sign in on the web. This app is for teachers and organization
          admins.
        </Text>
      </ScrollView>
    </KeyboardAvoidingView>
  );
}

function Field({ label, ...rest }: { label: string } & React.ComponentProps<typeof TextInput>) {
  return (
    <View style={styles.field}>
      <Text variant="label" tone="base">
        {label}
      </Text>
      <TextInput
        {...rest}
        style={styles.input}
        placeholderTextColor={theme.color.ink.faint}
        accessibilityLabel={label}
      />
    </View>
  );
}

const styles = StyleSheet.create({
  flex: { flex: 1, backgroundColor: theme.color.surface.canvas },
  content: { paddingHorizontal: 24, paddingBottom: 40, gap: 8 },
  brand: { flexDirection: 'row', alignItems: 'center', gap: 10, marginBottom: 24 },
  logo: {
    width: 44,
    height: 44,
    borderRadius: 14,
    backgroundColor: theme.color.brand.accent,
    alignItems: 'center',
    justifyContent: 'center',
  },
  logoLetter: { fontSize: 20 },
  wordmark: { fontSize: 20 },
  headline: { fontSize: 26, lineHeight: 33 },
  blurb: { marginTop: 8 },
  form: { marginTop: 28, gap: 14 },
  field: { gap: 6 },
  input: {
    height: 52,
    borderRadius: theme.radius.lg,
    borderWidth: 1,
    borderColor: theme.color.border.input,
    backgroundColor: theme.color.surface.raised,
    paddingHorizontal: 16,
    fontFamily: theme.font.body,
    fontSize: 15,
    color: theme.color.ink.strong,
  },
  error: {
    borderRadius: theme.radius.md,
    backgroundColor: '#DC26260F',
    paddingHorizontal: 14,
    paddingVertical: 10,
  },
  footnote: { marginTop: 24, textAlign: 'center' },
});
