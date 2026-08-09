/**
 * Native UI primitives, mirroring the web components against the same tokens.
 *
 * These are deliberately small and unclever: a phone in a classroom benefits
 * more from predictable, fast components than from a general-purpose system.
 */

import type { ReactNode } from 'react';
import {
  ActivityIndicator,
  Pressable,
  StyleSheet,
  Text as RNText,
  View,
  type StyleProp,
  type TextStyle,
  type ViewStyle,
} from 'react-native';

import { statusLabel, type SubscriptionStatus } from '@warq/core';
import { tint } from '@warq/tokens';

import { elevation, MIN_TOUCH, theme } from '../lib/theme';

// ── Text ────────────────────────────────────────────────────

type TextTone = 'strong' | 'base' | 'muted' | 'faint' | 'accent' | 'onAccent' | 'danger';
type TextVariant = 'title' | 'heading' | 'body' | 'label' | 'caption' | 'stat';

const TONE: Record<TextTone, string> = {
  strong: theme.color.ink.strong,
  base: theme.color.ink.base,
  muted: theme.color.ink.muted,
  faint: theme.color.ink.faint,
  accent: theme.color.brand.accent,
  onAccent: theme.color.brand.onAccent,
  danger: theme.color.status.expired,
};

const VARIANT: Record<TextVariant, TextStyle> = {
  stat: { fontFamily: theme.font.display, fontSize: 24 },
  title: { fontFamily: theme.font.display, fontSize: 22 },
  heading: { fontFamily: theme.font.display, fontSize: 15 },
  body: { fontFamily: theme.font.body, fontSize: 14, lineHeight: 20 },
  label: { fontFamily: theme.font.bodySemibold, fontSize: 12.5 },
  caption: { fontFamily: theme.font.body, fontSize: 11.5 },
};

interface TextProps {
  readonly children: ReactNode;
  readonly variant?: TextVariant;
  readonly tone?: TextTone;
  readonly style?: StyleProp<TextStyle>;
  readonly numberOfLines?: number;
}

export function Text({
  children,
  variant = 'body',
  tone = 'strong',
  style,
  numberOfLines,
}: TextProps) {
  return (
    <RNText numberOfLines={numberOfLines} style={[VARIANT[variant], { color: TONE[tone] }, style]}>
      {children}
    </RNText>
  );
}

// ── Card ────────────────────────────────────────────────────

export function Card({ children, style }: { children: ReactNode; style?: StyleProp<ViewStyle> }) {
  return <View style={[styles.card, style]}>{children}</View>;
}

// ── Button ──────────────────────────────────────────────────

type ButtonVariant = 'primary' | 'secondary' | 'danger';

interface ButtonProps {
  readonly label: string;
  readonly onPress: () => void;
  readonly variant?: ButtonVariant;
  readonly disabled?: boolean;
  readonly loading?: boolean;
  readonly style?: StyleProp<ViewStyle>;
}

export function Button({
  label,
  onPress,
  variant = 'primary',
  disabled,
  loading,
  style,
}: ButtonProps) {
  const background =
    variant === 'primary'
      ? theme.color.brand.accent
      : variant === 'danger'
        ? theme.color.surface.raised
        : theme.color.surface.raised;

  const foreground =
    variant === 'primary'
      ? theme.color.brand.onAccent
      : variant === 'danger'
        ? theme.color.status.expired
        : theme.color.ink.base;

  return (
    <Pressable
      accessibilityRole="button"
      accessibilityState={{ disabled: disabled || loading }}
      onPress={onPress}
      disabled={disabled || loading}
      style={({ pressed }) => [
        styles.button,
        {
          backgroundColor: background,
          borderColor:
            variant === 'primary'
              ? theme.color.brand.accent
              : variant === 'danger'
                ? theme.color.border.danger
                : theme.color.border.input,
          opacity: disabled ? 0.5 : pressed ? 0.88 : 1,
        },
        style,
      ]}
    >
      {loading ? (
        <ActivityIndicator color={foreground} />
      ) : (
        <RNText style={[styles.buttonLabel, { color: foreground }]}>{label}</RNText>
      )}
    </Pressable>
  );
}

// ── Status pill ─────────────────────────────────────────────

const STATUS_COLOR: Record<SubscriptionStatus, string> = {
  active: theme.color.status.active,
  pending: theme.color.status.pending,
  expiring_soon: theme.color.status.expiringSoon,
  expired: theme.color.status.expired,
  suspended: theme.color.status.suspended,
};

export function StatusPill({ status }: { status: SubscriptionStatus }) {
  const hex = STATUS_COLOR[status];

  return (
    <View style={[styles.pill, { backgroundColor: tint(hex, '1A') }]}>
      <RNText style={[styles.pillLabel, { color: hex }]}>{statusLabel(status)}</RNText>
    </View>
  );
}

// ── Empty state ─────────────────────────────────────────────

export function EmptyState({ title, body }: { title: string; body: string }) {
  return (
    <View style={styles.empty}>
      <Text variant="heading">{title}</Text>
      <Text variant="body" tone="muted" style={styles.emptyBody}>
        {body}
      </Text>
    </View>
  );
}

// ── Loading ─────────────────────────────────────────────────

export function Loading({ label = 'Loading…' }: { label?: string }) {
  return (
    <View style={styles.loading}>
      <ActivityIndicator color={theme.color.brand.accent} />
      <Text variant="caption" tone="muted">
        {label}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  card: {
    backgroundColor: theme.color.surface.raised,
    borderColor: theme.color.border.base,
    borderWidth: 1,
    borderRadius: theme.radius['3xl'],
    padding: 16,
    ...elevation.card,
  },
  button: {
    minHeight: MIN_TOUCH + 6,
    borderRadius: theme.radius.lg,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    paddingHorizontal: 18,
  },
  buttonLabel: {
    fontFamily: theme.font.bodyBold,
    fontSize: 14.5,
  },
  pill: {
    borderRadius: theme.radius.xs,
    paddingHorizontal: 10,
    paddingVertical: 4,
    alignSelf: 'flex-start',
  },
  pillLabel: {
    fontFamily: theme.font.bodyBold,
    fontSize: 11,
  },
  empty: {
    alignItems: 'center',
    gap: 6,
    paddingVertical: 40,
    paddingHorizontal: 24,
  },
  emptyBody: {
    textAlign: 'center',
  },
  loading: {
    alignItems: 'center',
    gap: 10,
    paddingVertical: 40,
  },
});
