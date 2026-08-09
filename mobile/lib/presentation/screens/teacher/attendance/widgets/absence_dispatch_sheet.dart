import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../../app/app_dependencies.dart';
import '../../../../../core/extensions/context_extensions.dart';
import '../../../../../core/routing/route_names.dart';
import '../../../../../core/theme/app_spacing.dart';
import '../../../../../core/utils/formatters.dart';
import '../../../../../data/models/models.dart';
import '../../../../../domain/services/absence_notification_service.dart';
import '../../../../widgets/common/app_avatar.dart';
import '../../../../widgets/common/app_badge.dart';
import '../../../../widgets/common/app_card.dart';
import '../../../../widgets/feedback/dialogs.dart';
import '../../../../widgets/layout/app_page.dart';

/// Hands the queued absence notices to WhatsApp, one recipient at a time.
///
/// WhatsApp cannot be driven unattended from the device, so this sheet is the
/// dispatch step: every parent gets a row, tapping **Send** opens WhatsApp with
/// the message already written, and the row is ticked off when it returns.
Future<void> showAbsenceDispatchSheet(
  BuildContext context, {
  required AbsenceDispatchReport report,
  required String className,
}) {
  return showAppSheet<void>(
    context,
    builder: (BuildContext sheetContext) => _AbsenceDispatchSheet(
      report: report,
      className: className,
    ),
  );
}

class _AbsenceDispatchSheet extends StatefulWidget {
  const _AbsenceDispatchSheet({required this.report, required this.className});

  final AbsenceDispatchReport report;
  final String className;

  @override
  State<_AbsenceDispatchSheet> createState() => _AbsenceDispatchSheetState();
}

class _AbsenceDispatchSheetState extends State<_AbsenceDispatchSheet> {
  late final List<OutboundMessage> _messages =
      List<OutboundMessage>.of(widget.report.messages);
  final Set<String> _sending = <String>{};

  int get _sentCount => _messages
      .where((OutboundMessage m) => m.status == MessageStatus.sent)
      .length;

  bool get _allSent => _messages.isNotEmpty && _sentCount == _messages.length;

  /// Index of the next message still to be handed over, so the sheet can
  /// highlight where the teacher is up to.
  int get _nextIndex =>
      _messages.indexWhere((OutboundMessage m) => m.status != MessageStatus.sent);

  Future<void> _send(OutboundMessage message) async {
    if (_sending.contains(message.id)) return;
    setState(() => _sending.add(message.id));

    final AppDependencies deps = context.read<AppDependencies>();
    final OutboundMessage updated =
        await deps.absenceNotifications.retry(message);

    if (!mounted) return;
    setState(() {
      _sending.remove(message.id);
      final int index =
          _messages.indexWhere((OutboundMessage m) => m.id == message.id);
      if (index != -1) _messages[index] = updated;
    });

    if (updated.status == MessageStatus.failed && mounted) {
      context.showError(
        updated.failureReason ?? 'Could not open WhatsApp for this number.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final List<Student> skipped = widget.report.studentsWithoutContact;
    final int pending = _messages.length - _sentCount;

    return AppSheet(
      title: _allSent ? 'All parents notified' : 'Notify parents',
      subtitle: _messages.isEmpty
          ? '${widget.className} — no parent could be reached'
          : '${widget.className} — $pending of ${_messages.length} still to send',
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            if (_messages.isNotEmpty) ...<Widget>[
              _ProgressBar(sent: _sentCount, total: _messages.length),
              const Gap.lg(),
              for (int i = 0; i < _messages.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _RecipientRow(
                    message: _messages[i],
                    isNext: i == _nextIndex,
                    isSending: _sending.contains(_messages[i].id),
                    onSend: () => _send(_messages[i]),
                  ),
                ),
            ],
            if (skipped.isNotEmpty) ...<Widget>[
              const Gap.md(),
              _SkippedCard(students: skipped),
            ],
            const Gap.lg(),
            if (_allSent)
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop(),
                icon: const Icon(Icons.check_rounded),
                label: const Text('Done'),
              )
            else
              Column(
                children: <Widget>[
                  if (_messages.isNotEmpty)
                    Text(
                      'WhatsApp opens with the message ready — tap send there, '
                      'then come back for the next parent.',
                      textAlign: TextAlign.center,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  const Gap.md(),
                  OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: Text(
                      _messages.isEmpty ? 'Close' : 'Finish later',
                    ),
                  ),
                  if (_messages.isNotEmpty) ...<Widget>[
                    const Gap.xs(),
                    Text(
                      'Unsent notices stay in Notifications → Guardian messages.',
                      textAlign: TextAlign.center,
                      style: context.text.labelSmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  ],
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  const _ProgressBar({required this.sent, required this.total});

  final int sent;
  final int total;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: LinearProgressIndicator(
        value: total == 0 ? 0 : sent / total,
        minHeight: 6,
        backgroundColor: context.semantic.subtleBorder,
        valueColor:
            AlwaysStoppedAnimation<Color>(context.semantic.success),
      ),
    );
  }
}

class _RecipientRow extends StatelessWidget {
  const _RecipientRow({
    required this.message,
    required this.isNext,
    required this.isSending,
    required this.onSend,
  });

  final OutboundMessage message;
  final bool isNext;
  final bool isSending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    final bool sent = message.status == MessageStatus.sent;
    final bool failed = message.status == MessageStatus.failed;

    return AppCard(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.md,
        vertical: AppSpacing.sm,
      ),
      color: sent ? context.semantic.successContainer : null,
      borderColor: failed
          ? context.semantic.danger.withValues(alpha: 0.5)
          : isNext
              ? context.colors.primary.withValues(alpha: 0.6)
              : null,
      child: Row(
        children: <Widget>[
          AppAvatar(
            name: message.studentName ?? 'Student',
            seed: message.studentId,
            size: 36,
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Text(
                  message.studentName ?? 'Student',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleSmall,
                ),
                const SizedBox(height: 2),
                Text(
                  '${message.relation.label} · '
                  '${Format.maskedPhone(message.recipientPhone)}',
                  style: context.text.labelSmall
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          if (sent)
            const AppBadge(
              'Sent',
              tone: BadgeTone.success,
              icon: Icons.check_rounded,
              dense: true,
            )
          else
            FilledButton.tonalIcon(
              onPressed: isSending ? null : onSend,
              icon: isSending
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.send_rounded, size: 16),
              label: Text(failed ? 'Retry' : 'Send'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(0, 38),
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              ),
            ),
        ],
      ),
    );
  }
}

class _SkippedCard extends StatelessWidget {
  const _SkippedCard({required this.students});

  final List<Student> students;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      color: context.semantic.warningContainer,
      borderColor: context.semantic.warning.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: context.semantic.warning,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'No usable number for '
                  '${Format.plural(students.length, 'student')}',
                  style: context.text.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: context.semantic.onWarningContainer,
                  ),
                ),
              ),
            ],
          ),
          const Gap.sm(),
          Text(
            students.map((Student s) => s.fullName).join(', '),
            style: context.text.bodySmall
                ?.copyWith(color: context.semantic.onWarningContainer),
          ),
          const Gap.sm(),
          Text(
            'Add a phone number in international format (+92 300 …), or set a '
            'default dialling code in Profile.',
            style: context.text.labelSmall
                ?.copyWith(color: context.semantic.onWarningContainer),
          ),
          const Gap.sm(),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pushNamed(Routes.messagingSettings);
              },
              style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: const Text('Messaging settings'),
            ),
          ),
        ],
      ),
    );
  }
}
