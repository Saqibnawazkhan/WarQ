import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/phone_number.dart';
import '../../state/app_settings_controller.dart';
import '../../widgets/common/app_badge.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/stat_tile.dart';
import '../../widgets/layout/app_page.dart';

/// How absence notices reach guardians, and the dialling code used to address
/// numbers that are stored without one.
class MessagingSettingsScreen extends StatefulWidget {
  const MessagingSettingsScreen({super.key});

  @override
  State<MessagingSettingsScreen> createState() =>
      _MessagingSettingsScreenState();
}

class _MessagingSettingsScreenState extends State<MessagingSettingsScreen> {
  late final TextEditingController _code = TextEditingController(
    text: context.read<AppSettingsController>().defaultCountryCode ?? '',
  );
  String? _error;

  /// A short list covering the regions this build is most likely used in;
  /// anything else can be typed directly.
  static const List<({String code, String label})> _common =
      <({String code, String label})>[
    (code: '92', label: 'Pakistan'),
    (code: '91', label: 'India'),
    (code: '880', label: 'Bangladesh'),
    (code: '971', label: 'UAE'),
    (code: '966', label: 'Saudi Arabia'),
    (code: '44', label: 'UK'),
    (code: '1', label: 'US / Canada'),
  ];

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _apply(String value) async {
    final String trimmed = value.trim();
    if (trimmed.isEmpty) {
      setState(() => _error = null);
      await context.read<AppSettingsController>().setDefaultCountryCode(null);
      return;
    }
    if (!PhoneNumber.isValidCountryCode(trimmed)) {
      setState(() => _error = 'Enter a dialling code such as 92 or +44.');
      return;
    }
    setState(() => _error = null);
    await context.read<AppSettingsController>().setDefaultCountryCode(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final AppSettingsController settings =
        context.watch<AppSettingsController>();
    final AppDependencies deps = context.read<AppDependencies>();
    final String? code = settings.defaultCountryCode;

    // Live preview so the teacher can see exactly what the setting does.
    const String sample = '03001112222';
    final String? resolved =
        PhoneNumber.toE164(sample, defaultCountryCode: code);

    return Scaffold(
      appBar: AppBar(title: const Text('Messaging')),
      body: SafeArea(
        child: AppPageBody(
          children: <Widget>[
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: context.semantic.success.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(AppRadii.sm),
                        ),
                        child: Icon(
                          Icons.chat_rounded,
                          color: context.semantic.success,
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Text(
                              deps.absenceNotifications.provider.displayName,
                              style: context.text.titleSmall
                                  ?.copyWith(fontWeight: FontWeight.w700),
                            ),
                            const SizedBox(height: 2),
                            const AppBadge(
                              'Active',
                              tone: BadgeTone.success,
                              dense: true,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Gap.md(),
                  Text(
                    deps.absenceNotifications.provider.statusDescription,
                    style: context.text.bodySmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                ],
              ),
            ),
            const Gap.xl(),
            SectionCard(
              title: 'Default dialling code',
              subtitle:
                  'Applied to guardian numbers saved without a country code',
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  TextField(
                    controller: _code,
                    keyboardType: TextInputType.phone,
                    inputFormatters: <TextInputFormatter>[
                      FilteringTextInputFormatter.allow(RegExp(r'[0-9+]')),
                      LengthLimitingTextInputFormatter(5),
                    ],
                    decoration: InputDecoration(
                      labelText: 'Country code',
                      hintText: 'e.g. 92',
                      prefixText: '+',
                      errorText: _error,
                      suffixIcon: _code.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: 'Clear',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: () {
                                _code.clear();
                                _apply('');
                                setState(() {});
                              },
                            ),
                    ),
                    onChanged: (String value) {
                      _apply(value);
                      setState(() {});
                    },
                  ),
                  const Gap.md(),
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: <Widget>[
                      for (final ({String code, String label}) entry in _common)
                        ChoiceChip(
                          label: Text('${entry.label} +${entry.code}'),
                          selected: code == entry.code,
                          showCheckmark: false,
                          onSelected: (_) {
                            _code.text = entry.code;
                            _apply(entry.code);
                            setState(() {});
                          },
                        ),
                    ],
                  ),
                  const Gap.lg(),
                  DetailRow(
                    label: 'A number saved as $sample',
                    value: resolved ?? 'cannot be messaged',
                    icon: Icons.arrow_forward_rounded,
                    valueColor: resolved == null
                        ? context.semantic.danger
                        : context.semantic.success,
                  ),
                ],
              ),
            ),
            const Gap.xl(),
            AppCard(
              color: context.colors.surfaceContainerHigh,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    'How absence notices work',
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Gap.sm(),
                  Text(
                    'Marking a student absent prepares one message per number '
                    'on their record — student, father and mother. WhatsApp '
                    'opens with the message written, and you tap send. Numbers '
                    'that are missing or cannot be dialled are skipped and '
                    'listed for you.',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                  const Gap.md(),
                  Text(
                    'Sending without any tap needs the WhatsApp Cloud API, '
                    'which requires a server to hold the access token and '
                    'message templates approved by Meta. That arrives with the '
                    'backend in the next phase.',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                ],
              ),
            ),
            const Gap.xxl(),
          ],
        ),
      ),
    );
  }
}
