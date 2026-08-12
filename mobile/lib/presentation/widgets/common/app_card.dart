import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/glass.dart';
import '../layout/app_page.dart';

/// The app's standard surface: bordered, flat, rounded.
class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.padding = AppSpacing.cardPadding,
    this.onTap,
    this.onLongPress,
    this.color,
    this.borderColor,
    this.margin,
  });

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;

  /// Handled by the card's own ink well. Callers must not nest another
  /// [InkWell] in [child] for this — a deeper gesture detector wins the arena
  /// and would swallow [onTap].
  final VoidCallback? onLongPress;
  final Color? color;
  final Color? borderColor;
  final EdgeInsets? margin;

  @override
  Widget build(BuildContext context) {
    // Glass without the filter. A card has nothing moving behind it, so a
    // BackdropFilter here would cost a saved layer per card — thirty of them on
    // a register — to blur a background that is already a soft gradient. The
    // translucent fill and the bright hairline edge are what the eye reads as
    // glass; over the app's background they do it on their own.
    //
    // A caller that passes its own colour means it, so that wins: the tinted
    // cards that carry a status still need to be that status's colour.
    final Widget content = Container(
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Glass.fill(context),
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: borderColor ?? Glass.edge(context)),
      ),
      child: child,
    );

    final Widget wrapped = (onTap == null && onLongPress == null)
        ? content
        : Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              onLongPress: onLongPress,
              borderRadius: AppRadii.cardRadius,
              child: content,
            ),
          );

    return margin == null ? wrapped : Padding(padding: margin!, child: wrapped);
  }
}

/// A titled block: heading, optional action, and content.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    required this.title,
    required this.child,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.leading,
    this.padding = AppSpacing.cardPadding,
  });

  final String title;
  final Widget child;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? leading;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (leading != null) ...<Widget>[
                leading!,
                const SizedBox(width: AppSpacing.md),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // A card heading and a [SectionHeader] label the same level
                    // of the page, so they are set at the same size. titleSmall
                    // put this heading level with the row names underneath it.
                    Text(
                      title,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (subtitle != null) ...<Widget>[
                      const Gap.xs(),
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
              if (onAction != null && actionLabel != null)
                TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.sm,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  child: Text(actionLabel!),
                ),
            ],
          ),
          const Gap.lg(),
          child,
        ],
      ),
    );
  }
}

/// Section heading used directly on the page background (outside a card).
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
    this.trailing,
  });

  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: <Widget>[
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (subtitle != null) ...<Widget>[
                  const Gap.xs(),
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
          if (trailing != null) trailing!,
          if (trailing == null && onAction != null && actionLabel != null)
            TextButton(onPressed: onAction, child: Text(actionLabel!)),
        ],
      ),
    );
  }
}
