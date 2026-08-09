import '../../../core/constants/app_constants.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../activity_repository.dart';
import '../notification_repository.dart';
import '../organization_repository.dart';

/// On-device implementation of [OrganizationRepository].
class LocalOrganizationRepository implements OrganizationRepository {
  LocalOrganizationRepository(
    this._db, {
    required ActivityRepository activity,
    required NotificationRepository notifications,
  })  : _activity = activity,
        _notifications = notifications;

  final LocalDatabase _db;
  final ActivityRepository _activity;
  final NotificationRepository _notifications;

  @override
  Future<Organization?> findById(String organizationId) async =>
      _db.organizations.byId(organizationId);

  @override
  Future<Organization?> findByJoinCode(String joinCode) async {
    final String code = joinCode.trim().toUpperCase();
    if (code.isEmpty) return null;
    return _db.organizations.firstWhereOrNull(
      (Organization o) => o.joinCode.toUpperCase() == code,
    );
  }

  @override
  Future<Organization> update({
    required String organizationId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? website,
  }) async {
    final Organization? existing = _db.organizations.byId(organizationId);
    if (existing == null) throw const AppFailure.notFound('That organization');

    final String? cleanedName = Format.cleanOrNull(name);
    if (name != null && cleanedName == null) {
      throw const AppFailure.validation('Organization name is required.');
    }
    final String? cleanedEmail = Format.cleanOrNull(email)?.toLowerCase();
    final String? cleanedPhone = Format.cleanOrNull(phone);
    final String? cleanedAddress = Format.cleanOrNull(address);
    final String? cleanedWebsite = Format.cleanOrNull(website);

    final Organization updated = existing.copyWith(
      name: cleanedName,
      email: cleanedEmail,
      clearEmail: email != null && cleanedEmail == null,
      phone: cleanedPhone,
      clearPhone: phone != null && cleanedPhone == null,
      address: cleanedAddress,
      clearAddress: address != null && cleanedAddress == null,
      website: cleanedWebsite,
      clearWebsite: website != null && cleanedWebsite == null,
      updatedAt: DateTime.now(),
    );
    await _db.organizations.put(updated);
    _db.bus.emit(DataEntity.organizations, id: organizationId);
    return updated;
  }

  @override
  Future<List<AppUser>> members(String organizationId) async {
    final List<AppUser> items = _db.users
        .where((AppUser u) =>
            u.organizationId == organizationId &&
            u.status != AccountStatus.removed)
        .toList()
      ..sort((AppUser a, AppUser b) =>
          a.displayName.toLowerCase().compareTo(b.displayName.toLowerCase()));
    return items;
  }

  @override
  Future<List<AppUser>> teachers(String organizationId) async {
    final List<AppUser> all = await members(organizationId);
    return all.where((AppUser u) => u.role == UserRole.teacher).toList();
  }

  @override
  Future<Invitation> invite({
    required String organizationId,
    required String email,
    required String invitedByUserId,
    String? inviteeName,
    String? message,
  }) async {
    final Organization? organization = _db.organizations.byId(organizationId);
    if (organization == null) throw const AppFailure.notFound('That organization');

    final String normalised = email.trim().toLowerCase();
    if (normalised.isEmpty) {
      throw const AppFailure.validation('Enter the teacher\'s email address.');
    }

    final AppUser? existingUser =
        _db.users.firstWhereOrNull((AppUser u) => u.email == normalised);
    if (existingUser != null && existingUser.organizationId == organizationId) {
      throw const AppFailure.conflict(
        'That teacher is already part of your organization.',
      );
    }

    final Invitation? open = _db.invitations.firstWhereOrNull((Invitation i) =>
        i.organizationId == organizationId &&
        i.email == normalised &&
        i.isActionable);
    if (open != null) {
      throw const AppFailure.conflict(
        'An invitation for that email is already pending.',
      );
    }

    final Invitation invitation = Invitation(
      id: IdGenerator.generate('inv'),
      organizationId: organizationId,
      email: normalised,
      token: IdGenerator.code(length: 10),
      invitedByUserId: invitedByUserId,
      createdAt: DateTime.now(),
      expiresAt: DateTime.now().add(AppConstants.invitationValidity),
      inviteeName: Format.cleanOrNull(inviteeName),
      message: Format.cleanOrNull(message),
    );

    await _db.invitations.put(invitation);
    _db.bus.emit(DataEntity.invitations, id: invitation.id);

    // A teacher who already has an account gets an in-app notification too.
    if (existingUser != null) {
      await _notifications.create(
        userId: existingUser.id,
        title: 'Invitation to ${organization.name}',
        body: 'You have been invited to join ${organization.name}.',
        category: NotificationCategory.invitation,
        organizationId: organizationId,
        relatedEntityType: 'invitation',
        relatedEntityId: invitation.id,
      );
    }

    await _activity.record(
      actorUserId: invitedByUserId,
      actorName: _db.users.byId(invitedByUserId)?.displayName,
      organizationId: organizationId,
      type: ActivityType.teacherInvited,
      summary: 'Invited $normalised to ${organization.name}',
      entityType: 'invitation',
      entityId: invitation.id,
    );
    return invitation;
  }

  @override
  Future<List<Invitation>> invitations(String organizationId) async {
    final List<Invitation> items = _db.invitations
        .where((Invitation i) => i.organizationId == organizationId)
        .toList()
      ..sort((Invitation a, Invitation b) => b.createdAt.compareTo(a.createdAt));
    return items;
  }

  @override
  Future<Invitation> revokeInvitation(String invitationId) async {
    final Invitation? existing = _db.invitations.byId(invitationId);
    if (existing == null) throw const AppFailure.notFound('That invitation');
    if (existing.status == InvitationStatus.accepted) {
      throw const AppFailure.conflict(
        'That invitation has already been accepted.',
      );
    }

    final Invitation updated =
        existing.copyWith(status: InvitationStatus.revoked);
    await _db.invitations.put(updated);
    _db.bus.emit(DataEntity.invitations, id: invitationId);

    await _activity.record(
      actorUserId: existing.invitedByUserId,
      actorName: _db.users.byId(existing.invitedByUserId)?.displayName,
      organizationId: existing.organizationId,
      type: ActivityType.invitationRevoked,
      summary: 'Revoked the invitation for ${existing.email}',
      entityType: 'invitation',
      entityId: invitationId,
    );
    return updated;
  }

  @override
  Future<Invitation> resendInvitation(String invitationId) async {
    final Invitation? existing = _db.invitations.byId(invitationId);
    if (existing == null) throw const AppFailure.notFound('That invitation');
    if (existing.status == InvitationStatus.accepted) {
      throw const AppFailure.conflict(
        'That invitation has already been accepted.',
      );
    }

    final Invitation updated = existing.copyWith(
      status: InvitationStatus.pending,
      expiresAt: DateTime.now().add(AppConstants.invitationValidity),
    );
    await _db.invitations.put(updated);
    _db.bus.emit(DataEntity.invitations, id: invitationId);
    return updated;
  }

  @override
  Future<void> removeTeacher({
    required String organizationId,
    required String teacherId,
    required String actorUserId,
  }) async {
    final AppUser? teacher = _db.users.byId(teacherId);
    if (teacher == null) throw const AppFailure.notFound('That teacher');
    if (teacher.organizationId != organizationId) {
      throw const AppFailure.unauthorized(
        'That teacher does not belong to your organization.',
      );
    }
    final Organization? organization = _db.organizations.byId(organizationId);
    if (organization != null && organization.ownerUserId == teacherId) {
      throw const AppFailure.conflict(
        'The organization owner cannot be removed.',
      );
    }

    // Detach rather than delete: the teacher keeps their classes, students and
    // history on their own account.
    await _db.users.put(
      teacher.copyWith(clearOrganization: true, updatedAt: DateTime.now()),
    );
    final List<SchoolClass> orphanedClasses = _db.classes
        .where((SchoolClass c) =>
            c.teacherId == teacherId && c.organizationId == organizationId)
        .map((SchoolClass c) => c.copyWith(clearOrganization: true))
        .toList(growable: false);
    if (orphanedClasses.isNotEmpty) {
      await _db.classes.putAll(orphanedClasses);
    }
    final List<Student> orphanedStudents = _db.students
        .where((Student s) =>
            s.ownerTeacherId == teacherId && s.organizationId == organizationId)
        .map((Student s) => s.copyWith(clearOrganization: true))
        .toList(growable: false);
    if (orphanedStudents.isNotEmpty) {
      await _db.students.putAll(orphanedStudents);
    }

    _db.bus.emitAll(<DataEntity>{
      DataEntity.users,
      DataEntity.classes,
      DataEntity.students,
    });

    await _notifications.create(
      userId: teacherId,
      title: 'Removed from ${organization?.name ?? 'your organization'}',
      body: 'Your classes and students remain available on your account.',
      category: NotificationCategory.organization,
    );

    await _activity.record(
      actorUserId: actorUserId,
      actorName: _db.users.byId(actorUserId)?.displayName,
      organizationId: organizationId,
      type: ActivityType.teacherRemoved,
      summary: 'Removed ${teacher.displayName} from '
          '${organization?.name ?? 'the organization'}',
      entityType: 'user',
      entityId: teacherId,
    );
  }

  @override
  Future<Organization> setGradeScale({
    required String organizationId,
    required String gradeScaleId,
  }) async {
    final Organization? existing = _db.organizations.byId(organizationId);
    if (existing == null) throw const AppFailure.notFound('That organization');
    final Organization updated =
        existing.copyWith(gradeScaleId: gradeScaleId, updatedAt: DateTime.now());
    await _db.organizations.put(updated);
    _db.bus.emit(DataEntity.organizations, id: organizationId);
    return updated;
  }
}
