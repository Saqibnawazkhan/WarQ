import { Redirect, Tabs } from 'expo-router';
import { Platform, StyleSheet, View } from 'react-native';

import { useSession } from '../../lib/session';
import { theme } from '../../lib/theme';
import { Loading, Text } from '../../ui';

/**
 * The four tabs from the mockup: Home, Classes, Attendance, Marks.
 *
 * Glyphs rather than an icon library — the mockups use typographic marks, and a
 * whole icon package for four symbols is weight a teacher on a slow connection
 * pays for.
 */
const TABS = [
  { name: 'index', title: 'Today', glyph: '◧' },
  { name: 'classes', title: 'Classes', glyph: '◫' },
  { name: 'attendance', title: 'Attendance', glyph: '✓' },
  { name: 'marks', title: 'Marks', glyph: '◔' },
  { name: 'settings', title: 'Account', glyph: '◎' },
] as const;

export default function TabsLayout() {
  const { session, loading } = useSession();

  if (loading) return <Loading label="Loading your classes…" />;
  if (!session) return <Redirect href="/sign-in" />;

  return (
    <Tabs
      screenOptions={{
        headerShown: false,
        tabBarActiveTintColor: theme.color.brand.accent,
        tabBarInactiveTintColor: theme.color.ink.disabled,
        tabBarStyle: {
          backgroundColor: theme.color.surface.raised,
          borderTopColor: theme.color.border.base,
          height: Platform.OS === 'ios' ? 84 : 64,
          paddingTop: 6,
        },
        tabBarLabelStyle: {
          fontFamily: theme.font.bodyBold,
          fontSize: 10,
        },
      }}
    >
      {TABS.map((tab) => (
        <Tabs.Screen
          key={tab.name}
          name={tab.name}
          options={{
            title: tab.title,
            tabBarIcon: ({ color: tint }) => (
              <View style={styles.icon}>
                <Text style={[styles.glyph, { color: tint }]}>{tab.glyph}</Text>
              </View>
            ),
          }}
        />
      ))}
    </Tabs>
  );
}

const styles = StyleSheet.create({
  icon: { alignItems: 'center', justifyContent: 'center' },
  glyph: { fontFamily: theme.font.display, fontSize: 18 },
});
