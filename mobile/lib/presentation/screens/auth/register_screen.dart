import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/models.dart';
import '../../state/session_controller.dart';
import 'widgets/auth_scaffold.dart';

/// Account creation for an individual teacher or an organization.
///
/// Phase 1 has no approval workflow — the account is usable immediately. When
/// an organization admin has already invited the email address, the new teacher
/// joins that organization automatically.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  final TextEditingController _fullName = TextEditingController();
  final TextEditingController _email = TextEditingController();
  final TextEditingController _phone = TextEditingController();
  final TextEditingController _organization = TextEditingController();
  final TextEditingController _city = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();

  UserRole _role = UserRole.teacher;
  bool _obscure = true;

  @override
  void dispose() {
    _fullName.dispose();
    _email.dispose();
    _phone.dispose();
    _organization.dispose();
    _city.dispose();
    _password.dispose();
    _confirmPassword.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final SessionController session = context.read<SessionController>();
    final bool ok = _role == UserRole.teacher
        ? await session.registerTeacher(
            fullName: _fullName.text,
            email: _email.text,
            password: _password.text,
            phone: _phone.text,
          )
        : await session.registerOrganization(
            fullName: _fullName.text,
            email: _email.text,
            password: _password.text,
            organizationName: _organization.text,
            city: _city.text,
            phone: _phone.text,
          );

    if (!mounted) return;
    if (ok) {
      // The root gate swaps to the signed-in shell; drop the auth stack.
      Navigator.of(context).popUntil((Route<dynamic> route) => route.isFirst);
      // A new account may be waiting for approval, in which case the gate shows
      // the screen that explains it. Welcoming them to an app they cannot use
      // yet would contradict it.
      context.showSuccess(
        session.user?.hasAccess ?? false
            ? 'Account created. Welcome to WarQ.'
            : 'Account created. We will let you in as soon as it is approved.',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    final bool isOrganization = _role == UserRole.orgAdmin;

    return AuthScaffold(
      showBackButton: true,
      title: 'Create your account',
      subtitle: 'Start managing classes in a couple of minutes.',
      children: <Widget>[
        if (session.errorMessage != null)
          AuthErrorBanner(message: session.errorMessage!),
        _RoleSelector(
          value: _role,
          onChanged: (UserRole value) => setState(() => _role = value),
        ),
        const SizedBox(height: AppSpacing.xl),
        Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (String? v) => Validators.name(v, field: 'Full name'),
              ),
              if (isOrganization) ...<Widget>[
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _organization,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Organization name',
                    prefixIcon: Icon(Icons.apartment_rounded),
                    helperText: 'Your school, college or academy',
                  ),
                  validator: (String? v) =>
                      Validators.name(v, field: 'Organization name'),
                ),
                const SizedBox(height: AppSpacing.lg),
                TextFormField(
                  controller: _city,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'City *',
                    prefixIcon: Icon(Icons.location_city_rounded),
                  ),
                  validator: (String? v) => Validators.name(v, field: 'City'),
                ),
              ],
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _email,
                keyboardType: TextInputType.emailAddress,
                textInputAction: TextInputAction.next,
                autocorrect: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                ),
                validator: (String? v) => Validators.email(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number (optional)',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (String? v) => Validators.phone(v),
              ),
              const SizedBox(height: AppSpacing.lg),
              TextFormField(
                controller: _password,
                obscureText: _obscure,
                textInputAction: TextInputAction.next,
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
                  labelText: 'Confirm password',
                  prefixIcon: Icon(Icons.lock_reset_rounded),
                ),
                validator: (String? v) =>
                    Validators.confirmPassword(v, _password.text),
                onFieldSubmitted: (_) => _submit(),
              ),
              const SizedBox(height: AppSpacing.xl),
              FilledButton(
                onPressed: session.isBusy ? null : _submit,
                child: session.isBusy
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        isOrganization
                            ? 'Create organization'
                            : 'Create teacher account',
                      ),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                isOrganization
                    ? 'You will be able to invite teachers straight away.'
                    : 'If your organization has already invited this email, you '
                        'will join it automatically.',
                textAlign: TextAlign.center,
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _RoleSelector extends StatelessWidget {
  const _RoleSelector({required this.value, required this.onChanged});

  final UserRole value;
  final ValueChanged<UserRole> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        _RoleOption(
          icon: Icons.person_outline_rounded,
          title: 'I am a teacher',
          description: 'Create classes, take attendance and record marks.',
          selected: value == UserRole.teacher,
          onTap: () => onChanged(UserRole.teacher),
        ),
        const SizedBox(height: AppSpacing.md),
        _RoleOption(
          icon: Icons.apartment_rounded,
          title: 'I manage an organization',
          description: 'Invite teachers and monitor their classes.',
          selected: value == UserRole.orgAdmin,
          onTap: () => onChanged(UserRole.orgAdmin),
        ),
      ],
    );
  }
}

class _RoleOption extends StatelessWidget {
  const _RoleOption({
    required this.icon,
    required this.title,
    required this.description,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? context.colors.primary.withValues(alpha: 0.07)
          : context.colors.surface,
      borderRadius: AppRadii.cardRadius,
      child: InkWell(
        onTap: onTap,
        borderRadius: AppRadii.cardRadius,
        child: Container(
          padding: const EdgeInsets.all(AppSpacing.lg),
          decoration: BoxDecoration(
            borderRadius: AppRadii.cardRadius,
            border: Border.all(
              color: selected
                  ? context.colors.primary
                  : context.semantic.subtleBorder,
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Row(
            children: <Widget>[
              Icon(
                icon,
                color: selected
                    ? context.colors.primary
                    : context.semantic.mutedText,
              ),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      title,
                      style: context.text.titleSmall
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  ],
                ),
              ),
              Icon(
                selected
                    ? Icons.radio_button_checked_rounded
                    : Icons.radio_button_unchecked_rounded,
                color: selected
                    ? context.colors.primary
                    : context.semantic.subtleBorder,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
