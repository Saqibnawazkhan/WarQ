import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../state/session_controller.dart';
import '../../widgets/layout/app_page.dart';
import '../auth/widgets/auth_scaffold.dart';

/// Change the signed-in user's password.
///
/// In [forced] mode this is the whole app: an invited teacher signed in with a
/// password that arrived by email, and the root gate shows nothing else until
/// they have chosen their own. There is no back button and no way round, so the
/// screen explains why rather than looking like something has gone wrong.
class ChangePasswordScreen extends StatefulWidget {
  const ChangePasswordScreen({super.key, this.forced = false});

  final bool forced;

  @override
  State<ChangePasswordScreen> createState() => _ChangePasswordScreenState();
}

class _ChangePasswordScreenState extends State<ChangePasswordScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _current = TextEditingController();
  final TextEditingController _next = TextEditingController();
  final TextEditingController _confirm = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final SessionController session = context.read<SessionController>();
    final bool ok = await session.changePassword(
      currentPassword: _current.text,
      newPassword: _next.text,
    );
    if (!mounted) return;
    if (ok) {
      // Nothing to pop back to when this is the only screen: reloading the
      // session clears the flag, and the root gate lets them through.
      if (widget.forced) {
        await session.load(refreshing: true);
        if (!mounted) return;
        context.showSuccess('Password set. Welcome to WarQ.');
        return;
      }
      Navigator.of(context).pop();
      context.showSuccess('Password changed.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.forced ? 'Choose your password' : 'Change password'),
        automaticallyImplyLeading: !widget.forced,
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AppPageBody(
            children: <Widget>[
              if (widget.forced) ...<Widget>[
                Container(
                  padding: AppSpacing.cardPadding,
                  decoration: BoxDecoration(
                    color: context.colors.surfaceContainerHigh,
                    borderRadius: AppRadii.cardRadius,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Icon(
                        Icons.lock_reset_rounded,
                        color: context.colors.primary,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'The password you signed in with was sent to you by '
                          'email, so it is sitting in a mailbox. Choose one only '
                          'you know and WarQ will forget the old one.',
                          style: context.text.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: AppSpacing.xl),
              ],
              if (session.errorMessage != null)
                AuthErrorBanner(message: session.errorMessage!),
              TextFormField(
                controller: _current,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: widget.forced ? 'Password from the email' : 'Current password',
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
                validator: (String? v) =>
                    Validators.required(v, field: 'Current password'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _next,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'New password',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: Validators.password,
              ),
              const Gap.lg(),
              TextFormField(
                controller: _confirm,
                obscureText: _obscure,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: 'Confirm new password',
                  prefixIcon: Icon(Icons.check_circle_outline_rounded),
                ),
                validator: (String? v) =>
                    Validators.confirmPassword(v, _next.text),
                onFieldSubmitted: (_) => _save(),
              ),
              const Gap.md(),
              Text(
                'Use at least ${AppConstants.minPasswordLength} characters.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
              const Gap.xxl(),
              FilledButton.icon(
                onPressed: session.isBusy ? null : _save,
                icon: session.isBusy
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: const Text('Update password'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
