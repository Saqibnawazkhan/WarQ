import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../../core/utils/date_utils.dart';
import '../../../data/models/models.dart';
import '../../state/app_settings_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/common/app_avatar.dart';
import '../../widgets/common/app_badge.dart';
import '../../widgets/common/app_card.dart';
import '../../widgets/common/stat_tile.dart';
import '../../widgets/feedback/dialogs.dart';
import '../../widgets/layout/app_page.dart';

/// Account and app settings, shared by both roles.
class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  Future<void> _signOut(BuildContext context) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Sign out?',
      message: 'You will need your password to sign back in.',
      confirmLabel: 'Sign out',
      icon: Icons.logout_rounded,
    );
    if (!confirmed || !context.mounted) return;
    await context.read<SessionController>().signOut();
  }

  Future<void> _resetDemoData(BuildContext context) async {
    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Reset demo data?',
      message:
          'Every class, student, attendance record and mark on this device is '
          'deleted and the sample dataset is restored. You will be signed out.',
      confirmLabel: 'Reset everything',
      isDestructive: true,
      icon: Icons.restart_alt_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final AppDependencies deps = context.read<AppDependencies>();
    final SessionController session = context.read<SessionController>();
    await withBlockingProgress(
      context,
      message: 'Restoring demo data…',
      () => deps.resetDemoData(),
    );
    await session.signOut();
    if (!context.mounted) return;
    context.showSuccess('Demo data restored. Sign in again to continue.');
  }

  Future<void> _pickTheme(BuildContext context) async {
    final AppSettingsController settings = context.read<AppSettingsController>();
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Appearance',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final ThemeMode mode in ThemeMode.values)
              ListTile(
                leading: Icon(switch (mode) {
                  ThemeMode.system => Icons.brightness_auto_rounded,
                  ThemeMode.light => Icons.light_mode_rounded,
                  ThemeMode.dark => Icons.dark_mode_rounded,
                }),
                title: Text(switch (mode) {
                  ThemeMode.system => 'Match device',
                  ThemeMode.light => 'Light',
                  ThemeMode.dark => 'Dark',
                }),
                trailing: settings.themeMode == mode
                    ? Icon(Icons.check_rounded, color: sheetContext.colors.primary)
                    : null,
                onTap: () {
                  settings.setThemeMode(mode);
                  Navigator.of(sheetContext).pop();
                },
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();
    final AppSettingsController settings = context.watch<AppSettingsController>();
    final AppUser? user = session.user;
    final Organization? organization = session.organization;

    if (user == null) {
      return const Scaffold(body: SizedBox.shrink());
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SafeArea(
        bottom: false,
        child: AppPageBody(
          children: <Widget>[
            _ProfileHeaderCard(user: user, organization: organization),
            const Gap.xl(),
            SectionCard(
              title: 'Account',
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: <Widget>[
                  _SettingsTile(
                    icon: Icons.person_outline_rounded,
                    title: 'Edit profile',
                    subtitle: 'Name, username, phone and title',
                    onTap: () =>
                        Navigator.of(context).pushNamed(Routes.editProfile),
                  ),
                  _SettingsTile(
                    icon: Icons.lock_outline_rounded,
                    title: 'Change password',
                    onTap: () =>
                        Navigator.of(context).pushNamed(Routes.changePassword),
                  ),
                  _SettingsTile(
                    icon: Icons.notifications_none_rounded,
                    title: 'Notifications',
                    subtitle: 'In-app alerts and guardian message outbox',
                    onTap: () =>
                        Navigator.of(context).pushNamed(Routes.notifications),
                  ),
                ],
              ),
            ),
            const Gap.xl(),
            SectionCard(
              title: 'Preferences',
              padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
              child: Column(
                children: <Widget>[
                  _SettingsTile(
                    icon: Icons.palette_outlined,
                    title: 'Appearance',
                    subtitle: settings.themeModeLabel,
                    onTap: () => _pickTheme(context),
                  ),
                  _SettingsTile(
                    icon: Icons.chat_outlined,
                    title: 'Messaging',
                    subtitle: 'How absence notices reach parents',
                    onTap: () => Navigator.of(context)
                        .pushNamed(Routes.messagingSettings),
                  ),
                  _SettingsTile(
                    icon: Icons.grade_outlined,
                    title: 'Grading scale',
                    subtitle: user.isOrgAdmin
                        ? 'Configure grades for your organization'
                        : 'View the grading scale used for your classes',
                    onTap: () =>
                        Navigator.of(context).pushNamed(Routes.gradeScale),
                  ),
                  _SettingsTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About ${AppConstants.appName}',
                    subtitle: 'Version ${AppConstants.appVersion}',
                    onTap: () => Navigator.of(context).pushNamed(Routes.about),
                  ),
                ],
              ),
            ),
            // Offline builds only. Against the shared database there is no demo
            // data to restore, and offering to "reset" would read as an offer
            // to wipe the teacher's real classes.
            if (context.read<AppDependencies>().backend == AppBackend.local) ...<Widget>[
              const Gap.xl(),
              SectionCard(
                title: 'Developer',
                subtitle: 'This build runs entirely on this device',
                padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                child: _SettingsTile(
                  icon: Icons.restart_alt_rounded,
                  title: 'Reset demo data',
                  subtitle: 'Restore the sample classes and students',
                  onTap: () => _resetDemoData(context),
                ),
              ),
            ],
            const Gap.xl(),
            OutlinedButton.icon(
              onPressed: () => _signOut(context),
              icon: Icon(Icons.logout_rounded, color: context.semantic.danger),
              label: Text(
                'Sign out',
                style: TextStyle(color: context.semantic.danger),
              ),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                  color: context.semantic.danger.withValues(alpha: 0.4),
                ),
              ),
            ),
            const Gap.xxl(),
            Center(
              child: Text(
                '${AppConstants.appName} ${AppConstants.appVersion}',
                style: context.text.labelSmall
                    ?.copyWith(color: context.semantic.mutedText),
              ),
            ),
            const Gap.xxl(),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeaderCard extends StatelessWidget {
  const _ProfileHeaderCard({required this.user, this.organization});

  final AppUser user;
  final Organization? organization;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(name: user.displayName, seed: user.id, size: 62),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      user.displayName,
                      style: context.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      user.email,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        AppBadge(
                          user.role.label,
                          tone: BadgeTone.brand,
                          dense: true,
                        ),
                        if (organization != null)
                          AppBadge(
                            organization!.name,
                            tone: BadgeTone.info,
                            icon: Icons.apartment_rounded,
                            dense: true,
                          )
                        else if (user.isTeacher)
                          const AppBadge('Individual teacher', dense: true),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (user.title != null || user.phone != null) ...<Widget>[
            const Gap.lg(),
            if (user.title != null)
              DetailRow(
                label: 'Title',
                value: user.title!,
                icon: Icons.badge_outlined,
              ),
            if (user.phone != null)
              DetailRow(
                label: 'Phone',
                value: user.phone!,
                icon: Icons.phone_outlined,
              ),
          ],
          const Gap.md(),
          DetailRow(
            label: 'Member since',
            value: AppDate.format(user.createdAt),
            icon: Icons.calendar_today_outlined,
          ),
          // City rather than a join code: teachers arrive through a tokenised
          // invitation, so showing a "code" would imply a way in that does not
          // exist.
          if (organization?.city != null)
            DetailRow(
              label: 'City',
              value: organization!.city!,
              icon: Icons.location_city_rounded,
            ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: AppSpacing.xs),
      leading: Container(
        width: 38,
        height: 38,
        decoration: BoxDecoration(
          color: context.colors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, size: 19, color: context.semantic.mutedText),
      ),
      title: Text(title, style: context.text.titleSmall),
      subtitle: subtitle == null
          ? null
          : Text(
              subtitle!,
              style: context.text.bodySmall
                  ?.copyWith(color: context.semantic.mutedText),
            ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.semantic.mutedText,
      ),
      onTap: onTap,
    );
  }
}
