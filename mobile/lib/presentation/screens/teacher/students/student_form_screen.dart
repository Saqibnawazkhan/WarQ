import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/student_repository.dart';
import '../../../state/base_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/layout/app_page.dart';

/// Add or edit a student.
///
/// Only the name is mandatory — roll number and every phone number are
/// optional, exactly as the product spec requires.
class StudentFormScreen extends StatefulWidget {
  const StudentFormScreen({super.key, required this.args});

  final StudentFormArgs args;

  @override
  State<StudentFormScreen> createState() => _StudentFormScreenState();
}

class _StudentFormScreenState extends State<StudentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _fullName;
  late final TextEditingController _rollNumber;
  late final TextEditingController _studentPhone;
  late final TextEditingController _fatherPhone;
  late final TextEditingController _motherPhone;
  late final TextEditingController _guardianName;
  late final TextEditingController _email;
  late final TextEditingController _address;
  late final TextEditingController _notes;

  bool _saving = false;
  bool _showMoreFields = false;
  String? _error;

  /// Set when the teacher chooses "save and add another" so the screen can
  /// reset instead of popping — bulk entry is much faster this way.
  bool _addAnother = false;

  Student? get _existing => widget.args.existing;

  @override
  void initState() {
    super.initState();
    _fullName = TextEditingController(text: _existing?.fullName ?? '');
    _rollNumber = TextEditingController(text: _existing?.rollNumber ?? '');
    _studentPhone = TextEditingController(text: _existing?.studentPhone ?? '');
    _fatherPhone = TextEditingController(text: _existing?.fatherPhone ?? '');
    _motherPhone = TextEditingController(text: _existing?.motherPhone ?? '');
    _guardianName = TextEditingController(text: _existing?.guardianName ?? '');
    _email = TextEditingController(text: _existing?.email ?? '');
    _address = TextEditingController(text: _existing?.address ?? '');
    _notes = TextEditingController(text: _existing?.notes ?? '');
    _showMoreFields = _existing?.guardianName != null ||
        _existing?.email != null ||
        _existing?.address != null ||
        _existing?.notes != null;
  }

  @override
  void dispose() {
    _fullName.dispose();
    _rollNumber.dispose();
    _studentPhone.dispose();
    _fatherPhone.dispose();
    _motherPhone.dispose();
    _guardianName.dispose();
    _email.dispose();
    _address.dispose();
    _notes.dispose();
    super.dispose();
  }

  StudentDraft _buildDraft() => StudentDraft(
        fullName: _fullName.text,
        rollNumber: _rollNumber.text,
        studentPhone: _studentPhone.text,
        fatherPhone: _fatherPhone.text,
        motherPhone: _motherPhone.text,
        guardianName: _guardianName.text,
        email: _email.text,
        address: _address.text,
        notes: _notes.text,
      );

  void _resetForm() {
    _fullName.clear();
    _rollNumber.clear();
    _studentPhone.clear();
    _fatherPhone.clear();
    _motherPhone.clear();
    _guardianName.clear();
    _email.clear();
    _address.clear();
    _notes.clear();
    _formKey.currentState?.reset();
  }

  Future<void> _save({bool addAnother = false}) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _addAnother = addAnother;
      _error = null;
    });

    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser teacher = context.read<SessionController>().requireUser;

    try {
      final Student saved = _existing == null
          ? await deps.students.create(
              teacherId: teacher.id,
              draft: _buildDraft(),
              classId: widget.args.classId,
              organizationId: teacher.organizationId,
            )
          : await deps.students.update(_existing!.id, _buildDraft());

      if (!mounted) return;

      if (addAnother) {
        _resetForm();
        setState(() => _saving = false);
        context.showSuccess('${saved.fullName} added. Add the next student.');
        return;
      }

      Navigator.of(context).pop(saved);
      context.showSuccess(
        _existing == null
            ? '${saved.fullName} added.'
            : '${saved.fullName} updated.',
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
      appBar: AppBar(title: Text(isEditing ? 'Edit student' : 'Add student')),
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
                controller: _fullName,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Student name *',
                  prefixIcon: Icon(Icons.person_outline_rounded),
                ),
                validator: (String? v) =>
                    Validators.name(v, field: 'Student name'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _rollNumber,
                textCapitalization: TextCapitalization.characters,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Roll / student number',
                  hintText: 'Optional',
                  prefixIcon: Icon(Icons.tag_rounded),
                ),
                validator: (String? v) =>
                    Validators.maxLength(v, 32, field: 'Roll number'),
              ),
              const Gap.xl(),
              _SectionLabel(
                title: 'Contact numbers',
                subtitle:
                    'Used for absence notifications. Every field is optional — '
                    'recipients without a number are simply skipped.',
              ),
              const Gap.md(),
              TextFormField(
                controller: _studentPhone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Student phone',
                  prefixIcon: Icon(Icons.smartphone_rounded),
                ),
                validator: (String? v) =>
                    Validators.phone(v, field: 'student phone number'),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _fatherPhone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: "Father's phone",
                  prefixIcon: Icon(Icons.man_rounded),
                ),
                validator: (String? v) =>
                    Validators.phone(v, field: "father's phone number"),
              ),
              const Gap.lg(),
              TextFormField(
                controller: _motherPhone,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: "Mother's phone",
                  prefixIcon: Icon(Icons.woman_rounded),
                ),
                validator: (String? v) =>
                    Validators.phone(v, field: "mother's phone number"),
              ),
              const Gap.lg(),
              if (!_showMoreFields)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: () => setState(() => _showMoreFields = true),
                    icon: const Icon(Icons.expand_more_rounded, size: 20),
                    label: const Text('More details'),
                  ),
                )
              else ...<Widget>[
                const Gap.sm(),
                _SectionLabel(title: 'Additional details'),
                const Gap.md(),
                TextFormField(
                  controller: _guardianName,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Guardian name',
                    prefixIcon: Icon(Icons.family_restroom_rounded),
                  ),
                  validator: (String? v) =>
                      Validators.maxLength(v, 80, field: 'Guardian name'),
                ),
                const Gap.lg(),
                TextFormField(
                  controller: _email,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email_rounded),
                  ),
                  validator: (String? v) =>
                      Validators.email(v, isRequired: false),
                ),
                const Gap.lg(),
                TextFormField(
                  controller: _address,
                  textCapitalization: TextCapitalization.words,
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Address',
                    prefixIcon: Icon(Icons.home_outlined),
                  ),
                  validator: (String? v) =>
                      Validators.maxLength(v, 160, field: 'Address'),
                ),
                const Gap.lg(),
                TextFormField(
                  controller: _notes,
                  maxLines: 3,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    labelText: 'Notes',
                    alignLabelWithHint: true,
                  ),
                  validator: (String? v) =>
                      Validators.maxLength(v, 400, field: 'Notes'),
                ),
              ],
              const Gap.xxl(),
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
                icon: _saving && !_addAnother
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.2,
                          color: Colors.white,
                        ),
                      )
                    : const Icon(Icons.check_rounded),
                label: Text(isEditing ? 'Save changes' : 'Add student'),
              ),
              if (!isEditing) ...<Widget>[
                const Gap.md(),
                OutlinedButton.icon(
                  onPressed: _saving ? null : () => _save(addAnother: true),
                  icon: const Icon(Icons.playlist_add_rounded, size: 20),
                  label: const Text('Save and add another'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel({required this.title, this.subtitle});

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          title,
          style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
        ),
        if (subtitle != null) ...<Widget>[
          const SizedBox(height: 2),
          Text(
            subtitle!,
            style: context.text.bodySmall
                ?.copyWith(color: context.semantic.mutedText),
          ),
        ],
      ],
    );
  }
}
