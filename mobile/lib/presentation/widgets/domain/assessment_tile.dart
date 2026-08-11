import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../domain/entities/dashboard_data.dart';
import '../common/app_badge.dart';
import '../common/app_card.dart';

/// Assessment row with grading progress.
class AssessmentTile extends StatelessWidget {
  const AssessmentTile({
    super.key,
    required this.summary,
    this.onTap,
    this.onEnterMarks,
    this.showClassName = false,
    this.trailing,
  });

  final AssessmentSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onEnterMarks;
  final bool showClassName;
  final Widget? trailing;

  Assessment get assessment => summary.assessment;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: context.colors.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(AppRadii.md),
                ),
                child: Icon(
                  iconFor(assessment.type),
                  size: 24,
                  color: context.colors.primary,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      assessment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      <String>[
                        assessment.typeLabel,
                        if (showClassName) summary.className,
                        AppDate.formatShort(assessment.date),
                        '${Format.marks(assessment.totalMarks)} marks',
                      ].join(' · '),
                      // On a mixed list this line carries the class and the due
                      // date, so it wraps once rather than losing its tail.
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  ],
                ),
              ),
              if (trailing != null) ...<Widget>[
                const SizedBox(width: AppSpacing.sm),
                trailing!,
              ],
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: <Widget>[
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(AppRadii.xs),
                  child: LinearProgressIndicator(
                    value: summary.progress,
                    minHeight: 8,
                    backgroundColor: context.semantic.subtleBorder,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      summary.isFullyGraded
                          ? context.semantic.success
                          : context.colors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                '${summary.gradedCount}/${summary.studentCount}',
                style: context.text.labelLarge
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          // Badge and action share a line at normal type; wrapping lets the
          // action drop underneath instead of overflowing once text is scaled.
          SizedBox(
            width: double.infinity,
            child: Wrap(
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: <Widget>[
                if (summary.averagePercentage != null)
                  AppBadge(
                    'Avg ${Format.percent(summary.averagePercentage!, decimals: 0)}',
                    tone: GradeBadge.toneForPercent(summary.averagePercentage),
                  )
                else
                  const AppBadge('Not graded yet'),
                if (onEnterMarks != null)
                  TextButton.icon(
                    onPressed: onEnterMarks,
                    icon: Icon(
                      summary.gradedCount == 0
                          ? Icons.edit_note_rounded
                          : Icons.checklist_rounded,
                      size: 20,
                    ),
                    label: Text(
                      summary.gradedCount == 0 ? 'Add marks' : 'Edit marks',
                    ),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: AppSpacing.sm,
                      ),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static IconData iconFor(AssessmentType type) => switch (type) {
        AssessmentType.quiz => Icons.quiz_outlined,
        AssessmentType.assignment => Icons.assignment_outlined,
        AssessmentType.midterm => Icons.menu_book_outlined,
        AssessmentType.finalExam => Icons.school_outlined,
        AssessmentType.presentation => Icons.co_present_outlined,
        AssessmentType.project => Icons.science_outlined,
        AssessmentType.lab => Icons.biotech_outlined,
        AssessmentType.custom => Icons.star_outline_rounded,
      };
}
