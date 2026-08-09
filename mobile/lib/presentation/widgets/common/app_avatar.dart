import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/formatters.dart';

/// Initials avatar with a colour derived from the name, so the same person
/// always gets the same tint.
class AppAvatar extends StatelessWidget {
  const AppAvatar({
    super.key,
    required this.name,
    this.size = 40,
    this.seed,
    this.icon,
    this.badge,
  });

  const AppAvatar.small({super.key, required this.name, this.seed})
      : size = 32,
        icon = null,
        badge = null;

  const AppAvatar.large({super.key, required this.name, this.seed})
      : size = 64,
        icon = null,
        badge = null;

  final String name;
  final double size;

  /// Overrides the colour seed when the display name may change.
  final String? seed;
  final IconData? icon;

  /// Small overlay in the bottom-right corner (e.g. a status dot).
  final Widget? badge;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.avatarColor(seed ?? name);
    final Widget circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: icon != null
          ? Icon(icon, size: size * 0.48, color: color)
          : Text(
              Format.initials(name),
              style: TextStyle(
                color: color,
                fontSize: size * 0.36,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
    );

    if (badge == null) return circle;
    return Stack(
      clipBehavior: Clip.none,
      children: <Widget>[
        circle,
        Positioned(right: -2, bottom: -2, child: badge!),
      ],
    );
  }
}

/// Square avatar used for classes, which read better than circles in lists.
class ClassAvatar extends StatelessWidget {
  const ClassAvatar({
    super.key,
    required this.name,
    this.seed,
    this.size = 44,
  });

  final String name;
  final String? seed;
  final double size;

  @override
  Widget build(BuildContext context) {
    final Color color = AppColors.avatarColor(seed ?? name);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(size * 0.28),
        border: Border.all(color: color.withValues(alpha: 0.24)),
      ),
      child: Text(
        Format.initials(name),
        style: TextStyle(
          color: color,
          fontSize: size * 0.34,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}
