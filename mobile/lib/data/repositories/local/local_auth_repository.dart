import 'dart:convert';

import '../../../core/constants/app_constants.dart';
import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../../core/utils/json_utils.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../local/password_hasher.dart';
import '../../models/models.dart';
import '../activity_repository.dart';
import '../auth_repository.dart';
import '../notification_repository.dart';

/// On-device implementation of [AuthRepository].
class LocalAuthRepository implements AuthRepository {
  LocalAuthRepository(
    this._db, {
    required ActivityRepository activity,
    required NotificationRepository notifications,
  })  : _activity = activity,
        _notifications = notifications;

  final LocalDatabase _db;
  final ActivityRepository _activity;
  final NotificationRepository _notifications;

  @override
  Future<AppUser?> restoreSession() async {
    final String? raw = await _db.store.read(StorageKeys.session);
    if (raw == null || raw.isEmpty) return null;
    try {
      final Object? decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final AuthSession session = AuthSession.fromJson(Json.normalize(decoded));
      final AppUser? user = _db.users.byId(session.userId);
      if (user == null) {
        await _db.store.delete(StorageKeys.session);
        return null;
      }
      if (!user.status.canSignIn || !user.role.canUseMobileApp) {
        await _db.store.delete(StorageKeys.session);
        return null;
      }
      return user;
    } catch (_) {
      await _db.store.delete(StorageKeys.session);
      return null;
    }
  }

  @override
  Future<AppUser> signIn({
    required String identifier,
    required String password,
  }) async {
    final String needle = identifier.trim().toLowerCase();
    if (needle.isEmpty) {
      throw const AppFailure.validation('Enter your email or username.');
    }

    final AuthCredential? credential = _db.credentials.firstWhereOrNull(
      (AuthCredential c) => c.email == needle || c.username == needle,
    );

    // Same message for unknown account and wrong password so the login screen
    // does not confirm which emails are registered.
    const AppFailure invalid = AppFailure(
      'Incorrect email or password. Please try again.',
      code: FailureCode.unauthorized,
    );

    if (credential == null) throw invalid;
    if (!PasswordHasher.verify(password, credential.salt, credential.passwordHash)) {
      throw invalid;
    }

    final AppUser? user = _db.users.byId(credential.userId);
    if (user == null) throw invalid;

    if (!user.role.canUseMobileApp) {
      throw const AppFailure.unauthorized(
        'Platform admin accounts sign in through the web dashboard.',
      );
    }
    if (!user.status.canSignIn) {
      throw AppFailure.unauthorized(
        'This account is ${user.status.label.toLowerCase()}. Contact your administrator.',
      );
    }

    final AppUser signedIn = user.copyWith(lastLoginAt: DateTime.now());
    await _db.users.put(signedIn);
    await _persistSession(signedIn);
    _db.bus.emit(DataEntity.users, id: signedIn.id);

    await _activity.record(
      actorUserId: signedIn.id,
      actorName: signedIn.displayName,
      organizationId: signedIn.organizationId,
      type: ActivityType.signedIn,
      summary: '${signedIn.displayName} signed in',
    );
    return signedIn;
  }

  @override
  Future<AppUser> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    final String normalisedEmail = _normaliseEmail(email);
    final String? normalisedUsername = _normaliseUsername(username);
    await _assertAvailable(normalisedEmail, normalisedUsername);

    // An open invitation for this address auto-joins the organization.
    final Invitation? invite = _db.invitations.firstWhereOrNull(
      (Invitation i) => i.email == normalisedEmail && i.isActionable,
    );

    final AppUser user = AppUser(
      id: IdGenerator.generate('usr'),
      fullName: Format.clean(fullName),
      email: normalisedEmail,
      role: UserRole.teacher,
      createdAt: DateTime.now(),
      username: normalisedUsername,
      phone: Format.cleanOrNull(phone),
      organizationId: invite?.organizationId,
      lastLoginAt: DateTime.now(),
    );

    await _db.users.put(user);
    await _writeCredential(user, password);
    await _persistSession(user);
    _db.bus.emit(DataEntity.users, id: user.id);

    if (invite != null) {
      await _db.invitations.put(
        invite.copyWith(
          status: InvitationStatus.accepted,
          acceptedAt: DateTime.now(),
          acceptedByUserId: user.id,
        ),
      );
      _db.bus.emit(DataEntity.invitations, id: invite.id);

      final Organization? org = _db.organizations.byId(invite.organizationId);
      await _activity.record(
        actorUserId: user.id,
        actorName: user.displayName,
        organizationId: invite.organizationId,
        type: ActivityType.teacherJoined,
        summary: '${user.displayName} joined ${org?.name ?? 'the organization'}',
      );
      await _notifications.create(
        userId: invite.invitedByUserId,
        title: 'Invitation accepted',
        body: '${user.displayName} joined your organization.',
        category: NotificationCategory.invitation,
        organizationId: invite.organizationId,
        relatedEntityType: 'user',
        relatedEntityId: user.id,
      );
    }

    await _notifications.create(
      userId: user.id,
      title: 'Welcome to ${AppConstants.appName}',
      body: invite == null
          ? 'Create your first class to get started.'
          : 'You have joined an organization. Create your first class to get started.',
      category: NotificationCategory.system,
    );

    return user;
  }

  @override
  Future<AppUser> registerOrganization({
    required String fullName,
    required String email,
    required String password,
    required String organizationName,
    String? username,
    String? phone,
  }) async {
    final String normalisedEmail = _normaliseEmail(email);
    final String? normalisedUsername = _normaliseUsername(username);
    await _assertAvailable(normalisedEmail, normalisedUsername);

    final String cleanedOrgName = Format.clean(organizationName);
    if (cleanedOrgName.isEmpty) {
      throw const AppFailure.validation('Organization name is required.');
    }

    final String userId = IdGenerator.generate('usr');
    final Organization organization = Organization(
      id: IdGenerator.generate('org'),
      name: cleanedOrgName,
      joinCode: IdGenerator.code(),
      ownerUserId: userId,
      createdAt: DateTime.now(),
      email: normalisedEmail,
    );

    final AppUser user = AppUser(
      id: userId,
      fullName: Format.clean(fullName),
      email: normalisedEmail,
      role: UserRole.orgAdmin,
      createdAt: DateTime.now(),
      username: normalisedUsername,
      phone: Format.cleanOrNull(phone),
      organizationId: organization.id,
      lastLoginAt: DateTime.now(),
    );

    await _db.organizations.put(organization);
    await _db.users.put(user);
    await _writeCredential(user, password);
    await _persistSession(user);
    _db.bus
      ..emit(DataEntity.organizations, id: organization.id)
      ..emit(DataEntity.users, id: user.id);

    await _notifications.create(
      userId: user.id,
      title: '${organization.name} is ready',
      body: 'Invite your teachers so their classes appear here.',
      category: NotificationCategory.organization,
      organizationId: organization.id,
    );
    return user;
  }

  @override
  Future<void> signOut(AppUser user) async {
    await _activity.record(
      actorUserId: user.id,
      actorName: user.displayName,
      organizationId: user.organizationId,
      type: ActivityType.signedOut,
      summary: '${user.displayName} signed out',
    );
    await _db.store.delete(StorageKeys.session);
  }

  @override
  Future<PasswordResetTicket> requestPasswordReset(String email) async {
    final String normalised = _normaliseEmail(email);
    final AuthCredential? credential = _db.credentials.firstWhereOrNull(
      (AuthCredential c) => c.email == normalised,
    );
    if (credential == null) {
      throw const AppFailure.notFound('An account with that email');
    }

    final DateTime expiresAt = DateTime.now().add(AppConstants.resetCodeValidity);
    final String code = IdGenerator.numericCode();
    await _db.credentials.put(
      credential.copyWith(
        resetCode: code,
        resetCodeExpiresAt: expiresAt,
        updatedAt: DateTime.now(),
      ),
    );
    return PasswordResetTicket(
      deliveredTo: normalised,
      code: code,
      expiresAt: expiresAt,
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final String normalised = _normaliseEmail(email);
    final AuthCredential? credential = _db.credentials.firstWhereOrNull(
      (AuthCredential c) => c.email == normalised,
    );
    if (credential == null) {
      throw const AppFailure.notFound('An account with that email');
    }
    if (!credential.hasValidResetCode) {
      throw const AppFailure.validation(
        'That reset code has expired. Request a new one.',
      );
    }
    if (credential.resetCode != code.trim()) {
      throw const AppFailure.validation('That reset code is not correct.');
    }
    _assertPasswordStrength(newPassword);

    final String salt = PasswordHasher.generateSalt();
    await _db.credentials.put(
      credential.copyWith(
        salt: salt,
        passwordHash: PasswordHasher.hash(newPassword, salt),
        clearResetCode: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final AuthCredential? credential = _db.credentials.byId(userId);
    if (credential == null) throw const AppFailure.notFound('Your account');
    if (!PasswordHasher.verify(
      currentPassword,
      credential.salt,
      credential.passwordHash,
    )) {
      throw const AppFailure.validation('Your current password is not correct.');
    }
    _assertPasswordStrength(newPassword);
    if (PasswordHasher.verify(newPassword, credential.salt, credential.passwordHash)) {
      throw const AppFailure.validation(
        'Choose a password different from your current one.',
      );
    }

    final String salt = PasswordHasher.generateSalt();
    await _db.credentials.put(
      credential.copyWith(
        salt: salt,
        passwordHash: PasswordHasher.hash(newPassword, salt),
        clearResetCode: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  @override
  Future<AppUser> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    String? phone,
    String? title,
    String? bio,
  }) async {
    final AppUser? user = _db.users.byId(userId);
    if (user == null) throw const AppFailure.notFound('Your account');

    final String? normalisedUsername = _normaliseUsername(username);
    if (normalisedUsername != null &&
        normalisedUsername != user.username &&
        !await isUsernameAvailable(normalisedUsername, excludeUserId: userId)) {
      throw const AppFailure.conflict('That username is already taken.');
    }

    final AppUser updated = user.copyWith(
      fullName: fullName == null ? null : Format.clean(fullName),
      username: normalisedUsername,
      clearUsername: username != null && normalisedUsername == null,
      phone: Format.cleanOrNull(phone),
      clearPhone: phone != null && Format.cleanOrNull(phone) == null,
      title: Format.cleanOrNull(title),
      clearTitle: title != null && Format.cleanOrNull(title) == null,
      bio: Format.cleanOrNull(bio),
      clearBio: bio != null && Format.cleanOrNull(bio) == null,
      updatedAt: DateTime.now(),
    );

    await _db.users.put(updated);
    // Keep the credential lookup index aligned with the account.
    final AuthCredential? credential = _db.credentials.byId(userId);
    if (credential != null) {
      await _db.credentials.put(
        credential.copyWith(
          username: updated.username,
          clearUsername: updated.username == null,
          updatedAt: DateTime.now(),
        ),
      );
    }
    _db.bus.emit(DataEntity.users, id: updated.id);

    await _activity.record(
      actorUserId: updated.id,
      actorName: updated.displayName,
      organizationId: updated.organizationId,
      type: ActivityType.profileUpdated,
      summary: '${updated.displayName} updated their profile',
    );
    return updated;
  }

  @override
  Future<bool> isEmailAvailable(String email, {String? excludeUserId}) async {
    final String normalised = _normaliseEmail(email);
    return _db.credentials.firstWhereOrNull((AuthCredential c) =>
            c.email == normalised && c.userId != excludeUserId) ==
        null;
  }

  @override
  Future<bool> isUsernameAvailable(String username, {String? excludeUserId}) async {
    final String? normalised = _normaliseUsername(username);
    if (normalised == null) return true;
    return _db.credentials.firstWhereOrNull((AuthCredential c) =>
            c.username == normalised && c.userId != excludeUserId) ==
        null;
  }

  @override
  Future<void> deleteAccount(String userId) async {
    final List<String> classIds = _db.classes
        .where((SchoolClass c) => c.teacherId == userId)
        .map((SchoolClass c) => c.id)
        .toList(growable: false);

    await _db.attendanceRecords
        .deleteWhere((AttendanceRecord r) => classIds.contains(r.classId));
    await _db.attendanceSessions
        .deleteWhere((AttendanceSession s) => classIds.contains(s.classId));
    await _db.marks.deleteWhere((AssessmentMark m) => classIds.contains(m.classId));
    await _db.assessments
        .deleteWhere((Assessment a) => classIds.contains(a.classId));
    await _db.enrollments
        .deleteWhere((ClassEnrollment e) => classIds.contains(e.classId));
    await _db.classes.deleteWhere((SchoolClass c) => c.teacherId == userId);
    await _db.students.deleteWhere((Student s) => s.ownerTeacherId == userId);
    await _db.notifications.deleteWhere((AppNotification n) => n.userId == userId);
    await _db.credentials.delete(userId);
    await _db.users.delete(userId);
    await _db.store.delete(StorageKeys.session);
    _db.bus.emitAll(DataEntity.values);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<void> _persistSession(AppUser user) async {
    final AuthSession session = AuthSession(
      userId: user.id,
      signedInAt: DateTime.now(),
    );
    await _db.store.write(StorageKeys.session, jsonEncode(session.toJson()));
  }

  Future<void> _writeCredential(AppUser user, String password) async {
    _assertPasswordStrength(password);
    final String salt = PasswordHasher.generateSalt();
    await _db.credentials.put(
      AuthCredential(
        userId: user.id,
        email: user.email,
        username: user.username,
        salt: salt,
        passwordHash: PasswordHasher.hash(password, salt),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _assertAvailable(String email, String? username) async {
    if (!await isEmailAvailable(email)) {
      throw const AppFailure.conflict(
        'An account with that email already exists.',
      );
    }
    if (username != null && !await isUsernameAvailable(username)) {
      throw const AppFailure.conflict('That username is already taken.');
    }
  }

  void _assertPasswordStrength(String password) {
    if (password.length < AppConstants.minPasswordLength) {
      throw AppFailure.validation(
        'Password must be at least ${AppConstants.minPasswordLength} characters.',
      );
    }
  }

  String _normaliseEmail(String email) {
    final String value = email.trim().toLowerCase();
    if (value.isEmpty) throw const AppFailure.validation('Email is required.');
    return value;
  }

  String? _normaliseUsername(String? username) {
    final String value = username?.trim().toLowerCase() ?? '';
    return value.isEmpty ? null : value;
  }
}
