import 'package:flutter/material.dart';

import '../../../core/theme/app_spacing.dart';
import 'floating_nav_bar.dart';

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

/// Lifts a shell tab's floating action button clear of the floating nav bar.
///
/// A tab has its own [Scaffold] nested inside the shell's, and that inner one
/// knows nothing about the bar, so it drops its button at the bottom of the
/// screen — underneath it. Padding the button pushes it up by that much,
/// because the location that places it measures the widget it is given.
///
/// The height is asked for rather than read from the media query, which is
/// what a page body does: Scaffold strips the padding from the button's slot
/// before building it, so there it always reads as zero.
///
/// Only for tabs inside a shell. On a pushed route there is no bar to clear and
/// this would leave a gap under the button.
class ClearOfNavBar extends StatelessWidget {
  const ClearOfNavBar({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: FloatingNavBar.reservedHeight(context),
      ),
      child: child,
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
    // The shells set `extendBody: true` so the page scrolls behind the floating
    // nav bar — that is what the bar has to blur. Scaffold reports the height it
    // gave up as bottom padding, and it has to be added here or the last item on
    // every page finishes underneath the bar. On a screen with no bottom bar
    // this is zero and the padding is unchanged.
    final EdgeInsets insets = padding.copyWith(
      bottom: padding.bottom + MediaQuery.paddingOf(context).bottom,
    );

    final Widget list = ListView(
      controller: controller,
      physics: physics ??
          (onRefresh == null
              ? null
              : const AlwaysScrollableScrollPhysics(
                  parent: BouncingScrollPhysics(),
                )),
      padding: insets,
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
