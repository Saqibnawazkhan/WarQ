import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/theme/glass.dart';

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

  /// Height of a cell, and so of the bar's contents.
  static const double _cellHeight = 46;

  /// Everything this bar covers, measured from the bottom of the screen: the
  /// cells, the padding around them, the gap it floats above the edge by, and
  /// the system inset underneath all of it.
  ///
  /// The shells set `extendBody: true` so pages scroll behind the bar, which
  /// means nothing below it is laid out around it. Anything that must stay
  /// clear — a page's last row, a tab's action button — asks for this.
  static double reservedHeight(BuildContext context) =>
      _cellHeight +
      AppSpacing.sm * 2 +
      AppSpacing.md +
      MediaQuery.viewPaddingOf(context).bottom;

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
        // Real glass here, and worth the saved layer: the page scrolls right
        // underneath this bar, so the blur is the thing you actually see doing
        // its job. There is exactly one of these on screen at a time.
        child: DecoratedBox(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            boxShadow: Glass.shadow(context),
          ),
          child: GlassSurface(
            borderRadius: BorderRadius.circular(AppRadii.xl),
            blur: 22,
            raised: true,
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
    final Color foreground = selected
        ? context.colors.primary
        : context.semantic.mutedText;

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
            height: FloatingNavBar._cellHeight,
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
