import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../data/models/models.dart';
import '../presentation/screens/auth/login_screen.dart';
import '../presentation/screens/org_admin/org_admin_shell.dart';
import '../presentation/screens/splash/splash_screen.dart';
import '../presentation/screens/teacher/teacher_shell.dart';
import '../presentation/state/session_controller.dart';

/// Chooses what the app shows based on the session.
///
/// Splash while the stored session is restored, the sign-in screen when nobody
/// is authenticated, and the shell matching the user's role afterwards. This is
/// the single place role-based navigation is decided.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    final SessionController session = context.watch<SessionController>();

    if (!session.isBootstrapped) {
      return const SplashScreen(message: 'Getting things ready…');
    }

    final AppUser? user = session.user;
    if (user == null) {
      return const LoginScreen();
    }

    return switch (user.role) {
      UserRole.teacher => const TeacherShell(),
      UserRole.orgAdmin => const OrgAdminShell(),
      // The platform admin console is web-only (Phase 2); the mobile app never
      // signs such an account in, but the branch keeps the switch exhaustive.
      UserRole.mainAdmin => const _UnsupportedRoleScreen(),
    };
  }
}

class _UnsupportedRoleScreen extends StatelessWidget {
  const _UnsupportedRoleScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.desktop_windows_outlined,
                size: 44,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                'Platform admin accounts sign in through the web dashboard.',
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => context.read<SessionController>().signOut(),
                child: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
