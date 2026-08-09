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
    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.zero,
        itemCount: actions.length,
        separatorBuilder: (_, __) => const SizedBox(width: AppSpacing.md),
        itemBuilder: (BuildContext context, int index) =>
            _QuickActionTile(action: actions[index]),
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
        width: 92,
        child: Material(
          color: context.colors.surface,
          borderRadius: AppRadii.cardRadius,
          child: InkWell(
            onTap: enabled ? action.onTap : null,
            borderRadius: AppRadii.cardRadius,
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.sm,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                borderRadius: AppRadii.cardRadius,
                border: Border.all(color: context.semantic.subtleBorder),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    width: 38,
                    height: 38,
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(AppRadii.sm),
                    ),
                    child: Icon(action.icon, size: 20, color: color),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Flexible so a long label or a large font scale shrinks the
                  // text block instead of overflowing the fixed-height tile.
                  Flexible(
                    child: Text(
                      action.label,
                      maxLines: 2,
                      textAlign: TextAlign.center,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelSmall?.copyWith(height: 1.2),
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
