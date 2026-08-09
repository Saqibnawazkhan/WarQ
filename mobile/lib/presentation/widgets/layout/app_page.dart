import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';

/// Constrains page content to a comfortable reading width.
///
/// Phones get the full width; tablets and foldables centre the content instead
/// of stretching rows across 10 inches.
class ContentWidth extends StatelessWidget {
  const ContentWidth({
    super.key,
    required this.child,
    this.maxWidth = AppBreakpoints.maxContentWidth,
    this.fillHeight = true,
  });

  final Widget child;
  final double maxWidth;

  /// Whether to expand to the full available height.
  ///
  /// `true` (the default) is what a scrollable page body needs — a `ListView`
  /// must be handed a bounded height. Set it to `false` anywhere the parent
  /// passes bounded constraints but expects this to wrap its child, most
  /// importantly inside `Scaffold.bottomNavigationBar`: a centring box would
  /// otherwise stretch the bar over the entire screen.
  final bool fillHeight;

  @override
  Widget build(BuildContext context) {
    return Center(
      heightFactor: fillHeight ? null : 1,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}

/// A scrollable page body with the app's standard padding, pull-to-refresh and
/// responsive width.
class AppPageBody extends StatelessWidget {
  const AppPageBody({
    super.key,
    required this.children,
    this.onRefresh,
    this.padding = AppSpacing.pageInsets,
    this.controller,
    this.physics,
  });

  final List<Widget> children;
  final Future<void> Function()? onRefresh;
  final EdgeInsets padding;
  final ScrollController? controller;
  final ScrollPhysics? physics;

  @override
  Widget build(BuildContext context) {
    final Widget list = ListView(
      controller: controller,
      physics: physics ??
          (onRefresh == null
              ? null
              : const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                )),
      padding: padding,
      children: children,
    );

    final Widget constrained = ContentWidth(child: list);
    if (onRefresh == null) return constrained;
    return RefreshIndicator(onRefresh: onRefresh!, child: constrained);
  }
}

/// Vertical gap helpers that keep spacing consistent without magic numbers.
class Gap extends StatelessWidget {
  const Gap(this.size, {super.key});

  const Gap.xs({super.key}) : size = AppSpacing.xs;
  const Gap.sm({super.key}) : size = AppSpacing.sm;
  const Gap.md({super.key}) : size = AppSpacing.md;
  const Gap.lg({super.key}) : size = AppSpacing.lg;
  const Gap.xl({super.key}) : size = AppSpacing.xl;
  const Gap.xxl({super.key}) : size = AppSpacing.xxl;

  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(height: size, width: size);
}
