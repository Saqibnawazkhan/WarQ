import 'package:flutter/material.dart';

import '../../presentation/screens/auth/forgot_password_screen.dart';
import '../../presentation/screens/auth/login_screen.dart';
import '../../presentation/screens/auth/register_screen.dart';
import '../../presentation/screens/notifications/notifications_screen.dart';
import '../../presentation/screens/org_admin/activity/org_activity_screen.dart';
import '../../presentation/screens/org_admin/classes/org_class_detail_screen.dart';
import '../../presentation/screens/org_admin/org_admin_shell.dart';
import '../../presentation/screens/org_admin/teachers/invitations_screen.dart';
import '../../presentation/screens/org_admin/teachers/invite_teacher_screen.dart';
import '../../presentation/screens/org_admin/teachers/teacher_detail_screen.dart';
import '../../presentation/screens/profile/change_password_screen.dart';
import '../../presentation/screens/profile/edit_profile_screen.dart';
import '../../presentation/screens/reports/report_preview_screen.dart';
import '../../presentation/screens/reports/reports_screen.dart';
import '../../presentation/screens/settings/about_screen.dart';
import '../../presentation/screens/settings/grade_scale_screen.dart';
import '../../presentation/screens/settings/messaging_settings_screen.dart';
import '../../presentation/screens/teacher/assessments/assessment_form_screen.dart';
import '../../presentation/screens/teacher/assessments/assessment_marks_screen.dart';
import '../../presentation/screens/teacher/attendance/attendance_history_screen.dart';
import '../../presentation/screens/teacher/attendance/mark_attendance_screen.dart';
import '../../presentation/screens/teacher/classes/class_detail_screen.dart';
import '../../presentation/screens/teacher/classes/class_form_screen.dart';
import '../../presentation/screens/teacher/students/enroll_students_screen.dart';
import '../../presentation/screens/teacher/students/student_detail_screen.dart';
import '../../presentation/screens/teacher/students/student_form_screen.dart';
import '../../presentation/screens/teacher/students/student_search_screen.dart';
import '../../presentation/screens/teacher/teacher_shell.dart';
import 'route_args.dart';
import 'route_names.dart';

/// Central route table.
///
/// Every destination is registered here so the navigation graph can be read in
/// one place. Arguments are typed (see `route_args.dart`) and validated before
/// the screen is built, which turns a bad push into a readable error page
/// rather than a runtime cast exception.
class AppRouter {
  const AppRouter._();

  static Route<dynamic>? onGenerateRoute(RouteSettings settings) {
    switch (settings.name) {
      // ----------------------------------------------------------- auth
      case Routes.login:
        return _page(settings, const LoginScreen());
      case Routes.register:
        return _page(settings, const RegisterScreen());
      case Routes.forgotPassword:
        return _page(settings, const ForgotPasswordScreen());

      // ---------------------------------------------------------- shells
      case Routes.teacherHome:
        return _page(settings, const TeacherShell());
      case Routes.orgAdminHome:
        return _page(settings, const OrgAdminShell());

      // --------------------------------------------------------- classes
      case Routes.classForm:
        return _page(
          settings,
          ClassFormScreen(
            args: _argsOr<ClassFormArgs>(settings, const ClassFormArgs()),
          ),
        );
      case Routes.classDetail:
        return _required<ClassDetailArgs>(
          settings,
          (ClassDetailArgs args) => ClassDetailScreen(args: args),
        );

      // -------------------------------------------------------- students
      case Routes.studentForm:
        return _required<StudentFormArgs>(
          settings,
          (StudentFormArgs args) => StudentFormScreen(args: args),
        );
      case Routes.studentDetail:
        return _required<StudentDetailArgs>(
          settings,
          (StudentDetailArgs args) => StudentDetailScreen(args: args),
        );
      case Routes.studentSearch:
        return _page(settings, const StudentSearchScreen());
      case Routes.enrollExisting:
        return _required<EnrollStudentsArgs>(
          settings,
          (EnrollStudentsArgs args) => EnrollStudentsScreen(args: args),
        );

      // ------------------------------------------------------ attendance
      case Routes.markAttendance:
        return _required<MarkAttendanceArgs>(
          settings,
          (MarkAttendanceArgs args) => MarkAttendanceScreen(args: args),
        );
      case Routes.attendanceHistory:
        return _page(
          settings,
          AttendanceHistoryScreen(
            args: _argsOr<AttendanceHistoryArgs>(
              settings,
              const AttendanceHistoryArgs(),
            ),
          ),
        );

      // ----------------------------------------------------- assessments
      case Routes.assessmentForm:
        return _required<AssessmentFormArgs>(
          settings,
          (AssessmentFormArgs args) => AssessmentFormScreen(args: args),
        );
      case Routes.assessmentMarks:
      case Routes.assessmentDetail:
        return _required<AssessmentMarksArgs>(
          settings,
          (AssessmentMarksArgs args) => AssessmentMarksScreen(args: args),
        );

      // --------------------------------------------------------- reports
      case Routes.reports:
        return _page(settings, const ReportsScreen());
      case Routes.reportPreview:
        return _required<ReportPreviewArgs>(
          settings,
          (ReportPreviewArgs args) => ReportPreviewScreen(args: args),
        );

      // ---------------------------------------------------------- shared
      case Routes.notifications:
      case Routes.messageOutbox:
        return _page(settings, const NotificationsScreen());
      case Routes.editProfile:
        return _page(settings, const EditProfileScreen());
      case Routes.changePassword:
        return _page(settings, const ChangePasswordScreen());
      case Routes.gradeScale:
        return _page(settings, const GradeScaleScreen());
      case Routes.messagingSettings:
        return _page(settings, const MessagingSettingsScreen());
      case Routes.about:
        return _page(settings, const AboutScreen());

      // ------------------------------------------------ organization admin
      case Routes.orgTeacherDetail:
        return _required<TeacherDetailArgs>(
          settings,
          (TeacherDetailArgs args) => TeacherDetailScreen(args: args),
        );
      case Routes.orgInviteTeacher:
        return _page(
          settings,
          InviteTeacherScreen(
            args: _argsOr<InviteTeacherArgs>(
              settings,
              const InviteTeacherArgs(),
            ),
          ),
        );
      case Routes.orgInvitations:
        return _page(settings, const InvitationsScreen());
      case Routes.orgClassDetail:
        return _required<ClassDetailArgs>(
          settings,
          (ClassDetailArgs args) => OrgClassDetailScreen(args: args),
        );
      case Routes.orgStudentDetail:
        return _required<StudentDetailArgs>(
          settings,
          (StudentDetailArgs args) =>
              StudentDetailScreen(args: args, readOnly: true),
        );
      case Routes.orgActivity:
        return _page(settings, const OrgActivityScreen());

      default:
        return null;
    }
  }

  /// Fallback for an unknown route, which should only happen after a typo in a
  /// `pushNamed` call.
  static Route<dynamic> onUnknownRoute(RouteSettings settings) {
    return _page(
      settings,
      _RouteErrorScreen(
        title: 'Page not found',
        message: 'No screen is registered for "${settings.name}".',
      ),
    );
  }

  static MaterialPageRoute<T> _page<T>(RouteSettings settings, Widget child) {
    return MaterialPageRoute<T>(settings: settings, builder: (_) => child);
  }

  static T _argsOr<T>(RouteSettings settings, T fallback) {
    final Object? args = settings.arguments;
    return args is T ? args : fallback;
  }

  /// Builds [builder] when the arguments are of the expected type, otherwise
  /// shows an explanatory page instead of crashing.
  static Route<dynamic> _required<T>(
    RouteSettings settings,
    Widget Function(T args) builder,
  ) {
    final Object? args = settings.arguments;
    if (args is T) return _page(settings, builder(args));
    return _page(
      settings,
      _RouteErrorScreen(
        title: 'Missing details',
        message: 'This screen needs $T to open. Go back and try again.',
      ),
    );
  }
}

class _RouteErrorScreen extends StatelessWidget {
  const _RouteErrorScreen({required this.title, required this.message});

  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                Icons.help_outline_rounded,
                size: 44,
                color: Theme.of(context).colorScheme.outline,
              ),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () => Navigator.of(context).maybePop(),
                child: const Text('Go back'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
