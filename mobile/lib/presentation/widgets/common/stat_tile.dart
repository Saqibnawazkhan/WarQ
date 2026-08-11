import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

/// Compact metric card: label, big value, optional icon and trend line.
class StatTile extends StatelessWidget {
  const StatTile({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.caption,
    this.accent,
    this.onTap,
  });

  final String label;
  final String value;
  final IconData? icon;
  final String? caption;

  /// Tints the icon chip and the value.
  final Color? accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final Color color = accent ?? context.colors.primary;

    return Material(
      color: context.colors.surface,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          // Taller than it is wide-padded. The vertical room carries the roomy
          // feel; the side padding stays tight because a three-up grid leaves a
          // tile only ~85pt wide on a phone, and every point spent on the
          // gutter is a point the value has to shrink by or the label loses to
          // an ellipsis.
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.xl,
          ),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(color: context.semantic.subtleBorder),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              if (icon != null) ...<Widget>[
                Container(
                  width: 36,
                  height: 36,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(AppRadii.sm),
                  ),
                  child: Icon(icon, size: 20, color: color),
                ),
                const SizedBox(height: AppSpacing.md),
              ],
              // The number is the card. Shrinking an unusually wide value beats
              // ellipsising it, because a truncated figure reads as a wrong one.
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  value,
                  maxLines: 1,
                  style: context.text.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                    color: accent == null ? null : color,
                  ),
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              Text(
                label,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(
                  color: context.semantic.mutedText,
                ),
              ),
              if (caption != null) ...<Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  caption!,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelSmall?.copyWith(color: color),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Responsive grid of [StatTile]s.
///
/// Tiles in a row are measured against each other, so a tile must be able to
/// report an intrinsic height — a `LayoutBuilder` at the root of one would
/// throw.
class StatGrid extends StatelessWidget {
  const StatGrid({super.key, required this.tiles, this.columns});

  final List<Widget> tiles;
  final int? columns;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (BuildContext context, BoxConstraints constraints) {
        final int count = columns ?? (constraints.maxWidth >= 520 ? 4 : 2);
        const double spacing = AppSpacing.lg;
        final double itemWidth =
            (constraints.maxWidth - spacing * (count - 1)) / count;

        final List<Widget> rows = <Widget>[];
        for (int start = 0; start < tiles.length; start += count) {
          final int end =
              start + count < tiles.length ? start + count : tiles.length;
          if (rows.isNotEmpty) rows.add(const SizedBox(height: spacing));
          rows.add(
            // Laid out row by row rather than wrapped so tiles that sit side by
            // side share a height — otherwise a card carrying a caption stands
            // taller than its neighbours and the grid looks ragged.
            IntrinsicHeight(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (int i = start; i < end; i++) ...<Widget>[
                    if (i > start) const SizedBox(width: spacing),
                    SizedBox(width: itemWidth, child: tiles[i]),
                  ],
                ],
              ),
            ),
          );
        }

        return Column(mainAxisSize: MainAxisSize.min, children: rows);
      },
    );
  }
}

/// A label/value row used inside detail cards.
class DetailRow extends StatelessWidget {
  const DetailRow({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.onTap,
    this.trailing,
  });

  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final Widget content = Padding(
      // A single line of body text is ~22pt, so `md` left a tappable row two
      // points short of the 48dp touch target. `lg` clears it and gives the
      // stacked contact rows the separation they lost when the labels grew.
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.lg),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            Icon(icon, size: 20, color: context.semantic.mutedText),
            const SizedBox(width: AppSpacing.md),
          ],
          Expanded(
            flex: 4,
            child: Text(
              label,
              style: context.text.bodyMedium?.copyWith(
                color: context.semantic.mutedText,
              ),
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            flex: 5,
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: context.text.bodyMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: valueColor,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            const SizedBox(width: AppSpacing.sm),
            trailing!,
          ],
        ],
      ),
    );

    if (onTap == null) return content;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AppRadii.xs),
      child: content,
    );
  }
}
