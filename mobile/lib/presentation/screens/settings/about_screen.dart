import 'package:flutter/material.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/layout/app_page.dart';
import '../splash/splash_screen.dart';

/// Version and scope information.
class AboutScreen extends StatelessWidget {
  const AboutScreen({super.key});

  static const List<({String title, String detail, IconData icon})> _features =
      <({String title, String detail, IconData icon})>[
    (
      title: 'Classes and students',
      detail: 'Create classes, enroll students and keep an A–Z roster.',
      icon: Icons.class_outlined,
    ),
    (
      title: 'Attendance',
      detail: 'Daily marking, full history and guardian absence notices.',
      icon: Icons.how_to_reg_outlined,
    ),
    (
      title: 'Assessments and grading',
      detail: 'Quizzes to final exams, with automatic percentages and grades.',
      icon: Icons.assignment_outlined,
    ),
    (
      title: 'PDF reports',
      detail: 'Individual and class reports you can preview, save and share.',
      icon: Icons.picture_as_pdf_outlined,
    ),
    (
      title: 'Organization panel',
      detail: 'Invite teachers, monitor activity and review performance.',
      icon: Icons.apartment_outlined,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('About')),
      body: SafeArea(
        child: AppPageBody(
          children: <Widget>[
            Center(
              child: Column(
                children: <Widget>[
                  const AppLogo(size: 68),
                  const Gap.lg(),
                  Text(
                    AppConstants.appName,
                    style: context.text.headlineSmall
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Version ${AppConstants.appVersion}',
                    style: context.text.bodySmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                ],
              ),
            ),
            const Gap.xxl(),
            SectionCard(
              title: 'What you can do',
              child: Column(
                children: <Widget>[
                  for (final ({String title, String detail, IconData icon}) item
                      in _features)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: 34,
                            height: 34,
                            decoration: BoxDecoration(
                              color: context.colors.primary
                                  .withValues(alpha: 0.10),
                              borderRadius: BorderRadius.circular(AppRadii.sm),
                            ),
                            child: Icon(
                              item.icon,
                              size: 17,
                              color: context.colors.primary,
                            ),
                          ),
                          const SizedBox(width: AppSpacing.md),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(item.title, style: context.text.titleSmall),
                                const SizedBox(height: 2),
                                Text(
                                  item.detail,
                                  style: context.text.bodySmall?.copyWith(
                                    color: context.semantic.mutedText,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
                    'Data and privacy',
                    style: context.text.titleSmall
                        ?.copyWith(fontWeight: FontWeight.w700),
                  ),
                  const Gap.sm(),
                  Text(
                    'This release stores everything on your device. Nothing is '
                    'uploaded, and guardian messages are recorded in the outbox '
                    'rather than sent until a messaging provider is connected.',
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
