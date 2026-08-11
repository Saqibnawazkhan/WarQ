import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../../domain/entities/dashboard_data.dart';
import '../common/app_badge.dart';
import '../common/app_card.dart';

/// Class row used on the dashboard, the class list and the attendance hub.
///
/// The class colour runs down the left edge as a bar instead of sitting in an
/// avatar: a column of these reads as one list of names all starting at the
/// same margin, while the colour the class was created with still identifies
/// it at a glance.
class ClassCard extends StatelessWidget {
  const ClassCard({
    super.key,
    required this.summary,
    this.onTap,
    this.onMarkAttendance,
    this.onOptions,
    this.trailing,
    this.showAttendanceCta = false,
  });

  final ClassSummary summary;
  final VoidCallback? onTap;
  final VoidCallback? onMarkAttendance;

  /// Per-class actions. Gets a button of its own beside the chevron, because
  /// the row itself opens the class and the actions still need a target.
  /// Ignored when [trailing] is set — that side of the row is the caller's.
  final VoidCallback? onOptions;

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
      // Zero here so the colour bar can reach all four edges of the card; the
      // padding moves onto the content sitting beside it.
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: AppRadii.cardRadius,
        child: Stack(
          children: <Widget>[
            Padding(
              padding: AppSpacing.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(child: _Details(summary: summary)),
                      if (trailing != null) ...<Widget>[
                        const SizedBox(width: AppSpacing.sm),
                        trailing!,
                      ] else ...<Widget>[
                        if (onOptions != null)
                          IconButton(
                            tooltip: 'Class options',
                            onPressed: onOptions,
                            icon: const Icon(Icons.more_vert_rounded),
                            color: context.semantic.mutedText,
                            // Compact so the two glyphs on this edge together
                            // leave the class name most of the row.
                            visualDensity: VisualDensity.compact,
                          )
                        else
                          // The button's own padding is what holds the name off
                          // this edge; without it the bare chevron would sit
                          // against the last letter of a long class name.
                          const SizedBox(width: AppSpacing.sm),
                        if (onTap != null)
                          Icon(
                            Icons.chevron_right_rounded,
                            color: context.semantic.mutedText,
                          ),
                      ],
                    ],
                  ),
                  if (pendingToday) ...<Widget>[
                    const SizedBox(height: AppSpacing.lg),
                    SizedBox(
                      width: double.infinity,
                      // No local height: the shared filled-button style already
                      // sizes for the button text scale, and overriding it here
                      // made the card's primary action shorter than every other
                      // one in the app.
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
            ),
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: _ColourBar(schoolClass: summary.schoolClass),
            ),
          ],
        ),
      ),
    );
  }
}

/// Name, section line and the class's figures — everything left of the chevron.
class _Details extends StatelessWidget {
  const _Details({required this.summary});

  final ClassSummary summary;

  @override
  Widget build(BuildContext context) {
    final String subtitle = summary.schoolClass.subtitle;
    final double? attendance = summary.attendance.percentage;

    // Plain facts rather than chips: at four or five of them a row of pills
    // becomes the loudest thing on the card, and the figures are what a
    // teacher is scanning for.
    final List<String> facts = <String>[
      Format.plural(summary.studentCount, 'student'),
      if (attendance != null)
        '${Format.percent(attendance, decimals: 0)} attendance',
      Format.plural(summary.assessmentCount, 'assessment'),
      if (summary.averagePercentage != null)
        'Avg ${Format.percent(summary.averagePercentage!, decimals: 0)}',
      if (summary.lastSessionDate != null)
        'Last attendance ${AppDate.relativeDay(summary.lastSessionDate!)}',
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        // A Row here made the badge take its width first and left the name a
        // couple of ellipsised characters on a narrow phone. A Wrap gives the
        // name the full column and drops the badge onto its own line only when
        // it has to. The badge stays dense for the same reason: on this line
        // the name has to win.
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
        if (subtitle.isNotEmpty) ...<Widget>[
          const SizedBox(height: AppSpacing.xxs),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
        ],
        const SizedBox(height: AppSpacing.md),
        Wrap(
          spacing: AppSpacing.lg,
          runSpacing: AppSpacing.xs,
          children: <Widget>[
            for (final String fact in facts)
              Text(
                fact,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.labelLarge
                    ?.copyWith(color: context.semantic.mutedText),
              ),
          ],
        ),
      ],
    );
  }
}

/// The class's own colour, as a bar down the left edge of the card.
class _ColourBar extends StatelessWidget {
  const _ColourBar({required this.schoolClass});

  final SchoolClass schoolClass;

  @override
  Widget build(BuildContext context) {
    final List<Color> colors = AppColors.classColors(schoolClass.colorSeed);

    return Container(
      width: AppSpacing.xs,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          // An archived class keeps its colour but stops competing with the
          // ones still being taught.
          colors: schoolClass.archived
              ? <Color>[
                  colors.first.withValues(alpha: 0.4),
                  colors.last.withValues(alpha: 0.4),
                ]
              : colors,
        ),
      ),
    );
  }
}
