import 'package:flutter/material.dart';

import '../constants/app_constants.dart';
import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';

/// Ergonomic accessors so widgets stay focused on layout rather than plumbing.
extension BuildContextX on BuildContext {
  ThemeData get theme => Theme.of(this);
  ColorScheme get colors => Theme.of(this).colorScheme;
  TextTheme get text => Theme.of(this).textTheme;

  /// Semantic palette registered as a theme extension.
  AppSemanticColors get semantic =>
      Theme.of(this).extension<AppSemanticColors>() ?? AppSemanticColors.light;

  bool get isDark => Theme.of(this).brightness == Brightness.dark;

  MediaQueryData get media => MediaQuery.of(this);
  Size get screenSize => MediaQuery.sizeOf(this);
  double get screenWidth => MediaQuery.sizeOf(this).width;
  double get screenHeight => MediaQuery.sizeOf(this).height;

  bool get isCompact => AppBreakpoints.isCompact(screenWidth);
  bool get isExpanded => AppBreakpoints.isExpanded(screenWidth);

  /// Bottom inset caused by the on-screen keyboard.
  double get keyboardInset => MediaQuery.viewInsetsOf(this).bottom;
  bool get isKeyboardOpen => keyboardInset > 0;

  NavigatorState get navigator => Navigator.of(this);
  ScaffoldMessengerState get messenger => ScaffoldMessenger.of(this);
}

/// Shows a styled snackbar through an already-captured messenger.
///
/// Use this when the message must appear *after* the current route is popped —
/// capture the messenger before the async gap, pop, then call this. A screen
/// with a tall `bottomNavigationBar` cannot display a floating snackbar (it is
/// pushed off screen), so the confirmation belongs on the destination screen.
void showSnackOn(
  ScaffoldMessengerState messenger,
  String message, {
  IconData? icon,
  Color? background,
  SnackBarAction? action,
  Duration? duration,
}) {
  messenger
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Row(
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 20, color: Colors.white),
              const SizedBox(width: AppSpacing.md),
            ],
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: background,
        action: action,
        duration: duration ?? AppConstants.snackBarDuration,
      ),
    );
}

/// Success styling for [showSnackOn].
void showSuccessOn(ScaffoldMessengerState messenger, String message) =>
    showSnackOn(
      messenger,
      message,
      icon: Icons.check_circle_outline_rounded,
      background: AppColors.success,
    );

/// Snackbar helpers with consistent styling for success / error / info states.
extension SnackBarX on BuildContext {
  void showSnack(
    String message, {
    IconData? icon,
    Color? background,
    SnackBarAction? action,
    Duration? duration,
  }) {
    showSnackOn(
      ScaffoldMessenger.of(this),
      message,
      icon: icon,
      background: background,
      action: action,
      duration: duration,
    );
  }

  void showSuccess(String message, {SnackBarAction? action}) => showSnack(
        message,
        icon: Icons.check_circle_outline_rounded,
        background: AppColors.success,
        action: action,
      );

  void showError(String message, {SnackBarAction? action}) => showSnack(
        message,
        icon: Icons.error_outline_rounded,
        background: AppColors.danger,
        action: action,
      );

  void showInfo(String message, {SnackBarAction? action}) => showSnack(
        message,
        icon: Icons.info_outline_rounded,
        action: action,
      );

  void showWarning(String message, {SnackBarAction? action}) => showSnack(
        message,
        icon: Icons.warning_amber_rounded,
        background: AppColors.warning,
        action: action,
      );
}
