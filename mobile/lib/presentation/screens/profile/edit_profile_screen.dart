import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/utils/validators.dart';
import '../../../data/models/models.dart';
import '../../state/session_controller.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/layout/app_page.dart';
import '../auth/widgets/auth_scaffold.dart';

/// Edit the signed-in user's own profile.
class EditProfileScreen extends StatefulWidget {
  const EditProfileScreen({super.key});

  @override
  State<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends State<EditProfileScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _username;
  late final TextEditingController _phone;
  late final TextEditingController _title;
  late final TextEditingController _bio;

  @override
  void initState() {
    super.initState();
    final AppUser user = context.read<SessionController>().requireUser;
    _fullName = TextEditingController(text: user.fullName);
    _username = TextEditingController(text: user.username ?? '');
    _phone = TextEditingController(text: user.phone ?? '');
    _title = TextEditingController(text: user.title ?? '');
    _bio = TextEditingController(text: user.bio ?? '');
  }

  @override
  void dispose() {
    _fullName.dispose();
    _username.dispose();
    _phone.dispose();
    _title.dispose();
    _bio.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final SessionController session = context.read<SessionController>();
    final bool ok = await session.updateProfile(
      fullName: _fullName.text,
      username: _username.text,
      phone: _phone.text,
      title: _title.text,
      bio: _bio.text,
    );
    if (!mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      context.showSuccess('Profile updated.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    final AppUser? user = session.user;
    if (user == null) return const Scaffold(body: SizedBox.shrink());

    return Scaffold(
      appBar: AppBar(title: const Text('Edit profile')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AppPageBody(
            children: <Widget>[
              if (session.errorMessage != null)
                AuthErrorBanner(message: session.errorMessage!),
              Center(
                child: AppAvatar(
                  name: _fullName.text.isEmpty ? user.displayName : _fullName.text,
                  seed: user.id,
                  size: 84,
                ),
              ),
              const Gap.xl(),
              TextFormField(
                controller: _fullName,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Full name *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (String? v) => Validators.name(v, field: 'Full name'),
                onChanged: (_) => setState(() {}),
              ),
              const Gap.lg(),
              TextFormField(
                initialValue: user.email,
                enabled: false,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  prefixIcon: Icon(Icons.alternate_email_rounded),
                  helperText: 'Email cannot be changed in this version',
                ),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _username,
                autocorrect: false,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Username',
                  hintText: 'Optional — an alternative way to sign in',
                  prefixIcon: Icon(Icons.badge_outlined),
                ),
                validator: (String? v) => Validators.username(v),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Phone number',
                  prefixIcon: Icon(Icons.phone_outlined),
                ),
                validator: (String? v) => Validators.phone(v),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _title,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Title',
                  hintText: 'e.g. Senior Lecturer — shown on reports',
                  prefixIcon: Icon(Icons.work_outline_rounded),
                ),
                validator: (String? v) =>
                    Validators.maxLength(v, 60, field: 'Title'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _bio,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'About',
                  alignLabelWithHint: true,
                ),
                validator: (String? v) =>
                    Validators.maxLength(v, 280, field: 'About'),
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
                label: const Text('Save changes'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
