import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../domain/entities/dashboard_data.dart';
import 'base_controller.dart';

/// Backs the teacher home screen.
class TeacherDashboardController extends BaseController {
  TeacherDashboardController(this._deps, this._teacher) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.classes,
      DataEntity.students,
      DataEntity.enrollments,
      DataEntity.attendance,
      DataEntity.assessments,
      DataEntity.marks,
      DataEntity.notifications,
      DataEntity.activity,
    });
  }

  final AppDependencies _deps;
  final AppUser _teacher;

  TeacherDashboardData _data = const TeacherDashboardData.empty();
  int _unreadNotifications = 0;

  TeacherDashboardData get data => _data;
  int get unreadNotifications => _unreadNotifications;
  AppUser get teacher => _teacher;

  /// Greeting that changes with the time of day.
  String get greeting {
    final int hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _data = await _deps.analytics.teacherDashboard(_teacher);
        _unreadNotifications = await _deps.notifications.unreadCount(_teacher.id);
      },
      refreshing: refreshing,
    );
  }
}
