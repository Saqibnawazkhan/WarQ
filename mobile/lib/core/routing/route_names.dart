/// Named routes for the whole application.
///
/// Keeping them in one place makes the navigation graph auditable and avoids
/// magic strings scattered through the widget tree.
class Routes {
  const Routes._();

  // Bootstrap + auth
  static const String splash = '/';
  static const String login = '/login';
  static const String register = '/register';
  static const String forgotPassword = '/forgot-password';

  // Role shells
  static const String teacherHome = '/teacher';
  static const String orgAdminHome = '/org';

  // Classes
  static const String classForm = '/teacher/classes/form';
  static const String classDetail = '/teacher/classes/detail';

  // Students
  static const String studentForm = '/teacher/students/form';
  static const String studentDetail = '/teacher/students/detail';
  static const String studentSearch = '/teacher/students/search';
  static const String enrollExisting = '/teacher/students/enroll';

  // Attendance
  static const String markAttendance = '/teacher/attendance/mark';
  static const String attendanceHistory = '/teacher/attendance/history';
  static const String attendanceSessionDetail = '/teacher/attendance/session';

  // Assessments
  static const String assessmentForm = '/teacher/assessments/form';
  static const String assessmentDetail = '/teacher/assessments/detail';
  static const String assessmentMarks = '/teacher/assessments/marks';

  // Reports
  static const String reports = '/teacher/reports';
  static const String reportPreview = '/reports/preview';

  // Shared
  static const String notifications = '/notifications';
  static const String messageOutbox = '/notifications/outbox';
  static const String editProfile = '/profile/edit';
  static const String changePassword = '/profile/password';
  static const String gradeScale = '/settings/grade-scale';
  static const String messagingSettings = '/settings/messaging';
  static const String about = '/settings/about';

  // Organisation admin
  static const String orgTeacherDetail = '/org/teachers/detail';
  static const String orgInviteTeacher = '/org/teachers/invite';
  static const String orgInvitations = '/org/teachers/invitations';
  static const String orgClassDetail = '/org/classes/detail';
  static const String orgStudentDetail = '/org/students/detail';
  static const String orgActivity = '/org/activity';
}
