import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../state/grade_scale_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/common/app_badge.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/feedback/dialogs.dart';
import '../../widgets/feedback/state_views.dart';
import '../../widgets/layout/app_page.dart';

/// View — and, for organization admins, edit — the grading scale.
///
/// Individual teachers see the platform default read-only; the model already
/// supports per-organization scales so the Phase 2 web dashboard can expose the
/// same editor.
class GradeScaleScreen extends StatelessWidget {
  const GradeScaleScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final AppUser user = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<GradeScaleController>(
      create: (BuildContext context) =>
          GradeScaleController(context.read<AppDependencies>(), user)..load(),
      child: const _GradeScaleView(),
    );
  }
}

class _GradeScaleView extends StatelessWidget {
  const _GradeScaleView();

  Future<void> _editBand(
    BuildContext context,
    GradeScaleController controller,
    int index,
  ) async {
    final GradeBand band = controller.draftBands[index];
    final TextEditingController label = TextEditingController(text: band.label);
    final TextEditingController threshold =
        TextEditingController(text: Format.marks(band.minPercent));
    final TextEditingController remark =
        TextEditingController(text: band.remark ?? '');

    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Edit grade band',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            TextField(
              controller: label,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Grade label'),
            ),
            const Gap.lg(),
            TextField(
              controller: threshold,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(
                labelText: 'Minimum percentage',
                suffixText: '%',
              ),
            ),
            const Gap.lg(),
            TextField(
              controller: remark,
              decoration: const InputDecoration(
                labelText: 'Remark',
                hintText: 'e.g. Excellent',
              ),
            ),
            const Gap.xl(),
            FilledButton(
              onPressed: () {
                controller.updateBand(
                  index,
                  label: label.text.trim().isEmpty ? null : label.text.trim(),
                  minPercent: double.tryParse(threshold.text.trim()),
                  remark: remark.text.trim().isEmpty ? null : remark.text.trim(),
                );
                Navigator.of(sheetContext).pop();
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );

    label.dispose();
    threshold.dispose();
    remark.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final GradeScaleController controller = context.watch<GradeScaleController>();
    final GradeScale? scale = controller.scale;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Grading scale'),
        actions: <Widget>[
          if (controller.canEdit && controller.hasChanges)
            TextButton(
              onPressed: controller.discardChanges,
              child: const Text('Discard'),
            ),
        ],
      ),
      bottomNavigationBar: controller.canEdit && controller.hasChanges
          ? SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(AppSpacing.lg),
                child: FilledButton.icon(
                  onPressed: controller.isBusy
                      ? null
                      : () async {
                          final bool ok = await controller.save();
                          if (!context.mounted) return;
                          if (ok) {
                            context.showSuccess('Grading scale updated.');
                          } else {
                            context.showError(
                              controller.errorMessage ??
                                  'Could not save the grading scale.',
                            );
                          }
                        },
                  icon: const Icon(Icons.check_rounded),
                  label: const Text('Save grading scale'),
                ),
              ),
            )
          : null,
      body: ControllerStateView(
        controller: controller,
        builder: (BuildContext context) {
          if (scale == null) {
            return const ErrorView(message: 'No grading scale is configured.');
          }
          return AppPageBody(
            onRefresh: controller.refresh,
            children: <Widget>[
              AppCard(
                color: context.colors.surfaceContainerHigh,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Icon(
                      controller.canEdit
                          ? Icons.tune_rounded
                          : Icons.lock_outline_rounded,
                      size: 18,
                      color: context.semantic.mutedText,
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Text(
                        controller.canEdit
                            ? 'Changes apply to every class in your organization. '
                                'Grades already displayed are recalculated instantly.'
                            : 'Your classes are graded with this scale. An '
                                'organization admin can customise it.',
                        style: context.text.bodySmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    ),
                  ],
                ),
              ),
              const Gap.xl(),
              SectionCard(
                title: 'Grade bands',
                subtitle: controller.canEdit
                    ? 'Tap a band to edit its label or threshold'
                    : '${controller.draftBands.length} bands',
                actionLabel: controller.canEdit ? 'Add band' : null,
                onAction: controller.canEdit ? controller.addBand : null,
                child: Column(
                  children: <Widget>[
                    for (int i = 0; i < controller.draftBands.length; i++)
                      _BandRow(
                        band: controller.draftBands[i],
                        range: scale.rangeFor(controller.draftBands[i]),
                        editable: controller.canEdit,
                        canDelete: controller.canEdit &&
                            controller.draftBands.length > 2,
                        onTap: controller.canEdit
                            ? () => _editBand(context, controller, i)
                            : null,
                        onDelete: () => controller.removeBand(i),
                      ),
                  ],
                ),
              ),
              const Gap.xl(),
              SectionCard(
                title: 'Pass mark',
                subtitle:
                    'Students below this percentage are flagged as needing '
                    'attention',
                child: Row(
                  children: <Widget>[
                    Expanded(
                      child: Slider(
                        value: controller.draftPassPercent,
                        min: 0,
                        max: 100,
                        divisions: 20,
                        label:
                            '${controller.draftPassPercent.toStringAsFixed(0)}%',
                        onChanged: controller.canEdit
                            ? controller.setPassPercent
                            : null,
                      ),
                    ),
                    SizedBox(
                      width: 54,
                      child: Text(
                        '${controller.draftPassPercent.toStringAsFixed(0)}%',
                        textAlign: TextAlign.end,
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                    ),
                  ],
                ),
              ),
              if (controller.canEdit && controller.isCustom) ...<Widget>[
                const Gap.xl(),
                OutlinedButton.icon(
                  onPressed: () async {
                    final bool confirmed = await showConfirmDialog(
                      context,
                      title: 'Reset to the standard scale?',
                      message:
                          'Your custom bands are removed and the default '
                          'A+/A/B/C/D/F scale is restored.',
                      confirmLabel: 'Reset',
                      isDestructive: true,
                      icon: Icons.restart_alt_rounded,
                    );
                    if (!confirmed || !context.mounted) return;
                    final bool ok = await controller.resetToDefault();
                    if (!context.mounted) return;
                    if (ok) context.showSuccess('Standard scale restored.');
                  },
                  icon: const Icon(Icons.restart_alt_rounded, size: 20),
                  label: const Text('Reset to standard scale'),
                ),
              ],
              const Gap.xxl(),
            ],
          );
        },
      ),
    );
  }
}

class _BandRow extends StatelessWidget {
  const _BandRow({
    required this.band,
    required this.range,
    required this.editable,
    required this.canDelete,
    required this.onDelete,
    this.onTap,
  });

  final GradeBand band;
  final ({double min, double? max}) range;
  final bool editable;
  final bool canDelete;
  final VoidCallback onDelete;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final String upper =
        range.max == null ? '100' : Format.marks(range.max! - 0.1);

    return ListTile(
      contentPadding: EdgeInsets.zero,
      onTap: onTap,
      leading: AppBadge(
        band.label,
        tone: GradeBadge.toneForPercent(band.minPercent),
      ),
      title: Text(
        '${Format.marks(band.minPercent)}% – $upper%',
        style: context.text.titleSmall,
      ),
      subtitle: band.remark == null
          ? null
          : Text(
              band.remark!,
              style: context.text.bodySmall
                  ?.copyWith(color: context.semantic.mutedText),
            ),
      trailing: editable
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                if (canDelete)
                  IconButton(
                    tooltip: 'Remove band',
                    onPressed: onDelete,
                    icon: Icon(
                      Icons.remove_circle_outline_rounded,
                      size: 20,
                      color: context.semantic.mutedText,
                    ),
                  ),
                const Icon(Icons.chevron_right_rounded),
              ],
            )
          : null,
    );
  }
}
