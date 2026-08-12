import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../data/models/models.dart';
import '../../state/org_admin_controller.dart';
import '../../state/session_controller.dart';
import '../../widgets/layout/floating_nav_bar.dart';
import '../profile/profile_screen.dart';
import 'classes/org_classes_tab.dart';
import 'dashboard/org_dashboard_screen.dart';
import 'reports/org_reports_tab.dart';
import 'teachers/org_teachers_tab.dart';

/// The five destinations of the organization admin app.
enum OrgTab {
  dashboard,
  teachers,
  classes,
  reports,
  profile;

  String get label => switch (this) {
        OrgTab.dashboard => 'Home',
        OrgTab.teachers => 'Teachers',
        OrgTab.classes => 'Classes',
        OrgTab.reports => 'Reports',
        OrgTab.profile => 'Profile',
      };

  IconData get icon => switch (this) {
        OrgTab.dashboard => Icons.dashboard_outlined,
        OrgTab.teachers => Icons.groups_outlined,
        OrgTab.classes => Icons.class_outlined,
        OrgTab.reports => Icons.insights_outlined,
        OrgTab.profile => Icons.person_outline_rounded,
      };

  IconData get selectedIcon => switch (this) {
        OrgTab.dashboard => Icons.dashboard_rounded,
        OrgTab.teachers => Icons.groups_rounded,
        OrgTab.classes => Icons.class_rounded,
        OrgTab.reports => Icons.insights_rounded,
        OrgTab.profile => Icons.person_rounded,
      };
}

/// Lets descendants switch tabs.
class OrgShellScope extends InheritedWidget {
  const OrgShellScope({
    super.key,
    required this.goToTab,
    required this.currentTab,
    required super.child,
  });

  final void Function(OrgTab tab) goToTab;
  final OrgTab currentTab;

  static OrgShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<OrgShellScope>();

  @override
  bool updateShouldNotify(OrgShellScope oldWidget) =>
      oldWidget.currentTab != currentTab;
}

/// Bottom-navigation host for the organization admin experience.
///
/// One [OrgAdminController] is shared by every tab, so the dashboard, teacher
/// list and class list always agree and only load the organization once.
class OrgAdminShell extends StatefulWidget {
  const OrgAdminShell({super.key});

  @override
  State<OrgAdminShell> createState() => _OrgAdminShellState();
}

class _OrgAdminShellState extends State<OrgAdminShell> {
  OrgTab _current = OrgTab.dashboard;

  void _goToTab(OrgTab tab) {
    if (_current == tab) return;
    setState(() => _current = tab);
  }

  @override
  Widget build(BuildContext context) {
    final AppUser admin = context.read<SessionController>().requireUser;

    return ChangeNotifierProvider<OrgAdminController>(
      create: (BuildContext context) =>
          OrgAdminController(context.read<AppDependencies>(), admin)..load(),
      child: OrgShellScope(
        goToTab: _goToTab,
        currentTab: _current,
        child: PopScope(
          canPop: _current == OrgTab.dashboard,
          onPopInvokedWithResult: (bool didPop, Object? result) {
            if (!didPop) _goToTab(OrgTab.dashboard);
          },
          child: Scaffold(
            body: IndexedStack(
              index: _current.index,
              children: const <Widget>[
                OrgDashboardScreen(),
                OrgTeachersTab(),
                OrgClassesTab(),
                OrgReportsTab(),
                ProfileScreen(),
              ],
            ),
            // The same floating bar the teacher shell uses, so an admin who
            // also teaches does not meet two different navigations.
            extendBody: true,
            bottomNavigationBar: FloatingNavBar(
              currentIndex: _current.index,
              onSelect: (int index) => _goToTab(OrgTab.values[index]),
              items: <NavItem>[
                for (final OrgTab tab in OrgTab.values)
                  NavItem(
                    icon: tab.icon,
                    selectedIcon: tab.selectedIcon,
                    label: tab.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
