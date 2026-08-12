import 'package:flutter/material.dart';

import 'assessments/assessments_tab.dart';
import 'attendance/attendance_tab.dart';
import 'classes/classes_tab.dart';
import 'dashboard/teacher_dashboard_screen.dart';
import '../profile/profile_screen.dart';
import '../../widgets/layout/floating_nav_bar.dart';

/// The five destinations of the teacher app.
enum TeacherTab {
  dashboard,
  classes,
  attendance,
  assessments,
  profile;

  String get label => switch (this) {
        TeacherTab.dashboard => 'Home',
        TeacherTab.classes => 'Classes',
        TeacherTab.attendance => 'Attendance',
        // Still "Marks" even though only one label shows at a time: five
        // destinations plus the expanded pill leaves about 90dp for the word,
        // and "Assessments" wants more than that — it was painted over the
        // Profile icon when tried. "Marks" is what a teacher calls it anyway;
        // the screen itself still says Assessments.
        TeacherTab.assessments => 'Marks',
        TeacherTab.profile => 'Profile',
      };

  IconData get icon => switch (this) {
        TeacherTab.dashboard => Icons.dashboard_outlined,
        TeacherTab.classes => Icons.class_outlined,
        TeacherTab.attendance => Icons.how_to_reg_outlined,
        TeacherTab.assessments => Icons.assignment_outlined,
        TeacherTab.profile => Icons.person_outline_rounded,
      };

  IconData get selectedIcon => switch (this) {
        TeacherTab.dashboard => Icons.dashboard_rounded,
        TeacherTab.classes => Icons.class_rounded,
        TeacherTab.attendance => Icons.how_to_reg_rounded,
        TeacherTab.assessments => Icons.assignment_rounded,
        TeacherTab.profile => Icons.person_rounded,
      };
}

/// Lets descendants switch tabs — the dashboard's quick actions use it.
class TeacherShellScope extends InheritedWidget {
  const TeacherShellScope({
    super.key,
    required this.goToTab,
    required this.currentTab,
    required super.child,
  });

  final void Function(TeacherTab tab) goToTab;
  final TeacherTab currentTab;

  static TeacherShellScope? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<TeacherShellScope>();

  @override
  bool updateShouldNotify(TeacherShellScope oldWidget) =>
      oldWidget.currentTab != currentTab;
}

/// Bottom-navigation host for the teacher experience.
///
/// Tabs are kept alive in an [IndexedStack] so scroll position and in-progress
/// filters survive switching, which matters when a teacher hops between
/// attendance and the roster.
class TeacherShell extends StatefulWidget {
  const TeacherShell({super.key, this.initialTab = TeacherTab.dashboard});

  final TeacherTab initialTab;

  @override
  State<TeacherShell> createState() => _TeacherShellState();
}

class _TeacherShellState extends State<TeacherShell> {
  late TeacherTab _current = widget.initialTab;

  void _goToTab(TeacherTab tab) {
    if (_current == tab) return;
    setState(() => _current = tab);
  }

  @override
  Widget build(BuildContext context) {
    return TeacherShellScope(
      goToTab: _goToTab,
      currentTab: _current,
      child: PopScope(
        // Back from a secondary tab returns home rather than exiting the app.
        canPop: _current == TeacherTab.dashboard,
        onPopInvokedWithResult: (bool didPop, Object? result) {
          if (!didPop) _goToTab(TeacherTab.dashboard);
        },
        child: Scaffold(
          body: IndexedStack(
            index: _current.index,
            children: const <Widget>[
              TeacherDashboardScreen(),
              ClassesTab(),
              AttendanceTab(),
              AssessmentsTab(),
              ProfileScreen(),
            ],
          ),
          // Floats clear of the screen edge, and shows only the selected
          // destination's label. See FloatingNavBar for why.
          extendBody: true,
          bottomNavigationBar: FloatingNavBar(
            currentIndex: _current.index,
            onSelect: (int index) => _goToTab(TeacherTab.values[index]),
            items: <NavItem>[
              for (final TeacherTab tab in TeacherTab.values)
                NavItem(
                  icon: tab.icon,
                  selectedIcon: tab.selectedIcon,
                  label: tab.label,
                ),
            ],
          ),
        ),
      ),
    );
  }
}
