import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/class_repository.dart';
import '../../../state/base_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/layout/app_page.dart';

/// Create or edit a class. Only the name is required.
class ClassFormScreen extends StatefulWidget {
  const ClassFormScreen({super.key, this.args = const ClassFormArgs()});

  final ClassFormArgs args;

  @override
  State<ClassFormScreen> createState() => _ClassFormScreenState();
}

class _ClassFormScreenState extends State<ClassFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _subject;
  late final TextEditingController _section;
  late final TextEditingController _session;
  late final TextEditingController _description;

  bool _saving = false;
  String? _error;

  SchoolClass? get _existing => widget.args.existing;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: _existing?.name ?? '');
    _subject = TextEditingController(text: _existing?.subject ?? '');
    _section = TextEditingController(text: _existing?.section ?? '');
    _session = TextEditingController(
      text: _existing?.session ?? AppDate.currentSessionLabel(),
    );
    _description = TextEditingController(text: _existing?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _subject.dispose();
    _section.dispose();
    _session.dispose();
    _description.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser teacher = context.read<SessionController>().requireUser;
    final ClassDraft draft = ClassDraft(
      name: _name.text,
      subject: _subject.text,
      section: _section.text,
      session: _session.text,
      description: _description.text,
    );

    try {
      final SchoolClass saved = _existing == null
          ? await deps.classes.create(
              teacherId: teacher.id,
              draft: draft,
              organizationId: teacher.organizationId,
            )
          : await deps.classes.update(_existing!.id, draft);

      if (!mounted) return;
      Navigator.of(context).pop(saved);
      context.showSuccess(
        _existing == null ? '${saved.name} created.' : '${saved.name} updated.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = BaseController.describeFailure(error);
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool isEditing = widget.args.isEditing;

    return Scaffold(
      appBar: AppBar(title: Text(isEditing ? 'Edit class' : 'New class')),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: AppPageBody(
            children: <Widget>[
              if (_error != null) ...<Widget>[
                AppCard(
                  color: context.semantic.dangerContainer,
                  borderColor: context.semantic.danger.withValues(alpha: 0.35),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.error_outline_rounded,
                        size: 18,
                        color: context.semantic.danger,
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          _error!,
                          style: context.text.bodySmall?.copyWith(
                            color: context.semantic.onDangerContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const Gap.lg(),
              ],
              TextFormField(
                controller: _name,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Class name *',
                  hintText: 'e.g. Software Engineering',
                  prefixIcon: Icon(Icons.class_outlined),
                ),
                validator: (String? v) => Validators.name(v, field: 'Class name'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _subject,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Subject',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.menu_book_outlined),
                ),
                validator: (String? v) =>
                    Validators.maxLength(v, 80, field: 'Subject'),
              ),
              const Gap.lg(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _section,
                      textCapitalization: TextCapitalization.characters,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Section',
                        hintText: 'A',
                        prefixIcon: Icon(Icons.group_work_outlined),
                      ),
                      validator: (String? v) =>
                          Validators.maxLength(v, 20, field: 'Section'),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: TextFormField(
                      controller: _session,
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Session',
                        hintText: '2026',
                        prefixIcon: Icon(Icons.calendar_today_outlined),
                      ),
                      validator: (String? v) =>
                          Validators.maxLength(v, 20, field: 'Session'),
                    ),
                  ),
                ],
              ),
              const Gap.lg(),
              TextFormField(
                controller: _description,
                maxLines: 3,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description',
                  hintText: 'Optional notes about this class',
                  alignLabelWithHint: true,
                ),
                validator: (String? v) =>
                    Validators.maxLength(v, 400, field: 'Description'),
              ),
              const Gap.sm(),
              Text(
                'Only the class name is required. Everything else can be added later.',
                style: context.text.bodySmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
              const Gap.xxl(),
              FilledButton.icon(
                onPressed: _saving ? null : _save,
                icon: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(isEditing ? 'Save changes' : 'Create class'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
