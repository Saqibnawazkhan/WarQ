import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../domain/entities/dashboard_data.dart';
import '../common/app_badge.dart';
import '../common/app_card.dart';

/// Assessment row: a status bar down its edge, the name, what the paper is,
/// and how far the grading has got.
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
    // Green once every student has a mark, indigo while there is work left.
    final Color accent = summary.isFullyGraded
        ? context.semantic.success
        : context.colors.primary;
    // The row itself is the way into mark entry, which is where both callbacks
    // went; the chevron says so, and no separate button has to repeat it.
    final VoidCallback? open = onTap ?? onEnterMarks;

    return AppCard(
      onTap: open,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: Container(
          decoration: BoxDecoration(
            border: Border(left: BorderSide(color: accent, width: 4)),
          ),
          // The bar eats into the left inset, so that side is short by its
          // width and the text still starts where every other card's does.
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.lg,
            AppSpacing.lg,
            AppSpacing.lg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
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
                          // On a mixed list this line carries the class and the
                          // due date, so it wraps once rather than losing its
                          // tail.
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.bodySmall
                              ?.copyWith(color: context.semantic.mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (trailing != null)
                    trailing!
                  else if (open != null)
                    Icon(
                      Icons.chevron_right_rounded,
                      color: context.semantic.mutedText,
                    ),
                ],
              ),
              const SizedBox(height: AppSpacing.lg),
              ClipRRect(
                borderRadius: BorderRadius.circular(AppRadii.pill),
                child: LinearProgressIndicator(
                  value: summary.progress,
                  minHeight: 6,
                  backgroundColor: context.semantic.subtleBorder,
                  valueColor: AlwaysStoppedAnimation<Color>(accent),
                ),
              ),
              const SizedBox(height: AppSpacing.md),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '${summary.gradedCount} of ${summary.studentCount} graded',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.labelMedium
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  if (summary.averagePercentage != null)
                    AppBadge(
                      'Avg ${Format.percent(summary.averagePercentage!, decimals: 0)}',
                      tone: GradeBadge.toneForPercent(summary.averagePercentage),
                      dense: true,
                    )
                  else
                    const AppBadge('Not graded yet', dense: true),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The glyph for a type. The row draws a colour bar instead of an icon, but
  /// the assessment form still picks a type with these.
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
