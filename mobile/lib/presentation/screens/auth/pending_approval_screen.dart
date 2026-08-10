import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../data/models/models.dart';
import '../../state/session_controller.dart';

/// Shown to a signed-in account that is not allowed to work yet.
///
/// Three different situations land here and they need different words. An
/// account waiting to be approved has done nothing wrong and just needs to
/// wait; one that was turned down or switched off needs to know who to talk to;
/// a teacher whose organization stopped paying is in good standing themselves
/// and should be told it is not about them.
///
/// The alternative is what the app did before this screen existed: drop them on
/// a dashboard where every panel fails with "your subscription is not active",
/// which reads like a broken app rather than a decision somebody made.
class PendingApprovalScreen extends StatelessWidget {
  const PendingApprovalScreen({super.key, required this.user});

  final AppUser user;

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    final _Explanation explanation = _explain(user);

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.xl),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  Container(
                    width: 68,
                    height: 68,
                    decoration: BoxDecoration(
                      color: explanation.tint(context),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      explanation.icon,
                      size: 32,
                      color: explanation.accent(context),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Text(
                    explanation.title,
                    textAlign: TextAlign.center,
                    style: context.text.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  Text(
                    explanation.body,
                    textAlign: TextAlign.center,
                    style: context.text.bodyMedium
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  Container(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    decoration: BoxDecoration(
                      color: context.colors.surfaceContainerHigh,
                      borderRadius: AppRadii.cardRadius,
                    ),
                    child: Column(
                      children: <Widget>[
                        Text(
                          user.displayName,
                          style: context.text.titleSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: context.text.bodySmall
                              ?.copyWith(color: context.semantic.mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: AppSpacing.xl),
                  // Checking again is the whole point: approval happens
                  // elsewhere and nothing pushes it to the phone, so the only
                  // thing to offer is a way to ask the server once more.
                  FilledButton.icon(
                    onPressed: session.isBusy
                        ? null
                        : () => session.load(refreshing: true),
                    icon: session.isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.refresh_rounded),
                    label: Text(session.isBusy ? 'Checking…' : 'Check again'),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  TextButton(
                    onPressed: () => context.read<SessionController>().signOut(),
                    child: const Text('Sign out'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  _Explanation _explain(AppUser user) {
    switch (user.status) {
      case AccountStatus.pending:
        return const _Explanation(
          icon: Icons.hourglass_top_rounded,
          tone: _Tone.waiting,
          title: 'Waiting for approval',
          body: 'Your account has been created and is with the Warq team for '
              'review. You will be able to sign in and start creating classes '
              'as soon as it is approved.',
        );
      case AccountStatus.removed:
        return const _Explanation(
          icon: Icons.block_rounded,
          tone: _Tone.stopped,
          title: 'Account not approved',
          body: 'This account was not approved for Warq. If you think that is '
              'a mistake, reply to your sign-up email and someone will take '
              'another look.',
        );
      case AccountStatus.suspended:
        return const _Explanation(
          icon: Icons.pause_circle_outline_rounded,
          tone: _Tone.stopped,
          title: 'Account paused',
          body: 'This account has been switched off. Your classes, registers '
              'and marks are all safe and come back exactly as they were once '
              'it is switched on again.',
        );
      case AccountStatus.active:
        // In good standing, but still gated: the subscription covering them has
        // lapsed or been suspended. Whose subscription it is changes who they
        // need to speak to.
        return user.belongsToOrganization
            ? const _Explanation(
                icon: Icons.apartment_rounded,
                tone: _Tone.stopped,
                title: 'Your organization’s subscription has stopped',
                body: 'Nothing is wrong with your account. Your organization '
                    'administrator can restore access, and everything you have '
                    'recorded is waiting for you.',
              )
            : const _Explanation(
                icon: Icons.card_membership_outlined,
                tone: _Tone.stopped,
                title: 'Your subscription has ended',
                body: 'Renew to pick up exactly where you left off. Your '
                    'classes, registers and marks are all still here.',
              );
    }
  }
}

enum _Tone { waiting, stopped }

class _Explanation {
  const _Explanation({
    required this.icon,
    required this.tone,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final _Tone tone;
  final String title;
  final String body;

  Color accent(BuildContext context) => switch (tone) {
        _Tone.waiting => context.colors.primary,
        _Tone.stopped => context.colors.error,
      };

  Color tint(BuildContext context) => accent(context).withValues(alpha: 0.10);
}
