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
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              ClassAvatar(
                name: summary.name,
                seed: summary.schoolClass.avatarKey,
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(
                      children: <Widget>[
                        Flexible(
                          child: Text(
                            summary.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700),
                          ),
                        ),
                        if (summary.schoolClass.archived) ...<Widget>[
                          const SizedBox(width: AppSpacing.sm),
                          const AppBadge('Archived', dense: true),
                        ],
                      ],
                    ),
                    if (summary.schoolClass.subtitle.isNotEmpty) ...<Widget>[
                      const SizedBox(height: 2),
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
              if (trailing != null) trailing!,
              if (trailing == null && onTap != null)
                Icon(
                  Icons.chevron_right_rounded,
                  color: context.semantic.mutedText,
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
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
                AttendanceBadge(
                  percent: summary.attendance.percentage,
                  dense: true,
                ),
              if (summary.averagePercentage != null)
                AppBadge(
                  'Avg ${Format.percent(summary.averagePercentage!, decimals: 0)}',
                  tone: GradeBadge.toneForPercent(summary.averagePercentage),
                  dense: true,
                ),
            ],
          ),
          if (summary.lastSessionDate != null) ...<Widget>[
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Last attendance ${AppDate.relativeDay(summary.lastSessionDate!)}',
              style: context.text.labelSmall
                  ?.copyWith(color: context.semantic.mutedText),
            ),
          ],
          if (pendingToday) ...<Widget>[
            const SizedBox(height: AppSpacing.md),
            SizedBox(
              width: double.infinity,
              child: FilledButton.tonalIcon(
                onPressed: onMarkAttendance,
                icon: const Icon(Icons.how_to_reg_rounded, size: 18),
                label: const Text('Mark today\'s attendance'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(42),
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
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md, vertical: 4),
      decoration: BoxDecoration(
        color: context.colors.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(icon, size: 13, color: context.semantic.mutedText),
          const SizedBox(width: 4),
          Text(
            label,
            style: context.text.labelMedium
                ?.copyWith(color: context.semantic.mutedText),
          ),
        ],
      ),
    );
  }
}
