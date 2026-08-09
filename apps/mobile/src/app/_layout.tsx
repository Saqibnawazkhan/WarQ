import {
  PublicSans_400Regular,
  PublicSans_500Medium,
  PublicSans_600SemiBold,
  PublicSans_700Bold,
} from '@expo-google-fonts/public-sans';
import { Sora_700Bold, Sora_800ExtraBold } from '@expo-google-fonts/sora';
import { useFonts } from 'expo-font';
import { Stack } from 'expo-router';
import * as SplashScreen from 'expo-splash-screen';
import { StatusBar } from 'expo-status-bar';
import { useEffect } from 'react';
import { QueryClient, QueryClientProvider } from '@tanstack/react-query';
import { SafeAreaProvider } from 'react-native-safe-area-context';

import { SessionProvider } from '../lib/session';
import { theme } from '../lib/theme';

void SplashScreen.preventAutoHideAsync();

const queryClient = new QueryClient({
  defaultOptions: {
    queries: {
      // A phone on a weak connection should not hammer a failing request.
      retry: 1,
      staleTime: 60_000,
      refetchOnWindowFocus: true,
    },
  },
});

export default function RootLayout() {
  // Bundled with the app rather than fetched, so the first launch on a weak
  // connection still shows the right typeface.
  const [fontsReady, fontError] = useFonts({
    Sora_700Bold,
    Sora_800ExtraBold,
    PublicSans_400Regular,
    PublicSans_500Medium,
    PublicSans_600SemiBold,
    PublicSans_700Bold,
  });

  useEffect(() => {
    // Held until the typefaces are ready, so the first frame is not the wrong
    // font. A missing font file must not leave the splash screen up forever,
    // so an error releases it too.
    if (fontsReady || fontError) void SplashScreen.hideAsync();
  }, [fontsReady, fontError]);

  if (!fontsReady && !fontError) return null;

  return (
    <SafeAreaProvider>
      <QueryClientProvider client={queryClient}>
        <SessionProvider>
          <StatusBar style="dark" />
          <Stack
            screenOptions={{
              headerShown: false,
              contentStyle: { backgroundColor: theme.color.surface.canvas },
            }}
          />
        </SessionProvider>
      </QueryClientProvider>
    </SafeAreaProvider>
  );
}
