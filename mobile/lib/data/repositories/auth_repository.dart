import '../models/models.dart';

/// Result of a successful password-reset request.
///
/// Phase 1 has no mail server, so the generated code is returned to the caller
/// and displayed in-app. A production build returns only [deliveredTo] and the
/// code travels by email/SMS instead.
class PasswordResetTicket {
  const PasswordResetTicket({
    required this.deliveredTo,
    required this.code,
    required this.expiresAt,
  });

  final String deliveredTo;
  final String code;
  final DateTime expiresAt;
}

/// Authentication and account management.
///
/// Phase 1 authenticates against on-device credentials. The contract is
/// deliberately identical to what a token-based backend would expose, so the
/// Phase 2 implementation only has to replace the body of each method.
abstract class AuthRepository {
  /// Restores a persisted session, or `null` when nobody is signed in.
  Future<AppUser?> restoreSession();

  /// [identifier] accepts either an email address or a username.
  Future<AppUser> signIn({
    required String identifier,
    required String password,
  });

  /// Creates an individual teacher account. If a pending organization
  /// invitation matches [email], the new account joins that organization.
  Future<AppUser> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    String? username,
    String? phone,
  });

  /// Creates an organization plus its first admin account.
  ///
  /// [city] is required by the shared database, which uses it for the platform
  /// admin's search across institutions.
  Future<AppUser> registerOrganization({
    required String fullName,
    required String email,
    required String password,
    required String organizationName,
    String? username,
    String? phone,
    String? city,
  });

  Future<void> signOut(AppUser user);

  /// Issues a reset code for [email].
  Future<PasswordResetTicket> requestPasswordReset(String email);

  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  });

  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  });

  Future<AppUser> updateProfile({
    required String userId,
    String? fullName,
    String? username,
    String? phone,
    String? title,
    String? bio,
  });

  Future<bool> isEmailAvailable(String email, {String? excludeUserId});

  Future<bool> isUsernameAvailable(String username, {String? excludeUserId});

  /// Deletes the signed-in account and everything it owns.
  Future<void> deleteAccount(String userId);
}
