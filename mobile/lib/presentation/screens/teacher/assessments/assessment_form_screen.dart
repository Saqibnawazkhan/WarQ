import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../core/utils/validators.dart';
import '../../../../data/models/models.dart';
import '../../../../data/repositories/assessment_repository.dart';
import '../../../state/base_controller.dart';
import '../../../state/session_controller.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/domain/assessment_tile.dart';
import '../../../widgets/layout/app_page.dart';

/// Create or edit an assessment (quiz, assignment, exam, project, …).
class AssessmentFormScreen extends StatefulWidget {
  const AssessmentFormScreen({super.key, required this.args});

  final AssessmentFormArgs args;

  @override
  State<AssessmentFormScreen> createState() => _AssessmentFormScreenState();
}

class _AssessmentFormScreenState extends State<AssessmentFormScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _customType;
  late final TextEditingController _totalMarks;
  late final TextEditingController _description;

  late AssessmentType _type;
  late DateTime _date;
  bool _saving = false;
  String? _error;

  Assessment? get _existing => widget.args.existing;

  @override
  void initState() {
    super.initState();
    _type = _existing?.type ?? AssessmentType.quiz;
    _date = _existing?.date ?? AppDate.today();
    _name = TextEditingController(text: _existing?.name ?? '');
    _customType = TextEditingController(text: _existing?.customTypeLabel ?? '');
    _totalMarks = TextEditingController(
      text: Format.marks(_existing?.totalMarks ?? _type.suggestedTotalMarks),
    );
    _description = TextEditingController(text: _existing?.description ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _customType.dispose();
    _totalMarks.dispose();
    _description.dispose();
    super.dispose();
  }

  void _onTypeChanged(AssessmentType type) {
    setState(() {
      _type = type;
      // Only auto-fill the suggested total while creating; editing must not
      // silently rewrite a total that already has marks against it.
      if (_existing == null) {
        _totalMarks.text = Format.marks(type.suggestedTotalMarks);
      }
    });
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(DateTime.now().year - 2),
      lastDate: DateTime(DateTime.now().year + 2),
      helpText: 'Assessment date',
    );
    if (picked != null) setState(() => _date = AppDate.dateOnly(picked));
  }

  Future<void> _save({bool thenEnterMarks = false}) async {
    FocusScope.of(context).unfocus();
    if (!(_formKey.currentState?.validate() ?? false)) return;

    setState(() {
      _saving = true;
      _error = null;
    });

    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser teacher = context.read<SessionController>().requireUser;
    final AssessmentDraft draft = AssessmentDraft(
      name: _name.text,
      type: _type,
      customTypeLabel: _customType.text,
      date: _date,
      totalMarks: double.tryParse(_totalMarks.text.trim()) ?? 0,
      description: _description.text,
    );

    try {
      final Assessment saved = _existing == null
          ? await deps.assessments.create(
              classId: widget.args.classId,
              userId: teacher.id,
              draft: draft,
            )
          : await deps.assessments.update(_existing!.id, draft);

      if (!mounted) return;
      Navigator.of(context).pop(saved);
      if (thenEnterMarks) {
        Navigator.of(context).pushNamed(
          Routes.assessmentMarks,
          arguments: AssessmentMarksArgs(assessmentId: saved.id),
        );
      } else {
        context.showSuccess(
          _existing == null ? '${saved.name} created.' : '${saved.name} updated.',
        );
      }
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
      appBar: AppBar(
        title: Text(isEditing ? 'Edit assessment' : 'New assessment'),
      ),
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
              // The name comes first because it is what the teacher opened this
              // screen to type. The eight types used to sit above it as three
              // rows of chips, which pushed the only required field below the
              // fold to choose something that is Quiz nine times out of ten.
              TextFormField(
                controller: _name,
                autofocus: !isEditing,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.next,
                decoration: const InputDecoration(
                  labelText: 'Assessment name *',
                  hintText: 'e.g. Quiz 1',
                  prefixIcon: Icon(Icons.title_rounded),
                ),
                validator: (String? v) =>
                    Validators.name(v, field: 'Assessment name'),
              ),
              const Gap.lg(),
              DropdownButtonFormField<AssessmentType>(
                initialValue: _type,
                // No prefix icon: each item carries the icon for its own type,
                // and the field would otherwise show two side by side.
                decoration: const InputDecoration(
                  labelText: 'Type',
                  contentPadding: EdgeInsets.symmetric(
                    horizontal: AppSpacing.lg,
                    vertical: AppSpacing.md,
                  ),
                ),
                items: <DropdownMenuItem<AssessmentType>>[
                  for (final AssessmentType type in AssessmentType.values)
                    DropdownMenuItem<AssessmentType>(
                      value: type,
                      child: Row(
                        children: <Widget>[
                          Icon(
                            AssessmentTile.iconFor(type),
                            size: 18,
                            color: context.semantic.mutedText,
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Text(type.label),
                        ],
                      ),
                    ),
                ],
                onChanged: (AssessmentType? type) {
                  if (type != null) _onTypeChanged(type);
                },
              ),
              if (_type == AssessmentType.custom) ...<Widget>[
                const Gap.lg(),
                TextFormField(
                  controller: _customType,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: 'Custom type name *',
                    hintText: 'e.g. Lab report',
                    prefixIcon: Icon(Icons.label_outline_rounded),
                  ),
                  validator: (String? v) => _type == AssessmentType.custom
                      ? Validators.required(v, field: 'Custom type name')
                      : null,
                ),
              ],
              const Gap.lg(),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: TextFormField(
                      controller: _totalMarks,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Total marks *',
                        prefixIcon: Icon(Icons.calculate_outlined),
                      ),
                      validator: Validators.totalMarks,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: InkWell(
                      onTap: _pickDate,
                      borderRadius: AppRadii.fieldRadius,
                      child: InputDecorator(
                        decoration: const InputDecoration(
                          labelText: 'Date',
                          prefixIcon: Icon(Icons.calendar_today_outlined),
                        ),
                        child: Text(AppDate.format(_date)),
                      ),
                    ),
                  ),
                ],
              ),
              const Gap.lg(),
              TextFormField(
                controller: _description,
                maxLines: 2,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Description (optional)',
                  hintText: 'Topics covered, instructions, …',
                  alignLabelWithHint: true,
                ),
                validator: (String? v) =>
                    Validators.maxLength(v, 400, field: 'Description'),
              ),
              const Gap.xl(),
              // One button that looks like the answer, and the other route as
              // plain text under it. Two filled-looking buttons side by side
              // made a teacher stop and choose before they had done anything.
              FilledButton.icon(
                onPressed: _saving ? null : () => _save(),
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
                label: Text(isEditing ? 'Save changes' : 'Create assessment'),
              ),
              if (!isEditing) ...<Widget>[
                const Gap.sm(),
                TextButton.icon(
                  onPressed: _saving ? null : () => _save(thenEnterMarks: true),
                  icon: const Icon(Icons.edit_note_rounded, size: 20),
                  label: const Text('Create, then enter marks now'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
