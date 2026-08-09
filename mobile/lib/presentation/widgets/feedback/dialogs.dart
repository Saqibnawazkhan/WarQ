import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

/// Confirmation dialog used before destructive actions.
///
/// Returns `true` only when the user explicitly confirms.
Future<bool> showConfirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Confirm',
  String cancelLabel = 'Cancel',
  bool isDestructive = false,
  IconData? icon,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      final Color accent = isDestructive
          ? dialogContext.semantic.danger
          : dialogContext.colors.primary;
      return AlertDialog(
        icon: icon == null
            ? null
            : Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.12),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: accent, size: 24),
              ),
        title: Text(title),
        content: Text(message),
        actionsPadding: const EdgeInsets.fromLTRB(
          AppSpacing.lg,
          0,
          AppSpacing.lg,
          AppSpacing.lg,
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: Text(cancelLabel),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: isDestructive
                ? FilledButton.styleFrom(
                    backgroundColor: dialogContext.semantic.danger,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(0, 44),
                  )
                : FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            child: Text(confirmLabel),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

/// Bottom sheet host with the app's rounded top corners, keyboard-aware
/// padding and a safe maximum height.
Future<T?> showAppSheet<T>(
  BuildContext context, {
  required Widget Function(BuildContext context) builder,
  bool isScrollControlled = true,
  bool isDismissible = true,
}) {
  // Supplying `constraints` replaces the default ones wholesale, so the height
  // cap has to be restated here. Without it the sheet grows past the bottom of
  // the screen and its actions become untappable.
  final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;

  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: isScrollControlled,
    isDismissible: isDismissible,
    useSafeArea: true,
    constraints: BoxConstraints(maxWidth: 640, maxHeight: maxHeight),
    builder: (BuildContext sheetContext) {
      return Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(sheetContext).bottom,
        ),
        child: builder(sheetContext),
      );
    },
  );
}

/// Standard content wrapper for a bottom sheet: title, optional action, body.
class AppSheet extends StatelessWidget {
  const AppSheet({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actions,
    this.padding = const EdgeInsets.fromLTRB(
      AppSpacing.xl,
      AppSpacing.sm,
      AppSpacing.xl,
      AppSpacing.xl,
    ),
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final List<Widget>? actions;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    // The bound lives here rather than only on the modal route: without a
    // bounded height the `Flexible` below cannot constrain the body, the inner
    // scroll view sizes itself to its content, and a long sheet runs off the
    // bottom of the screen with its actions unreachable.
    final double maxHeight = MediaQuery.sizeOf(context).height * 0.88;

    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: maxHeight),
        child: Padding(
          padding: padding,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          title,
                          style: context.text.titleLarge?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        if (subtitle != null) ...<Widget>[
                          const SizedBox(height: 2),
                          Text(
                            subtitle!,
                            style: context.text.bodySmall?.copyWith(
                              color: context.semantic.mutedText,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  if (actions != null) ...actions!,
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              Flexible(child: child),
            ],
          ),
        ),
      ),
    );
  }
}

/// Blocking progress overlay shown during long operations such as PDF
/// generation.
Future<T> withBlockingProgress<T>(
  BuildContext context,
  Future<T> Function() action, {
  String message = 'Working…',
}) async {
  final NavigatorState navigator = Navigator.of(context, rootNavigator: true);
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    useRootNavigator: true,
    builder: (BuildContext dialogContext) => PopScope(
      canPop: false,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.xxl,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            color: dialogContext.colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.md),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              const SizedBox(
                width: 26,
                height: 26,
                child: CircularProgressIndicator(strokeWidth: 2.6),
              ),
              const SizedBox(height: AppSpacing.lg),
              Text(message, style: dialogContext.text.bodyMedium),
            ],
          ),
        ),
      ),
    ),
  );

  try {
    return await action();
  } finally {
    if (navigator.canPop()) navigator.pop();
  }
}
