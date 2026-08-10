import 'package:supabase_flutter/supabase_flutter.dart' hide User;
import 'package:supabase_flutter/supabase_flutter.dart' as sb show User;

import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../auth_repository.dart';

/// Authentication backed by Supabase.
///
/// Registration is one call. A database trigger on `auth.users` creates the
/// profile and, for a self-service sign-up, the organization and subscription
/// too — atomically, and whether or not email confirmation is switched on. The
/// shape of the account is carried in the sign-up metadata (`signup_kind`), and
/// the role is decided by that trigger, never by anything the client sends.
class SupabaseAuthRepository implements AuthRepository {
  SupabaseAuthRepository(this._client);

  final SupabaseClient _client;

  GoTrueClient get _auth => _client.auth;

  @override
  Future<AppUser?> restoreSession() async {
    final Session? session = _auth.currentSession;
    if (session == null) return null;

    try {
      final AppUser user = await _requireProfile(session.user.id);
      if (!user.role.canUseMobileApp) {
        await _auth.signOut();
        throw const AppFailure.unauthorized(
          'Platform admin accounts sign in through the web dashboard.',
        );
      }
      return user;
    } on AppFailure {
      rethrow;
    } catch (_) {
      // A token that no longer resolves to a profile is worse than no token:
      // it would leave the app in a signed-in state with nothing behind it.
      await _auth.signOut();
      return null;
    }
  }

  @override
  Future<AppUser> signIn({
    required String identifier,
    required String password,
  }) async {
    final String email = _email(identifier);

    final AuthResponse response;
    try {
      response = await _auth.signInWithPassword(email: email, password: password);
    } on AuthException catch (error) {
      throw _authFailure(error);
    }

    final sb.User? account = response.user;
    if (account == null) {
      throw const AppFailure.unauthorized(
        'Incorrect email or password. Please try again.',
      );
    }

    final AppUser user = await _requireProfile(account.id);

    if (!user.role.canUseMobileApp) {
      await _auth.signOut();
      throw const AppFailure.unauthorized(
        'Platform admin accounts sign in through the web dashboard.',
      );
    }
    if (user.status == AccountStatus.suspended) {
      await _auth.signOut();
      throw const AppFailure.unauthorized(
        'This account has been suspended. Contact your administrator.',
      );
    }
    return user;
  }

  @override
  Future<AppUser> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    String? username,
    String? phone,
  }) {
    return _register(
      email: email,
      password: password,
      data: <String, dynamic>{
        'signup_kind': 'individual_teacher',
        'full_name': Format.clean(fullName),
        if (Format.cleanOrNull(phone) != null) 'phone': Format.cleanOrNull(phone),
      },
    );
  }

  @override
  Future<AppUser> registerOrganization({
    required String fullName,
    required String email,
    required String password,
    required String organizationName,
    String? username,
    String? phone,
    String? city,
  }) {
    final String? cleanedCity = Format.cleanOrNull(city);
    if (cleanedCity == null) {
      throw const AppFailure.validation('Enter the city your organization is in.');
    }
    if (Format.cleanOrNull(organizationName) == null) {
      throw const AppFailure.validation('Organization name is required.');
    }

    return _register(
      email: email,
      password: password,
      data: <String, dynamic>{
        'signup_kind': 'organization',
        'full_name': Format.clean(fullName),
        'organization_name': Format.clean(organizationName),
        'city': cleanedCity,
        if (Format.cleanOrNull(phone) != null) 'phone': Format.cleanOrNull(phone),
      },
    );
  }

  Future<AppUser> _register({
    required String email,
    required String password,
    required Map<String, dynamic> data,
  }) async {
    final AuthResponse response;
    try {
      response = await _auth.signUp(
        email: _email(email),
        password: password,
        data: data,
      );
    } on AuthException catch (error) {
      throw _authFailure(error);
    }

    final sb.User? account = response.user;
    if (account == null) {
      throw const AppFailure(
        'Your account was created but could not be opened. Try signing in.',
      );
    }

    // With email confirmation switched on there is no session yet, so the
    // profile is not readable and the caller must sign in after confirming.
    if (response.session == null) {
      throw const AppFailure(
        'Check your email to confirm your account, then sign in.',
        code: FailureCode.validation,
      );
    }

    return _requireProfile(account.id);
  }

  @override
  Future<void> signOut(AppUser user) async {
    await _auth.signOut();
  }

  @override
  Future<PasswordResetTicket> requestPasswordReset(String email) async {
    final String address = _email(email);
    try {
      await _auth.resetPasswordForEmail(address);
    } on AuthException catch (error) {
      throw _authFailure(error);
    }

    // Supabase emails a link rather than handing back a code, and deliberately
    // does not say whether the address exists. The screen shows this as
    // "check your email" instead of a code to type.
    return PasswordResetTicket(
      deliveredTo: address,
      code: '',
      expiresAt: DateTime.now().add(const Duration(hours: 1)),
    );
  }

  @override
  Future<void> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    // Completing a reset requires the recovery session created by following the
    // emailed link, which lands back in the app rather than passing through
    // this method.
    throw const AppFailure.validation(
      'Open the link we emailed you, then choose a new password.',
    );
  }

  @override
  Future<void> changePassword({
    required String userId,
    required String currentPassword,
    required String newPassword,
  }) async {
    final String? email = _auth.currentUser?.email;
    if (email == null) throw const AppFailure.unauthorized();

    // Supabase updates a password from the session alone. Re-authenticating
    // first means a borrowed unlocked phone cannot change the password without
    // knowing the current one.
    try {
      await _auth.signInWithPassword(email: email, password: currentPassword);
    } on AuthException {
      throw const AppFailure.validation('Your current password is not correct.');
    }

    try {
      await _auth.updateUser(UserAttributes(password: newPassword));
    } on AuthException catch (error) {
      throw _authFailure(error);
    }
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
    final Map<String, dynamic> patch = <String, dynamic>{
      if (fullName != null) 'full_name': Format.clean(fullName),
      if (phone != null) 'phone': Format.cleanOrNull(phone),
      if (title != null) 'title': Format.cleanOrNull(title),
      if (bio != null) 'bio': Format.cleanOrNull(bio),
    };
    if (patch.isEmpty) return _requireProfile(userId);

    try {
      final Map<String, dynamic> row = await _client
          .from('profiles')
          .update(patch)
          .eq('id', userId)
          .select()
          .single();
      return Rows.user(row);
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    }
  }

  @override
  Future<bool> isEmailAvailable(String email, {String? excludeUserId}) async {
    // Row-level security hides other people's profiles, so the client cannot
    // answer this - and should not be able to, since it would turn the app into
    // a way of discovering who has an account. Sign-up reports a duplicate
    // instead, which is the same answer at the only moment it matters.
    return true;
  }

  @override
  Future<bool> isUsernameAvailable(String username, {String? excludeUserId}) async => true;

  @override
  Future<void> deleteAccount(String userId) async {
    // Deleting an auth user needs the service-role key, which must never ship
    // in the app. The platform admin console will own this.
    throw const AppFailure(
      'Ask your administrator to delete this account.',
      code: FailureCode.unauthorized,
    );
  }

  // ---------------------------------------------------------------------------

  Future<AppUser> _requireProfile(String id) async {
    try {
      // me() rather than a select on profiles: it answers has_access in the
      // same round trip, and it is the *same* function that gates every read
      // and write, so the app cannot disagree with the database about whether
      // this account may work today.
      final Object? payload = await _client.rpc<Object?>('me');
      final Map<String, dynamic>? me =
          payload is Map<String, dynamic> ? payload : null;
      final Object? profile = me?['profile'];

      if (profile is Map<String, dynamic>) {
        return Rows.user(profile).copyWith(
          hasAccess: Rows.boolean(me!, 'has_access', fallback: true),
        );
      }

      // A signed-in token with no profile behind it. Falling back to the table
      // keeps a stale session from being mistaken for a missing account.
      final Map<String, dynamic>? row =
          await _client.from('profiles').select().eq('id', id).maybeSingle();
      if (row == null) {
        throw const AppFailure.notFound('Your profile');
      }
      return Rows.user(row);
    } on PostgrestException catch (error) {
      throw _postgrestFailure(error);
    }
  }

  String _email(String value) {
    final String email = value.trim().toLowerCase();
    if (email.isEmpty) throw const AppFailure.validation('Email is required.');
    if (!email.contains('@')) {
      throw const AppFailure.validation(
        'Sign in with your email address.',
      );
    }
    return email;
  }

  AppFailure _authFailure(AuthException error) {
    final String message = error.message.toLowerCase();
    if (message.contains('already registered') ||
        message.contains('already been registered') ||
        message.contains('duplicate')) {
      return const AppFailure.conflict(
        'An account with that email already exists.',
      );
    }
    if (message.contains('invalid login') || message.contains('invalid credentials')) {
      return const AppFailure(
        'Incorrect email or password. Please try again.',
        code: FailureCode.unauthorized,
      );
    }
    if (message.contains('password')) {
      return AppFailure.validation(error.message);
    }
    if (message.contains('rate limit') || message.contains('too many')) {
      return const AppFailure(
        'Too many attempts. Wait a moment and try again.',
        code: FailureCode.network,
      );
    }
    return AppFailure(error.message, code: FailureCode.unauthorized);
  }

  static AppFailure _postgrestFailure(PostgrestException error) {
    // 42501 is Postgres' insufficient_privilege, which here means a row-level
    // security policy refused the write rather than anything being broken.
    if (error.code == '42501' || error.message.contains('row-level security')) {
      return const AppFailure.unauthorized(
        'You do not have permission to do that.',
      );
    }
    if (error.code == '23505') {
      return const AppFailure.conflict('That already exists.');
    }
    return AppFailure(error.message, code: FailureCode.storage);
  }
}
