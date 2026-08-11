import 'package:flutter/material.dart';

import '../../../core/extensions/context_extensions.dart';
import '../../../core/routing/route_args.dart';
import '../../../core/routing/route_names.dart';
import '../../../core/theme/app_spacing.dart';
import '../../widgets/feedback/dialogs.dart';
import '../profile/profile_screen.dart';
import 'assessments/assessments_tab.dart';
import 'attendance/attendance_tab.dart';
import 'classes/classes_tab.dart';
import 'dashboard/teacher_dashboard_screen.dart';

/// The pages of the teacher app.
///
/// The bar draws [barDestinations] only. [profile] keeps its page and is opened
/// from the compose sheet and from the Home header's avatar, because the bar's
/// middle slot belongs to the compose button rather than to a fifth
/// destination.
enum TeacherTab {
  dashboard,
  classes,
  attendance,
  assessments,
  profile;

  /// The four destinations, two either side of the docked compose button.
  static const List<TeacherTab> barDestinations = <TeacherTab>[
    TeacherTab.dashboard,
    TeacherTab.classes,
    TeacherTab.attendance,
    TeacherTab.assessments,
  ];

  String get label => switch (this) {
        TeacherTab.dashboard => 'Home',
        TeacherTab.classes => 'Classes',
        TeacherTab.attendance => 'Attendance',
        // "Assessments" is one character too long for a fifth of a phone
        // screen at the current label size: it wraps and breaks the bar's
        // alignment. "Marks" is both shorter and what a teacher calls the
        // thing they come here to do; the screen itself still says
        // Assessments.
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

/// Lets descendants switch tabs — the dashboard's quick actions use it, and it
/// is how the Home header opens the profile now that it is off the bar.
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

  /// The compose button gathers the create actions the tabs each offer.
  ///
  /// Only work that needs no class chosen up front can start here: the shell
  /// holds no class list of its own and must not fetch one, so creating an
  /// assessment — which cannot open without a class — stays on the Marks tab.
  Future<void> _openComposeSheet() async {
    await showAppSheet<void>(
      context,
      builder: (BuildContext sheetContext) => AppSheet(
        title: 'Create',
        // Scrollable so the sheet stays usable on a short screen with the
        // system text size turned up.
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              _ComposeOption(
                icon: Icons.add_box_rounded,
                title: 'Create class',
                subtitle: 'A class you teach, with its own roster',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed(Routes.classForm);
                },
              ),
              _ComposeOption(
                icon: Icons.person_add_alt_1_rounded,
                title: 'Add student',
                subtitle: 'Enroll them in a class afterwards',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  Navigator.of(context).pushNamed(
                    Routes.studentForm,
                    arguments: const StudentFormArgs(),
                  );
                },
              ),
              // Profile lost its slot on the bar, and signing out lives nowhere
              // else, so it keeps a door here until the Home header's avatar
              // opens it.
              const Divider(height: AppSpacing.xxl),
              _ComposeOption(
                icon: Icons.person_outline_rounded,
                title: 'Profile & settings',
                subtitle: 'Account, appearance and sign out',
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  _goToTab(TeacherTab.profile);
                },
              ),
            ],
          ),
        ),
      ),
    );
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
          // Round rather than the theme's rounded square: this one is the
          // app's compose button, raised out of the bar, and reads as a button
          // on top of the bar only while it stays a circle.
          floatingActionButton: FloatingActionButton(
            heroTag: 'teacher-compose',
            onPressed: _openComposeSheet,
            tooltip: 'Create',
            shape: const CircleBorder(),
            child: const Icon(Icons.add_rounded),
          ),
          floatingActionButtonLocation:
              FloatingActionButtonLocation.centerDocked,
          bottomNavigationBar: _TeacherNavBar(
            current: _current,
            onSelect: _goToTab,
          ),
        ),
      ),
    );
  }
}

/// The bar itself: four destinations around the docked compose button.
///
/// Five equal cells rather than four, with the middle one left empty. The
/// compose button then sits in a gap exactly one destination wide, and the four
/// labels keep the room they had when the bar carried five of them — which is
/// what "Attendance" needs in order not to wrap.
class _TeacherNavBar extends StatelessWidget {
  const _TeacherNavBar({required this.current, required this.onSelect});

  final TeacherTab current;
  final ValueChanged<TeacherTab> onSelect;

  @override
  Widget build(BuildContext context) {
    final NavigationBarThemeData barTheme = context.theme.navigationBarTheme;
    const List<TeacherTab> tabs = TeacherTab.barDestinations;

    return Material(
      color: barTheme.backgroundColor ?? context.colors.surface,
      child: SafeArea(
        top: false,
        child: SizedBox(
          height: barTheme.height ?? kBottomNavigationBarHeight,
          child: Row(
            children: <Widget>[
              for (int i = 0; i < tabs.length; i++) ...<Widget>[
                if (i == tabs.length ~/ 2) const Spacer(),
                Expanded(
                  child: _NavItem(
                    tab: tabs[i],
                    selected: current == tabs[i],
                    onTap: () => onSelect(tabs[i]),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// One destination, styled from the navigation bar theme rather than from
/// values of its own, so this hand-built bar and the organization admin's plain
/// [NavigationBar] stay the same bar to look at.
class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.tab,
    required this.selected,
    required this.onTap,
  });

  final TeacherTab tab;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final NavigationBarThemeData barTheme = context.theme.navigationBarTheme;
    final Set<WidgetState> states = <WidgetState>{
      if (selected) WidgetState.selected,
    };
    final IconThemeData? iconTheme = barTheme.iconTheme?.resolve(states);
    final TextStyle? labelStyle = barTheme.labelTextStyle?.resolve(states);

    return Semantics(
      selected: selected,
      button: true,
      // The NavigationBar this replaces named every destination on long press.
      // Keeping that is what makes a label ellipsised on a narrow phone
      // recoverable.
      child: Tooltip(
        message: tab.label,
        child: InkWell(
          onTap: onTap,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: selected ? barTheme.indicatorColor : null,
                  borderRadius: BorderRadius.circular(AppRadii.pill),
                ),
                child: Icon(
                  selected ? tab.selectedIcon : tab.icon,
                  size: iconTheme?.size,
                  color: iconTheme?.color ?? context.semantic.mutedText,
                ),
              ),
              const SizedBox(height: AppSpacing.xs),
              // Flexible rather than a plain Text: a teacher who turns the
              // system text size up gets a shorter label rather than a bar that
              // overflows.
              Flexible(
                child: Text(
                  tab.label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: labelStyle,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One row of the compose sheet.
class _ComposeOption extends StatelessWidget {
  const _ComposeOption({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: Container(
        width: 44,
        height: 44,
        decoration: BoxDecoration(
          color: context.colors.primary.withValues(alpha: 0.10),
          borderRadius: BorderRadius.circular(AppRadii.sm),
        ),
        child: Icon(icon, color: context.colors.primary),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: context.text.titleSmall?.copyWith(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        subtitle,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: context.text.bodySmall?.copyWith(color: context.semantic.mutedText),
      ),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: context.semantic.mutedText,
      ),
      onTap: onTap,
    );
  }
}
