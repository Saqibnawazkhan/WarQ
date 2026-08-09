import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/services/messaging/message_templates.dart';
import '../../../state/org_admin_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/layout/app_page.dart';
import '../../auth/widgets/auth_scaffold.dart';

/// Invite a teacher to the organization by email.
///
/// Phase 1 records the invitation and offers copyable text the admin can send
/// through any channel. Wiring an email or WhatsApp provider later reuses the
/// same [Invitation] record.
///
/// Pushed routes sit above the shell in the navigator, so this screen owns its
/// own [OrgAdminController]; the shell refreshes through the data event bus.
class InviteTeacherScreen extends StatelessWidget {
  const InviteTeacherScreen({
    super.key,
    this.args = const InviteTeacherArgs(),
  });

  final InviteTeacherArgs args;

  @override
  Widget build(BuildContext context) {
    final AppUser admin = context.read<SessionController>().requireUser;
    return ChangeNotifierProvider<OrgAdminController>(
      create: (BuildContext context) =>
          OrgAdminController(context.read<AppDependencies>(), admin)..load(),
      child: _InviteTeacherForm(args: args),
    );
  }
}

class _InviteTeacherForm extends StatefulWidget {
  const _InviteTeacherForm({required this.args});

  final InviteTeacherArgs args;

  @override
  State<_InviteTeacherForm> createState() => _InviteTeacherFormState();
}

class _InviteTeacherFormState extends State<_InviteTeacherForm> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _email =
      TextEditingController(text: widget.args.prefilledEmail ?? '');
  final TextEditingController _name = TextEditingController();
  final TextEditingController _message = TextEditingController();

  Invitation? _created;

  @override
  void dispose() {
    _email.dispose();
    _name.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final OrgAdminController controller = context.read<OrgAdminController>();
    final Invitation? invitation = await controller.inviteTeacher(
      email: _email.text,
      inviteeName: _name.text,
      message: _message.text,
    );
    if (!mounted) return;
    if (invitation == null) {
      context.showError(controller.errorMessage ?? 'Could not send the invitation.');
      return;
    }
    setState(() => _created = invitation);
    context.showSuccess('Invitation created for ${invitation.email}.');
  }

  @override
  Widget build(BuildContext context) {
    final OrgAdminController controller = context.watch<OrgAdminController>();
    final Invitation? created = _created;

    return Scaffold(
      appBar: AppBar(title: const Text('Invite teacher')),
      body: SafeArea(
        child: created != null
            ? _InvitationCreated(
                invitation: created,
                organizationName: controller.organization?.name ?? 'your organization',
                inviterName: controller.admin.displayName,
                onInviteAnother: () => setState(() {
                  _created = null;
                  _email.clear();
                  _name.clear();
                  _message.clear();
                }),
              )
            : Form(
                key: _formKey,
                child: AppPageBody(
                  children: <Widget>[
                    if (controller.errorMessage != null)
                      AuthErrorBanner(message: controller.errorMessage!),
                    Text(
                      'Invite a teacher to ${controller.organization?.name ?? 'your organization'}',
                      style: context.text.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const Gap.sm(),
                    Text(
                      'They join automatically when they create an account with '
                      'this email address. Existing users get an in-app '
                      'notification straight away.',
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                    const Gap.xl(),
                    TextFormField(
                      controller: _email,
                      autofocus: true,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Teacher email *',
                        prefixIcon: Icon(Icons.alternate_email_rounded),
                      ),
                      validator: (String? v) => Validators.email(v),
                    ),
                    const Gap.lg(),
                    TextFormField(
                      controller: _name,
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Teacher name',
                        hintText: 'Optional',
                        prefixIcon: Icon(Icons.person_outline_rounded),
                      ),
                      validator: (String? v) =>
                          Validators.maxLength(v, 80, field: 'Teacher name'),
                    ),
                    const Gap.lg(),
                    TextFormField(
                      controller: _message,
                      maxLines: 3,
                      textCapitalization: TextCapitalization.sentences,
                      decoration: const InputDecoration(
                        labelText: 'Personal message',
                        hintText: 'Optional note included with the invitation',
                        alignLabelWithHint: true,
                      ),
                      validator: (String? v) =>
                          Validators.maxLength(v, 280, field: 'Message'),
                    ),
                    const Gap.xxl(),
                    FilledButton.icon(
                      onPressed: controller.isBusy ? null : _send,
                      icon: controller.isBusy
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.send_rounded),
                      label: const Text('Create invitation'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}

class _InvitationCreated extends StatelessWidget {
  const _InvitationCreated({
    required this.invitation,
    required this.organizationName,
    required this.inviterName,
    required this.onInviteAnother,
  });

  final Invitation invitation;
  final String organizationName;
  final String inviterName;
  final VoidCallback onInviteAnother;

  @override
  Widget build(BuildContext context) {
    final String text = MessageTemplates.invitation(
      organizationName: organizationName,
      inviterName: inviterName,
      token: invitation.token,
      inviteeName: invitation.inviteeName,
    );

    return AppPageBody(
      children: <Widget>[
        Center(
          child: Column(
            children: <Widget>[
              Container(
                width: 68,
                height: 68,
                decoration: BoxDecoration(
                  color: context.semantic.successContainer,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  Icons.mark_email_read_outlined,
                  size: 32,
                  color: context.semantic.success,
                ),
              ),
              const Gap.lg(),
              Text(
                'Invitation created',
                style: context.text.titleLarge
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Gap.xs(),
              Text(
                invitation.email,
                style: context.text.bodyMedium
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ],
          ),
        ),
        const Gap.xxl(),
        AppCard(
          color: context.colors.surfaceContainerHigh,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Invitation message',
                      style: context.text.labelLarge
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copy',
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: text));
                      context.showInfo('Invitation text copied.');
                    },
                    icon: const Icon(Icons.copy_rounded, size: 18),
                  ),
                ],
              ),
              const Gap.sm(),
              SelectableText(text, style: context.text.bodySmall),
            ],
          ),
        ),
        const Gap.lg(),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'What happens next',
                style: context.text.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const Gap.sm(),
              Text(
                'Send this message through email or WhatsApp. Once they sign up '
                'with ${invitation.email}, the invitation is marked accepted and '
                'their classes appear in your dashboard.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ],
          ),
        ),
        const Gap.xxl(),
        FilledButton.icon(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.check_rounded),
          label: const Text('Done'),
        ),
        const Gap.md(),
        OutlinedButton.icon(
          onPressed: onInviteAnother,
          icon: const Icon(Icons.person_add_alt_1_rounded, size: 20),
          label: const Text('Invite another teacher'),
        ),
      ],
    );
  }
}
