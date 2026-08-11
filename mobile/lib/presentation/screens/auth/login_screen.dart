import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../state/session_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Email/username + password sign-in.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _identifier = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final FocusNode _passwordFocus = FocusNode();
  bool _obscure = true;

  /// The default text-button padding insets the label by 12 on each side, which
  /// both pushes the two links past the width of a 360dp phone and leaves them
  /// visibly out of line with the fields above.
  static final ButtonStyle _linkStyle = TextButton.styleFrom(
    padding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
  );

  @override
  void dispose() {
    _identifier.dispose();
    _password.dispose();
    _passwordFocus.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final SessionController session = context.read<SessionController>();
    final bool ok = await session.signIn(
      identifier: _identifier.text,
      password: _password.text,
    );
    if (!mounted) return;
    // Only greet someone who is actually getting in. An account still waiting
    // for approval lands on a screen explaining the wait, and "Welcome back"
    // over the top of it reads as though something went right.
    if (ok && (session.user?.hasAccess ?? false)) {
      context.showSuccess('Welcome back, ${session.user?.displayName ?? ''}.');
    }
  }

  void _useDemoAccount(String email) {
    _identifier.text = email;
    _password.text = DemoAccounts.password;
    context.read<SessionController>().clearError();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();

    // Only an offline build has the seeded accounts. Offering them against the
    // shared database would hand every new teacher a password that cannot work.
    final bool offersDemoAccounts =
        context.read<AppDependencies>().backend == AppBackend.local;

    return AuthScaffold(
      title: 'Your classroom,\nmanaged in minutes.',
      subtitle:
          'Attendance, marks, grades and reports for teachers and institutions.',
      footer:
          offersDemoAccounts ? _DemoAccountsCard(onSelect: _useDemoAccount) : null,
      children: <Widget>[
        if (session.errorMessage != null)
          AuthErrorBanner(message: session.errorMessage!),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _identifier,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autofillHints: const <String>[AutofillHints.username],
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email or username',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: Validators.emailOrUsername,
                onFieldSubmitted: (_) => _passwordFocus.requestFocus(),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _password,
                focusNode: _passwordFocus,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                autofillHints: const <String>[AutofillHints.password],
                decoration: InputDecoration(
                  labelText: 'Password',
                  prefixIcon: const Icon(Icons.lock_outline_rounded),
                  suffixIcon: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(
                      _obscure
                          ? Icons.visibility_outlined
                          : Icons.visibility_off_outlined,
                    ),
                    tooltip: _obscure ? 'Show password' : 'Hide password',
                  ),
                ),
                validator: (String? value) =>
                    (value == null || value.isEmpty) ? 'Password is required.' : null,
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: session.isBusy ? null : _submit,
                child: session.isBusy
                    ? SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: context.colors.onPrimary,
                        ),
                      )
                    : const Text('Sign in'),
              ),
              const SizedBox(height: AppSpacing.md),
              // Wrap rather than Row: the two links sit on one line at the
              // usual text size, and drop onto separate lines instead of
              // overflowing on a narrow screen or at a large text scale.
              Wrap(
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.xs,
                children: <Widget>[
                  TextButton(
                    style: _linkStyle,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Routes.forgotPassword),
                    child: const Text('Forgot password?'),
                  ),
                  TextButton(
                    style: _linkStyle,
                    onPressed: () =>
                        Navigator.of(context).pushNamed(Routes.register),
                    child: const Text('Create an account'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Phase 1 ships with seeded accounts; surfacing them removes the guesswork of
/// signing in to a local-only build.
class _DemoAccountsCard extends StatelessWidget {
  const _DemoAccountsCard({required this.onSelect});

  final void Function(String email) onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: AppSpacing.cardPadding,
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: AppRadii.cardRadius,
        // The card lifts off the tinted page on its own surface, so it needs a
        // shadow rather than an outline to read as a card.
        boxShadow: <BoxShadow>[
          BoxShadow(
            color: context.colors.shadow.withValues(alpha: 0.06),
            blurRadius: 18,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.science_outlined,
                size: 16,
                color: context.semantic.mutedText,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Demo accounts',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.labelLarge
                      ?.copyWith(color: context.semantic.mutedText),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Password for all demo accounts: ${DemoAccounts.password}',
            style: context.text.bodySmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: <Widget>[
              _DemoChip(
                label: 'Teacher',
                email: DemoAccounts.teacherEmail,
                onSelect: onSelect,
              ),
              _DemoChip(
                label: 'Org admin',
                email: DemoAccounts.orgAdminEmail,
                onSelect: onSelect,
              ),
              _DemoChip(
                label: 'Org teacher',
                email: DemoAccounts.orgTeacherEmail,
                onSelect: onSelect,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoChip extends StatelessWidget {
  const _DemoChip({
    required this.label,
    required this.email,
    required this.onSelect,
  });

  final String label;
  final String email;
  final void Function(String email) onSelect;

  @override
  Widget build(BuildContext context) {
    return ActionChip(
      avatar: const Icon(Icons.person_outline_rounded, size: 16),
      label: Text(label),
      onPressed: () => onSelect(email),
      tooltip: email,
    );
  }
}
