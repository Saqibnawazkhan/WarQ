import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

/// One shortcut on the dashboard's quick-action row.
class QuickAction {
  const QuickAction({
    required this.label,
    required this.icon,
    required this.onTap,
    this.color,
    this.enabled = true,
  });

  final String label;
  final IconData icon;
  final VoidCallback onTap;
  final Color? color;
  final bool enabled;
}

/// Horizontally scrolling shortcuts for the actions teachers use most:
/// mark attendance, add student, add marks, generate report.
class QuickActionBar extends StatelessWidget {
  const QuickActionBar({super.key, required this.actions});

  final List<QuickAction> actions;

  @override
  Widget build(BuildContext context) {
    // The bar takes the height of its tallest tile instead of a fixed one: at
    // the larger type scale a two-line label ("Mark attendance") no longer fits
    // a hard-coded box, and clipping a shortcut's name mid-word hides what it
    // does. Stretching the row also keeps every card the same height.
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            for (int i = 0; i < actions.length; i++) ...<Widget>[
              if (i > 0) const SizedBox(width: AppSpacing.md),
              _QuickActionTile(action: actions[i]),
            ],
          ],
        ),
      ),
    );
  }
}

class _QuickActionTile extends StatelessWidget {
  const _QuickActionTile({required this.action});

  final QuickAction action;

  @override
  Widget build(BuildContext context) {
    final Color color = action.color ?? context.colors.primary;
    final bool enabled = action.enabled;

    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: SizedBox(
        // Wide enough that the longest word in a label ("attendance") still
        // sits on one line at the 1.35 text scale the app allows.
        width: 116,
        child: Material(
          color: context.colors.surface,
          borderRadius: AppRadii.cardRadius,
          child: InkWell(
            onTap: enabled ? action.onTap : null,
            borderRadius: AppRadii.cardRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.md,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: context.semantic.subtleBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(action.icon, size: 22, color: color),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  // Flexible so an unusually long label still degrades to an
                  // ellipsis rather than an overflow, even though the bar now
                  // grows to fit two lines.
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium?.copyWith(height: 1.25),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
