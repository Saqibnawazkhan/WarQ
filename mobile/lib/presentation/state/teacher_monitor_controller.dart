import '../../app/app_dependencies.dart';
import '../../core/error/failure.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../domain/entities/dashboard_data.dart';
import 'base_controller.dart';

/// Backs the organization admin's read-only view of one teacher.
///
/// Access is checked against the admin's own organization on every load, so a
/// stale route argument cannot leak another organization's data.
class TeacherMonitorController extends BaseController {
  TeacherMonitorController(this._deps, this._admin, this.teacherId) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.users,
      DataEntity.classes,
      DataEntity.enrollments,
      DataEntity.attendance,
      DataEntity.assessments,
      DataEntity.marks,
      DataEntity.activity,
    });
  }

  final AppDependencies _deps;
  final AppUser _admin;
  final String teacherId;

  TeacherSnapshot? _snapshot;
  List<ActivityLog> _activity = const <ActivityLog>[];

  TeacherSnapshot? get snapshot => _snapshot;
  AppUser? get teacher => _snapshot?.teacher;
  List<ActivityLog> get activity => _activity;
  List<ClassSummary> get classes => _snapshot?.classes ?? const <ClassSummary>[];

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        final String? organizationId = _admin.organizationId;
        if (organizationId == null) {
          throw const AppFailure.unauthorized(
            'Your account is not linked to an organization.',
          );
        }

        final List<AppUser> members =
            await _deps.organizations.members(organizationId);
        AppUser? target;
        for (final AppUser member in members) {
          if (member.id == teacherId) {
            target = member;
            break;
          }
        }

        if (target == null) {
          throw const AppFailure.unauthorized(
            'That teacher is not part of your organization.',
          );
        }

        _snapshot = await _deps.analytics.teacherSnapshot(target, detailed: true);
        _activity = await _deps.activity.listForOrganization(
          organizationId,
          limit: 30,
          actorUserId: teacherId,
        );
      },
      refreshing: refreshing,
    );
  }

  Future<bool> removeFromOrganization() async {
    final String? organizationId = _admin.organizationId;
    if (organizationId == null) return false;
    final bool? ok = await guardAction<bool>(() async {
      await _deps.organizations.removeTeacher(
        organizationId: organizationId,
        teacherId: teacherId,
        actorUserId: _admin.id,
      );
      return true;
    });
    return ok ?? false;
  }
}
