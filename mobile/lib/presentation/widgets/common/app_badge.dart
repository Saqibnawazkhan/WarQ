import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';

/// Semantic tone applied to pills and chips.
enum BadgeTone { neutral, brand, success, warning, danger, info }

/// Rounded label used for grades, statuses and counts.
class AppBadge extends StatelessWidget {
  const AppBadge(
    this.label, {
    super.key,
    this.tone = BadgeTone.neutral,
    this.icon,
    this.dense = false,
  });

  final String label;
  final BadgeTone tone;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final (Color background, Color foreground) = _colors(context, tone);

    // A badge carries a status or a grade, not decoration — it has to be
    // readable at arm's length. So both sizes use the same label and `dense`
    // only tightens the padding around it.
    final TextStyle? labelStyle = context.text.labelLarge
        ?.copyWith(color: foreground, fontWeight: FontWeight.w700);
    final double? labelSize = labelStyle?.fontSize;

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? AppSpacing.md : AppSpacing.lg,
        vertical: dense ? AppSpacing.xs : AppSpacing.sm,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(AppRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          if (icon != null) ...<Widget>[
            // Measured off the label rather than carrying a size of its own,
            // and scaled alongside it, so the glyph and the word beside it
            // cannot drift apart when either scale moves.
            Icon(
              icon,
              size: labelSize == null ? null : labelSize + 2,
              applyTextScaling: true,
              color: foreground,
            ),
            const SizedBox(width: AppSpacing.xs),
          ],
          // A badge sits inline beside a class or student name and takes its
          // width first, so where the row is tight it has to give way rather
          // than overflow. Flexible resolves here because the badge is always
          // laid out inside something that bounds it.
          Flexible(
            child: Text(
              label,
              style: labelStyle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  static (Color, Color) _colors(BuildContext context, BadgeTone tone) {
    final AppSemanticColors semantic = context.semantic;
    return switch (tone) {
      BadgeTone.neutral => (
          context.colors.surfaceContainerHighest,
          semantic.mutedText,
        ),
      BadgeTone.brand => (
          context.colors.primary.withValues(alpha: 0.12),
          context.colors.primary,
        ),
      BadgeTone.success => (semantic.successContainer, semantic.onSuccessContainer),
      BadgeTone.warning => (semantic.warningContainer, semantic.onWarningContainer),
      BadgeTone.danger => (semantic.dangerContainer, semantic.onDangerContainer),
      BadgeTone.info => (semantic.infoContainer, semantic.onInfoContainer),
    };
  }
}

/// Grade pill whose colour tracks the percentage.
class GradeBadge extends StatelessWidget {
  const GradeBadge({
    super.key,
    required this.grade,
    this.percent,
    this.dense = false,
  });

  final String? grade;
  final double? percent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      grade ?? '—',
      tone: toneForPercent(percent),
      dense: dense,
    );
  }

  /// Shared colour rule so grades, charts and progress bars agree.
  static BadgeTone toneForPercent(double? percent) {
    if (percent == null) return BadgeTone.neutral;
    if (percent >= 80) return BadgeTone.success;
    if (percent >= 60) return BadgeTone.brand;
    if (percent >= AppConstants.performanceRiskThreshold) return BadgeTone.warning;
    return BadgeTone.danger;
  }
}

/// Percentage pill used for attendance figures.
class AttendanceBadge extends StatelessWidget {
  const AttendanceBadge({super.key, required this.percent, this.dense = false});

  final double? percent;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final BadgeTone tone = percent == null
        ? BadgeTone.neutral
        : percent! >= 90
            ? BadgeTone.success
            : percent! >= AppConstants.attendanceRiskThreshold
                ? BadgeTone.brand
                : percent! >= 50
                    ? BadgeTone.warning
                    : BadgeTone.danger;
    return AppBadge(
      Format.percentOrDash(percent, decimals: 0),
      tone: tone,
      icon: dense ? null : Icons.event_available_rounded,
      dense: dense,
    );
  }
}

/// Coloured chip for a single attendance status.
class AttendanceStatusChip extends StatelessWidget {
  const AttendanceStatusChip(this.status, {super.key, this.dense = false});

  final AttendanceStatus status;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return AppBadge(
      status.label,
      tone: toneFor(status),
      icon: iconFor(status),
      dense: dense,
    );
  }

  static BadgeTone toneFor(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => BadgeTone.success,
        AttendanceStatus.absent => BadgeTone.danger,
        AttendanceStatus.late => BadgeTone.warning,
        AttendanceStatus.shortLeave => BadgeTone.info,
      };

  static IconData iconFor(AttendanceStatus status) => switch (status) {
        AttendanceStatus.present => Icons.check_circle_rounded,
        AttendanceStatus.absent => Icons.cancel_rounded,
        AttendanceStatus.late => Icons.schedule_rounded,
        AttendanceStatus.shortLeave => Icons.verified_user_rounded,
      };

  static Color colorFor(BuildContext context, AttendanceStatus status) =>
      switch (status) {
        AttendanceStatus.present => context.semantic.success,
        AttendanceStatus.absent => context.semantic.danger,
        AttendanceStatus.late => context.semantic.warning,
        AttendanceStatus.shortLeave => context.semantic.info,
      };
}
