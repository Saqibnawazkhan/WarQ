import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../domain/entities/student_performance.dart';
import '../common/app_avatar.dart';
import '../common/app_badge.dart';
import '../common/app_card.dart';

/// Roster row showing the fields the spec asks for: name, student number,
/// attendance percentage, overall percentage and grade.
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
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.lg,
        vertical: AppSpacing.md,
      ),
      borderColor: atRisk
          ? context.semantic.warning.withValues(alpha: 0.5)
          : null,
      child: Row(
        children: <Widget>[
          AppAvatar(name: student.fullName, seed: student.id, size: 42),
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
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 3),
                Row(
                  children: <Widget>[
                    if (student.rollNumber != null) ...<Widget>[
                      Text(
                        student.rollNumber!,
                        style: context.text.bodySmall?.copyWith(
                          color: context.semantic.mutedText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        '·',
                        style: context.text.bodySmall?.copyWith(
                          color: context.semantic.mutedText,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                    ],
                    Flexible(
                      child: Text(
                        performance.attendance.hasData
                            ? '${Format.percentOrDash(performance.attendance.percentage, decimals: 0)} attendance'
                            : 'No attendance yet',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall?.copyWith(
                          color: performance.hasLowAttendance
                              ? context.semantic.warning
                              : context.semantic.mutedText,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (trailing != null)
            trailing!
          else
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  Format.percentOrDash(performance.percentage, decimals: 0),
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                GradeBadge(
                  grade: performance.grade?.label,
                  percent: performance.percentage,
                  dense: true,
                ),
              ],
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
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
      leading: AppAvatar(name: student.fullName, seed: student.id, size: 40),
      title: Text(student.fullName, style: context.text.titleSmall),
      subtitle: Text(
        subtitle ?? student.rollNumber ?? 'No roll number',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(
          color: context.semantic.mutedText,
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
        AppSpacing.lg,
        AppSpacing.xs,
        AppSpacing.sm,
      ),
      child: Row(
        children: <Widget>[
          Text(
            letter,
            style: context.text.labelLarge?.copyWith(
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
              style: context.text.labelSmall?.copyWith(
                color: context.semantic.mutedText,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
