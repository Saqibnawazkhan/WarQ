import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../core/utils/validators.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../state/session_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Two-step password reset.
///
/// Phase 1 has no mail server, so the generated code is displayed in the app
/// and clearly labelled as a local-only step. The screen flow — request a code,
/// then enter it with a new password — is the same one a real email or SMS
/// delivery will slot into.
class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final GlobalKey<FormState> _requestKey = GlobalKey<FormState>();
  final GlobalKey<FormState> _resetKey = GlobalKey<FormState>();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _code = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  PasswordResetTicket? _ticket;
  bool _obscure = true;

  @override
  void dispose() {
    _email.dispose();
    _code.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _requestCode() async {
    FocusScope.of(context).unfocus();
    if (!(_requestKey.currentState?.validate() ?? false)) return;

    final SessionController session = context.read<SessionController>();
    final PasswordResetTicket? ticket =
        await session.requestPasswordReset(_email.text);
    if (!mounted || ticket == null) return;
    setState(() {
      _ticket = ticket;
      _code.text = ticket.code;
    });
  }

  Future<void> _resetPassword() async {
    FocusScope.of(context).unfocus();
    if (!(_resetKey.currentState?.validate() ?? false)) return;

    final SessionController session = context.read<SessionController>();
    final bool ok = await session.resetPassword(
      email: _email.text,
      code: _code.text,
      newPassword: _password.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      context.showSuccess('Password updated. You can sign in now.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    final PasswordResetTicket? ticket = _ticket;

    return AuthScaffold(
      showBackButton: true,
      title: ticket == null ? 'Reset your password' : 'Choose a new password',
      subtitle: ticket == null
          ? 'Enter the email address on your account and we will send a reset code.'
          : 'Enter the code and pick a new password.',
      children: <Widget>[
        if (session.errorMessage != null)
          AuthErrorBanner(message: session.errorMessage!),
        if (ticket == null)
          Form(
            key: _requestKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (String? v) => Validators.email(v),
                  onFieldSubmitted: (_) => _requestCode(),
                ),
                const SizedBox(height: AppSpacing.xl),
                FilledButton(
                  onPressed: session.isBusy ? null : _requestCode,
                  child: session.isBusy
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.2,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Send reset code'),
                ),
              ],
            ),
          )
        else
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              _ResetCodeCard(ticket: ticket),
              const SizedBox(height: AppSpacing.xl),
              Form(
                key: _resetKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    TextFormField(
                      controller: _code,
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Reset code',
                        prefixIcon: Icon(Icons.pin_outlined),
                      ),
                      validator: (String? v) =>
                          Validators.required(v, field: 'Reset code'),
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _password,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.next,
                      decoration: InputDecoration(
                        labelText: 'New password',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(() => _obscure = !_obscure),
                          icon: Icon(
                            _obscure
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                      ),
                      validator: Validators.password,
                    ),
                    const SizedBox(height: AppSpacing.lg),
                    TextFormField(
                      controller: _confirmPassword,
                      obscureText: _obscure,
                      textInputAction: TextInputAction.done,
                      decoration: const InputDecoration(
                        labelText: 'Confirm new password',
                        prefixIcon: Icon(Icons.lock_reset_rounded),
                      ),
                      validator: (String? v) =>
                          Validators.confirmPassword(v, _password.text),
                      onFieldSubmitted: (_) => _resetPassword(),
                    ),
                    const SizedBox(height: AppSpacing.xl),
                    FilledButton(
                      onPressed: session.isBusy ? null : _resetPassword,
                      child: session.isBusy
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Text('Update password'),
                    ),
                    TextButton(
                      onPressed: () => setState(() => _ticket = null),
                      child: const Text('Use a different email'),
                    ),
                  ],
                ),
              ),
            ],
          ),
      ],
    );
  }
}

class _ResetCodeCard extends StatelessWidget {
  const _ResetCodeCard({required this.ticket});

  final PasswordResetTicket ticket;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: context.semantic.infoContainer,
        borderRadius: AppRadii.cardRadius,
        border: Border.all(color: context.semantic.info.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                Icons.info_outline_rounded,
                size: 18,
                color: context.semantic.info,
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  'Reset code for ${ticket.deliveredTo}',
                  style: context.text.labelLarge?.copyWith(
                    color: context.semantic.onInfoContainer,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: <Widget>[
              Text(
                ticket.code,
                style: context.text.headlineSmall?.copyWith(
                  letterSpacing: 6,
                  fontWeight: FontWeight.w800,
                  color: context.semantic.onInfoContainer,
                ),
              ),
              const Spacer(),
              IconButton(
                tooltip: 'Copy code',
                onPressed: () {
                  Clipboard.setData(ClipboardData(text: ticket.code));
                  context.showInfo('Reset code copied.');
                },
                icon: const Icon(Icons.copy_rounded, size: 18),
              ),
            ],
          ),
          Text(
            'Valid until ${AppDate.formatTime(ticket.expiresAt)}. '
            'In production this code is emailed instead of shown here.',
            style: context.text.bodySmall?.copyWith(
              color: context.semantic.onInfoContainer,
            ),
          ),
        ],
      ),
    );
  }
}
