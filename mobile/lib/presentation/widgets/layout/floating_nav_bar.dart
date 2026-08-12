import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';

/// One destination on [FloatingNavBar].
class NavItem {
  const NavItem({
    required this.icon,
    required this.selectedIcon,
    required this.label,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;
}

/// The app's bottom navigation.
///
/// A bar that floats clear of the screen edge rather than sitting flat against
/// it, and shows the label of the selected destination only — the others
/// collapse to their icon and slide over to make room.
///
/// That is not only fashion. Five labels side by side is what forced
/// "Assessments" to be abbreviated: a fifth of a phone could not hold the word,
/// so it wrapped and broke the bar's alignment. With one label on screen at a
/// time there is room for whatever the destination is actually called, and the
/// four icons left over are easier to hit for being wider apart.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.items,
    required this.currentIndex,
    required this.onSelect,
  });

  final List<NavItem> items;
  final int currentIndex;
  final ValueChanged<int> onSelect;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          0,
          AppSpacing.md,
          AppSpacing.md,
        ),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: context.colors.surface,
            borderRadius: BorderRadius.circular(AppRadii.xl),
            border: Border.all(color: context.semantic.subtleBorder),
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: context.colors.shadow.withValues(alpha: 0.10),
                blurRadius: 24,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.sm,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: <Widget>[
                // Three shares to the selected cell against one each for the
                // rest, because it is the only one carrying a word. An even
                // split left it a fifth of the bar, which fitted the icon and
                // one letter; two shares still clipped "Attendance", the
                // longest label either shell uses.
                //
                // Expanded rather than Flexible so the cells fill the bar
                // rather than bunching in the middle.
                for (int i = 0; i < items.length; i++)
                  Expanded(
                    flex: i == currentIndex ? 3 : 1,
                    child: _NavCell(
                      item: items[i],
                      selected: i == currentIndex,
                      onTap: () => onSelect(i),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavCell extends StatelessWidget {
  const _NavCell({
    required this.item,
    required this.selected,
    required this.onTap,
  });

  final NavItem item;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final Color foreground =
        selected ? context.colors.primary : context.semantic.mutedText;

    return Semantics(
      button: true,
      selected: selected,
      label: item.label,
      child: Tooltip(
        // The four collapsed destinations show no label, so long-press is how
        // anyone unsure of an icon finds out what it is.
        message: item.label,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppRadii.pill),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            height: 46,
            padding: EdgeInsets.symmetric(
              horizontal: selected ? AppSpacing.lg : AppSpacing.md,
            ),
            decoration: BoxDecoration(
              color: selected
                  ? context.colors.primary.withValues(alpha: 0.12)
                  : Colors.transparent,
              borderRadius: BorderRadius.circular(AppRadii.pill),
            ),
            child: Row(
              // The cell now fills its share of the bar, so its contents are
              // centred in it rather than sitting against the left edge.
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.center,
              children: <Widget>[
                Icon(
                  selected ? item.selectedIcon : item.icon,
                  size: 23,
                  color: foreground,
                ),
                // Flexible, and inside the Row rather than beside it: a Row
                // whose children size to their content does not shrink them
                // when the space runs out, it lets them spill. Without this the
                // label of a long destination is painted straight over the
                // icon of the one next to it.
                if (selected)
                  Flexible(
                    child: AnimatedSize(
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutCubic,
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.only(left: AppSpacing.sm),
                        child: Text(
                          item.label,
                          maxLines: 1,
                          softWrap: false,
                          overflow: TextOverflow.fade,
                          style: context.text.labelLarge?.copyWith(
                            color: foreground,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
