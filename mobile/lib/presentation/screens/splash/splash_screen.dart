import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

/// Shown while the session is restored from storage.
class SplashScreen extends StatelessWidget {
  const SplashScreen({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const AppLogo(size: 72),
            const SizedBox(height: AppSpacing.xl),
            Text(
              AppConstants.appName,
              style: context.text.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.4,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              message ?? AppConstants.appTagline,
              style: context.text.bodyMedium
                  ?.copyWith(color: context.semantic.mutedText),
            ),
            const SizedBox(height: AppSpacing.xxxl),
            const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4),
            ),
          ],
        ),
      ),
    );
  }
}

/// The app mark.
///
/// The device on its own rather than the full lockup: the wordmark beside it is
/// dark navy and would disappear in dark mode, while the mark's blue reads on
/// either ground. Wherever the name is needed it is set in the app's own type
/// beside this, which does follow the theme.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 48});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      'assets/brand/warq_mark.png',
      width: size,
      height: size,
      fit: BoxFit.contain,
      // Decorative: the name is always written out next to it, so a screen
      // reader announcing the logo as well would only repeat itself.
      excludeFromSemantics: true,
    );
  }
}
