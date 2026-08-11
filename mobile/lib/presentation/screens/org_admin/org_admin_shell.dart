import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../app/app_dependencies.dart';
import '../../../data/models/models.dart';
import '../../state/org_admin_controller.dart';
import '../../state/session_controller.dart';
import '../profile/profile_screen.dart';
import 'activity/org_activity_screen.dart';
import 'classes/org_classes_tab.dart';
import 'dashboard/org_dashboard_screen.dart';
import 'reports/org_reports_tab.dart';
import 'teachers/org_teachers_tab.dart';

/// The pages of the organization admin app.
///
/// The bar draws [barDestinations] only. Reports keeps its page and is reached
/// from the dashboard's quick actions; Profile keeps its page and is reached
/// from the dashboard header.
enum OrgTab {
  dashboard,
  teachers,
  classes,
  activity,
  reports,
  profile;

  String get label => switch (this) {
        OrgTab.dashboard => 'Dashboard',
        OrgTab.teachers => 'Teachers',
        OrgTab.classes => 'Classes',
        OrgTab.activity => 'Activity',
        OrgTab.reports => 'Reports',
        OrgTab.profile => 'Profile',
      };

  IconData get icon => switch (this) {
        OrgTab.dashboard => Icons.dashboard_outlined,
        OrgTab.teachers => Icons.groups_outlined,
        OrgTab.classes => Icons.class_outlined,
        OrgTab.activity => Icons.history_outlined,
        OrgTab.reports => Icons.insights_outlined,
        OrgTab.profile => Icons.person_outline_rounded,
      };

  IconData get selectedIcon => switch (this) {
        OrgTab.dashboard => Icons.dashboard_rounded,
        OrgTab.teachers => Icons.groups_rounded,
        OrgTab.classes => Icons.class_rounded,
        OrgTab.activity => Icons.history_rounded,
        OrgTab.reports => Icons.insights_rounded,
        OrgTab.profile => Icons.person_rounded,
      };

  /// The four destinations the bar carries.
  static const List<OrgTab> barDestinations = <OrgTab>[
    OrgTab.dashboard,
    OrgTab.teachers,
    OrgTab.classes,
    OrgTab.activity,
  ];
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

  /// The activity log is the one page built on demand.
  ///
  /// It is new to the shell and fetches its own 200-row history from
  /// `initState`, so building it alongside the others would add a query to app
  /// start that the app never used to make. Every other page was built up front
  /// before the bar changed and still is, which is what keeps the classes tab's
  /// per-class figures loaded by the time the tab is tapped.
  bool _activityOpened = false;

  void _goToTab(OrgTab tab) {
    if (_current == tab) return;
    setState(() {
      _current = tab;
      if (tab == OrgTab.activity) _activityOpened = true;
    });
  }

  /// Reports and Profile are off the bar, so nothing there is highlighted while
  /// one of them is open — the bar falls back to the dashboard rather than
  /// being handed an index it has no destination for.
  int get _selectedIndex {
    final int index = OrgTab.barDestinations.indexOf(_current);
    return index < 0 ? 0 : index;
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
            // Ordered to match [OrgTab]'s declaration, which is what indexes it.
            body: IndexedStack(
              index: _current.index,
              children: <Widget>[
                const OrgDashboardScreen(),
                const OrgTeachersTab(),
                const OrgClassesTab(),
                if (_activityOpened)
                  const OrgActivityScreen()
                else
                  const SizedBox.shrink(),
                const OrgReportsTab(),
                const ProfileScreen(),
              ],
            ),
            bottomNavigationBar: NavigationBar(
              selectedIndex: _selectedIndex,
              onDestinationSelected: (int index) =>
                  _goToTab(OrgTab.barDestinations[index]),
              destinations: <NavigationDestination>[
                for (final OrgTab tab in OrgTab.barDestinations)
                  NavigationDestination(
                    icon: Icon(tab.icon),
                    selectedIcon: Icon(tab.selectedIcon),
                    label: tab.label,
                    tooltip: tab.label,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
