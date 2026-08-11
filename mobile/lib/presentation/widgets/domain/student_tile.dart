import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../domain/entities/student_performance.dart';
import '../common/app_avatar.dart';
import '../common/app_badge.dart';
import '../common/app_card.dart';

/// Width of the status bar down the left edge of a roster row.
const double _accentBarWidth = 4;

/// Ceiling for the figures at the end of a roster row.
///
/// The name is what a teacher scans for, so it has to win the row. A grade
/// scale is configurable and could carry a long band label; bounding the
/// column makes that label ellipsize inside it instead of pushing the name
/// out of the card.
const double _statsMaxWidth = 96;

/// Roster row: initials, name and roll number, then attendance and grade.
class StudentTile extends StatelessWidget {
  const StudentTile({
    super.key,
    required this.performance,
    this.onTap,
    this.onLongPress,
    this.trailing,
    this.showRisk = true,
  });

  final StudentPerformance performance;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final Widget? trailing;
  final bool showRisk;

  Student get student => performance.student;

  @override
  Widget build(BuildContext context) {
    final bool atRisk = showRisk && performance.isAtRisk;

    return AppCard(
      onTap: onTap,
      onLongPress: onLongPress,
      // The bar has to reach the card's own edge, so the row carries the
      // padding instead of the card.
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: AppSpacing.tilePadding,
          decoration: BoxDecoration(
            border: Border(
              left: BorderSide(
                // Colour carries the standing: amber for a student who needs
                // attention, the brand indigo for everyone else.
                color: atRisk
                    ? context.semantic.warning
                    : context.colors.primary,
                width: _accentBarWidth,
              ),
            ),
          ),
          child: Row(
            children: <Widget>[
              AppAvatar(name: student.fullName, seed: student.id, size: 44),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(
                      student.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.xxs),
                    Text(
                      student.rollNumber ?? 'No roll number',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: context.semantic.mutedText,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              trailing ?? StudentTileStats(performance: performance),
            ],
          ),
        ),
      ),
    );
  }
}

/// The figures at the end of a roster row: attendance over the grade.
///
/// Lives here rather than in the roster screen so a student reads the same
/// wherever the tile is used, including where the screen supplies its own
/// [StudentTile.trailing].
class StudentTileStats extends StatelessWidget {
  const StudentTileStats({super.key, required this.performance});

  final StudentPerformance performance;

  @override
  Widget build(BuildContext context) {
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: _statsMaxWidth),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Text(
            Format.percentOrDash(
              performance.attendance.percentage,
              decimals: 0,
            ),
            maxLines: 1,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: performance.hasLowAttendance
                  ? context.semantic.warning
                  : null,
            ),
          ),
          const SizedBox(height: AppSpacing.xs),
          GradeBadge(
            grade: performance.grade?.label,
            percent: performance.percentage,
            dense: true,
          ),
        ],
      ),
    );
  }
}

/// Simpler row for pickers and search results, where no performance data is
/// loaded.
class StudentPickerTile extends StatelessWidget {
  const StudentPickerTile({
    super.key,
    required this.student,
    this.subtitle,
    this.onTap,
    this.selected = false,
    this.trailing,
  });

  final Student student;
  final String? subtitle;
  final VoidCallback? onTap;
  final bool selected;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: AppSpacing.sm,
      ),
      leading: AppAvatar(name: student.fullName, seed: student.id, size: 44),
      // Matches the roster tile so a name reads the same wherever it appears.
      title: Text(
        student.fullName,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.titleMedium?.copyWith(
          fontWeight: FontWeight.w700,
        ),
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: AppSpacing.xxs),
        child: Text(
          subtitle ?? student.rollNumber ?? 'No roll number',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            color: context.semantic.mutedText,
          ),
        ),
      ),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  selected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  color: selected
                      ? context.colors.primary
                      : context.semantic.subtleBorder,
                )),
    );
  }
}

/// Alphabetical section header for the A–Z roster.
class AlphabetHeader extends StatelessWidget {
  const AlphabetHeader({super.key, required this.letter, this.count});

  final String letter;
  final int? count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.xs,
        AppSpacing.xl,
        AppSpacing.xs,
        AppSpacing.md,
      ),
      child: Row(
        children: <Widget>[
          Text(
            letter,
            style: context.text.titleSmall?.copyWith(
              color: context.colors.primary,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: Divider(color: context.semantic.subtleBorder)),
          if (count != null) ...<Widget>[
            const SizedBox(width: AppSpacing.md),
            Text(
              '$count',
              style: context.text.bodySmall?.copyWith(
                color: context.semantic.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
