import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../domain/entities/dashboard_data.dart';
import '../common/app_avatar.dart';
import '../common/app_badge.dart';
import '../common/app_card.dart';

/// Class row used on the dashboard, the class list and the attendance hub.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onMarkAttendance,
    this.trailing,
    this.showAttendanceCta = false,
  });

  final ClassSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAttendance;
  final Widget? trailing;

  /// Shows a "Mark attendance" button when today's sheet is still missing.
  final bool showAttendanceCta;

  @override
  Widget build(BuildContext context) {
    final bool pendingToday = showAttendanceCta &&
        !summary.markedToday &&
        summary.studentCount > 0 &&
        onMarkAttendance != null;

    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              ClassAvatar(
                name: summary.name,
                seed: summary.schoolClass.avatarKey,
                size: 48,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    // A Row here made the badge take its width first and left
                    // the name a couple of ellipsised characters on a narrow
                    // phone. A Wrap gives the name the full column and drops
                    // the badge onto its own line only when it has to. The
                    // badge stays dense for the same reason: on this line the
                    // name has to win.
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: <Widget>[
                        Text(
                          summary.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        if (summary.schoolClass.archived)
                          const AppBadge('Archived', dense: true),
                      ],
                    ),
                    if (summary.schoolClass.subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: AppSpacing.xxs),
                      Text(
                        summary.schoolClass.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
              if (trailing == null && onTap != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.semantic.mutedText,
                ),
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            // Chips and badges sit on slightly different type scales, so a run
            // of them would otherwise hang off a shared top edge with a ragged
            // bottom one.
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              _Chip(
                icon: Icons.people_alt_rounded,
                label: Format.plural(summary.studentCount, 'student'),
              ),
              _Chip(
                icon: Icons.assignment_outlined,
                label: Format.plural(summary.assessmentCount, 'assessment'),
              ),
              if (summary.attendance.hasData)
                AttendanceBadge(percent: summary.attendance.percentage),
              if (summary.averagePercentage != null)
                AppBadge(
                  'Avg ${Format.percent(summary.averagePercentage!, decimals: 0)}',
                  tone: GradeBadge.toneForPercent(summary.averagePercentage),
                ),
            ],
          ),
          if (summary.lastSessionDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            Text(
              'Last attendance ${AppDate.relativeDay(summary.lastSessionDate!)}',
              style: context.text.bodySmall
                  ?.copyWith(color: context.semantic.mutedText),
            ),
          ],
          if (pendingToday) ...<Widget>[
            const SizedBox(height: AppSpacing.lg),
            SizedBox(
              width: double.infinity,
              // No local height: the shared filled-button style already sizes
              // for the button text scale, and overriding it here made the
              // card's primary action shorter than every other one in the app.
              child: FilledButton.tonalIcon(
                onPressed: onMarkAttendance,
                icon: const Icon(Icons.how_to_reg_rounded, size: 20),
                label: const Text(
                  'Mark today\'s attendance',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 16, color: context.semantic.mutedText),
          const SizedBox(width: AppSpacing.xs),
          // The count is a fact worth scanning, so only the icon stays muted.
          // Flexible because a Wrap hands its width down but will not shrink a
          // child that asks for more.
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.labelLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
