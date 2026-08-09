import '../../app/app_dependencies.dart';
import '../../core/error/failure.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../domain/entities/dashboard_data.dart';
import 'base_controller.dart';

/// Backs the organization admin dashboard, teacher list and invitations.
///
/// Every query is scoped to [organizationId], which is taken from the signed-in
/// admin's account — an admin can never read another organization's data.
class OrgAdminController extends BaseController {
  OrgAdminController(this._deps, this._admin)
      : organizationId = _admin.organizationId ?? '' {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.users,
      DataEntity.organizations,
      DataEntity.classes,
      DataEntity.students,
      DataEntity.enrollments,
      DataEntity.attendance,
      DataEntity.assessments,
      DataEntity.marks,
      DataEntity.invitations,
      DataEntity.activity,
    });
  }

  final AppDependencies _deps;
  final AppUser _admin;
  final String organizationId;

  OrganizationDashboardData? _dashboard;
  List<Invitation> _invitations = const <Invitation>[];
  List<SchoolClass> _classes = const <SchoolClass>[];
  String _teacherQuery = '';

  OrganizationDashboardData? get dashboard => _dashboard;
  Organization? get organization => _dashboard?.organization;
  List<Invitation> get invitations => _invitations;
  List<SchoolClass> get classes => _classes;
  String get teacherQuery => _teacherQuery;
  AppUser get admin => _admin;

  List<TeacherSnapshot> get teachers =>
      _dashboard?.teacherSnapshots ?? const <TeacherSnapshot>[];

  List<TeacherSnapshot> get visibleTeachers {
    final String needle = _teacherQuery.trim().toLowerCase();
    if (needle.isEmpty) return teachers;
    return teachers
        .where((TeacherSnapshot snapshot) =>
            snapshot.teacher.displayName.toLowerCase().contains(needle) ||
            snapshot.teacher.email.toLowerCase().contains(needle))
        .toList(growable: false);
  }

  List<Invitation> get pendingInvitations =>
      _invitations.where((Invitation i) => i.isActionable).toList();

  bool get hasOrganization => organizationId.isNotEmpty;

  @override
  Future<void> load({bool refreshing = false}) async {
    if (!hasOrganization) {
      await guardLoad(
        () async => throw const AppFailure.unauthorized(
          'Your account is not linked to an organization.',
        ),
        refreshing: refreshing,
      );
      return;
    }

    await guardLoad(
      () async {
        _dashboard = await _deps.analytics.organizationDashboard(organizationId);
        _invitations = await _deps.organizations.invitations(organizationId);
        _classes = await _deps.classes.listForOrganization(organizationId);
      },
      refreshing: refreshing,
    );
  }

  void searchTeachers(String value) {
    if (_teacherQuery == value) return;
    _teacherQuery = value;
    safeNotify();
  }

  Future<Invitation?> inviteTeacher({
    required String email,
    String? inviteeName,
    String? message,
  }) {
    return guardAction<Invitation>(
      () => _deps.organizations.invite(
        organizationId: organizationId,
        email: email,
        invitedByUserId: _admin.id,
        inviteeName: inviteeName,
        message: message,
      ),
    );
  }

  Future<bool> revokeInvitation(String invitationId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.organizations.revokeInvitation(invitationId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> resendInvitation(String invitationId) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.organizations.resendInvitation(invitationId);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> removeTeacher(String teacherId) async {
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

  Future<bool> updateOrganization({
    String? name,
    String? email,
    String? phone,
    String? address,
    String? website,
  }) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.organizations.update(
        organizationId: organizationId,
        name: name,
        email: email,
        phone: phone,
        address: address,
        website: website,
      );
      return true;
    });
    return ok ?? false;
  }
}
