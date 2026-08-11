import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../domain/entities/dashboard_data.dart';

/// A class as a coloured tile, for the grid on the Classes tab.
///
/// The colour is the point: a teacher recognises "the orange one" long before
/// they read the name, and the database already hands every class a colour
/// index as it is created, so the six tiles in a grid are always distinct.
///
/// Deliberately carries less than [ClassCard] does. A grid tile is glanced at,
/// not read — the name and the size of the class are what a teacher needs to
/// pick the right one, and everything else is a tap away on the class itself.
class ClassGridTile extends StatelessWidget {
  const ClassGridTile({
    super.key,
    required this.summary,
    this.onTap,
    this.onOptions,
    this.statusIcon,
  });

  final ClassSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onOptions;

  /// Shown in the corner where the options button would otherwise sit, for
  /// screens that need to say something about the class rather than offer
  /// actions on it — a tick on the register a teacher has already taken.
  final IconData? statusIcon;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = AppColors.classColors(summary.schoolClass.colorSeed);
    final bool archived = summary.schoolClass.archived;

    return Semantics(
      button: true,
      label: '${summary.name}, ${summary.studentCount} students',
      child: Material(
        borderRadius: BorderRadius.circular(AppRadii.xl),
        clipBehavior: Clip.antiAlias,
        child: Ink(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              // An archived class keeps its colour but stops competing with the
              // ones still being taught.
              colors: archived
                  ? <Color>[
                      colors.first.withValues(alpha: 0.45),
                      colors.last.withValues(alpha: 0.45),
                    ]
                  : colors,
            ),
            borderRadius: BorderRadius.circular(AppRadii.xl),
          ),
          child: InkWell(
            onTap: onTap,
            child: Stack(
              children: <Widget>[
                // Two circles bleeding off the top-right corner. Purely
                // decorative, and clipped by the Material above, so they read
                // as depth rather than as content.
                Positioned(
                  top: -46,
                  right: -46,
                  child: _Bubble(size: 132, opacity: 0.13),
                ),
                const Positioned(
                  top: 26,
                  right: -70,
                  child: _Bubble(size: 116, opacity: 0.08),
                ),

                Padding(
                  padding: const EdgeInsets.all(AppSpacing.lg),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Container(
                        width: 46,
                        height: 46,
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.22),
                          borderRadius: BorderRadius.circular(AppRadii.md),
                        ),
                        child: const Icon(
                          Icons.school_rounded,
                          color: Colors.white,
                          size: 24,
                        ),
                      ),

                      const Spacer(),

                      Text(
                        summary.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.titleMedium?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          height: 1.2,
                        ),
                      ),
                      if (summary.schoolClass.subtitle.isNotEmpty) ...<Widget>[
                        const SizedBox(height: 2),
                        Text(
                          summary.schoolClass.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall?.copyWith(
                            color: Colors.white.withValues(alpha: 0.85),
                          ),
                        ),
                      ],
                      const SizedBox(height: AppSpacing.sm),
                      Row(
                        children: <Widget>[
                          _Pill(
                            icon: Icons.group_rounded,
                            label: '${summary.studentCount}',
                          ),
                          if (archived) ...<Widget>[
                            const SizedBox(width: AppSpacing.xs),
                            const Flexible(
                              child: _Pill(
                                icon: Icons.inventory_2_outlined,
                                label: 'Archived',
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),

                if (statusIcon != null)
                  Positioned(
                    top: AppSpacing.md,
                    right: AppSpacing.md,
                    child: Icon(statusIcon, color: Colors.white, size: 24),
                  )
                else if (onOptions != null)
                  Positioned(
                    top: AppSpacing.xs,
                    right: AppSpacing.xs,
                    child: IconButton(
                      tooltip: 'Class options',
                      onPressed: onOptions,
                      icon: const Icon(Icons.more_vert_rounded),
                      color: Colors.white,
                      // The tile is busy at that corner, so the target stays
                      // full size while the glyph sits quietly on the bubble.
                      iconSize: 20,
                      visualDensity: VisualDensity.compact,
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

class _Bubble extends StatelessWidget {
  const _Bubble({required this.size, required this.opacity});

  final double size;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: opacity),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.xxs,
      ),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.24),
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 15, color: Colors.white),
          const SizedBox(width: AppSpacing.xs),
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelMedium?.copyWith(
                color: Colors.white,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
