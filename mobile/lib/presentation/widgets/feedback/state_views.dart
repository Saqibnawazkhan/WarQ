import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../state/base_controller.dart';
import '../layout/app_page.dart';

/// Centred spinner used while a screen loads for the first time.
class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.message});

  final String? message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(strokeWidth: 2.6),
          ),
          if (message != null) ...<Widget>[
            const Gap.lg(),
            Text(
              message!,
              style: context.text.bodyMedium?.copyWith(
                color: context.semantic.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Shimmer-free skeleton: neutral blocks that hint at the incoming layout.
class SkeletonList extends StatelessWidget {
  const SkeletonList({super.key, this.itemCount = 4, this.itemHeight = 84});

  final int itemCount;
  final double itemHeight;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: AppSpacing.pageInsets,
      itemCount: itemCount,
      separatorBuilder: (_, __) => const Gap.md(),
      itemBuilder: (BuildContext context, int index) => Container(
        height: itemHeight,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHigh,
          borderRadius: AppRadii.cardRadius,
        ),
      ),
    );
  }
}

/// Friendly empty state with an optional call to action.
class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    required this.title,
    required this.message,
    this.icon = Icons.inbox_outlined,
    this.actionLabel,
    this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
    this.compact = false,
  });

  final String title;
  final String message;
  final IconData icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryActionLabel;
  final VoidCallback? onSecondaryAction;

  /// Renders without vertical centring, for use inside a scrolling page.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.xxl,
        vertical: AppSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.colors.primary.withValues(alpha: 0.10),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 30, color: context.colors.primary),
          ),
          const Gap.xl(),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap.sm(),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.semantic.mutedText,
            ),
          ),
          if (onAction != null && actionLabel != null) ...<Widget>[
            const Gap.xl(),
            SizedBox(
              width: 240,
              child: FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add_rounded, size: 20),
                label: Text(actionLabel!),
              ),
            ),
          ],
          if (onSecondaryAction != null && secondaryActionLabel != null) ...<Widget>[
            const Gap.sm(),
            TextButton(
              onPressed: onSecondaryAction,
              child: Text(secondaryActionLabel!),
            ),
          ],
        ],
      ),
    );

    if (compact) return content;
    return Center(child: SingleChildScrollView(child: content));
  }
}

/// Error state with a retry affordance.
class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.title = 'Something went wrong',
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final String title;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      padding: const EdgeInsets.all(AppSpacing.xxl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: context.semantic.dangerContainer,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.error_outline_rounded,
              size: 30,
              color: context.semantic.danger,
            ),
          ),
          const Gap.xl(),
          Text(
            title,
            textAlign: TextAlign.center,
            style: context.text.titleMedium?.copyWith(fontWeight: FontWeight.w700),
          ),
          const Gap.sm(),
          Text(
            message,
            textAlign: TextAlign.center,
            style: context.text.bodyMedium?.copyWith(
              color: context.semantic.mutedText,
            ),
          ),
          if (onRetry != null) ...<Widget>[
            const Gap.xl(),
            SizedBox(
              width: 200,
              child: OutlinedButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh_rounded, size: 20),
                label: const Text('Try again'),
              ),
            ),
          ],
        ],
      ),
    );

    if (compact) return content;
    return Center(child: SingleChildScrollView(child: content));
  }
}

/// Renders the right view for a controller's [ViewStatus].
///
/// Screens describe *what* each state looks like and this widget decides
/// *when* to show it, so the loading/empty/error handling required by the spec
/// is impossible to forget.
class ControllerStateView extends StatelessWidget {
  const ControllerStateView({
    super.key,
    required this.controller,
    required this.builder,
    this.loading,
    this.empty,
    this.onRetry,
  });

  final BaseController controller;
  final WidgetBuilder builder;
  final Widget? loading;
  final Widget? empty;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    switch (controller.status) {
      case ViewStatus.idle:
      case ViewStatus.loading:
        return loading ?? const LoadingView();
      case ViewStatus.error:
        return ErrorView(
          message: controller.errorMessage ?? 'Please try again.',
          onRetry: onRetry ?? controller.refresh,
        );
      case ViewStatus.empty:
        return empty ?? builder(context);
      case ViewStatus.ready:
      case ViewStatus.refreshing:
        return builder(context);
    }
  }
}
