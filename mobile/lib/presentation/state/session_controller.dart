import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import '../../data/repositories/auth_repository.dart';
import 'base_controller.dart';

/// Owns the signed-in user for the lifetime of the app.
///
/// Every other controller reads the current user from here rather than passing
/// it down the widget tree, and the root router listens to it to decide which
/// shell to show.
class SessionController extends BaseController {
  SessionController(this._deps) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.users,
      DataEntity.organizations,
    });
  }

  final AppDependencies _deps;

  AppUser? _user;
  Organization? _organization;
  bool _bootstrapped = false;

  AppUser? get user => _user;
  Organization? get organization => _organization;
  bool get isSignedIn => _user != null;
  bool get isBootstrapped => _bootstrapped;

  UserRole? get role => _user?.role;
  bool get isTeacher => _user?.isTeacher ?? false;
  bool get isOrgAdmin => _user?.isOrgAdmin ?? false;

  /// Convenience for screens that cannot render without a user; only called
  /// from inside an authenticated shell.
  AppUser get requireUser {
    final AppUser? current = _user;
    if (current == null) {
      throw StateError('No signed-in user. This screen requires a session.');
    }
    return current;
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        final AppUser? restored = await _deps.auth.restoreSession();
        await _applyUser(restored);
        _bootstrapped = true;
      },
      refreshing: refreshing,
    );
  }

  /// Re-reads the current user from storage after an external change (e.g. the
  /// admin removed this teacher from the organization).
  @override
  void onDataChanged(DataEvent event) {
    if (_user == null) return;
    super.onDataChanged(event);
  }

  Future<bool> signIn({
    required String identifier,
    required String password,
  }) async {
    final bool? ok = await guardAction<bool>(() async {
      final AppUser user = await _deps.auth.signIn(
        identifier: identifier,
        password: password,
      );
      await _applyUser(user);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> registerTeacher({
    required String fullName,
    required String email,
    required String password,
    String? username,
    String? phone,
  }) async {
    final bool? ok = await guardAction<bool>(() async {
      final AppUser user = await _deps.auth.registerTeacher(
        fullName: fullName,
        email: email,
        password: password,
        username: username,
        phone: phone,
      );
      await _applyUser(user);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> registerOrganization({
    required String fullName,
    required String email,
    required String password,
    required String organizationName,
    String? username,
    String? phone,
  }) async {
    final bool? ok = await guardAction<bool>(() async {
      final AppUser user = await _deps.auth.registerOrganization(
        fullName: fullName,
        email: email,
        password: password,
        organizationName: organizationName,
        username: username,
        phone: phone,
      );
      await _applyUser(user);
      return true;
    });
    return ok ?? false;
  }

  Future<void> signOut() async {
    final AppUser? current = _user;
    if (current == null) return;
    await guardAction<bool>(() async {
      await _deps.auth.signOut(current);
      return true;
    });
    _user = null;
    _organization = null;
    safeNotify();
  }

  Future<PasswordResetTicket?> requestPasswordReset(String email) {
    return guardAction<PasswordResetTicket>(
      () => _deps.auth.requestPasswordReset(email),
    );
  }

  Future<bool> resetPassword({
    required String email,
    required String code,
    required String newPassword,
  }) async {
    final bool? ok = await guardAction<bool>(() async {
      await _deps.auth.resetPassword(
        email: email,
        code: code,
        newPassword: newPassword,
      );
      return true;
    });
    return ok ?? false;
  }

  Future<bool> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    final AppUser current = requireUser;
    final bool? ok = await guardAction<bool>(() async {
      await _deps.auth.changePassword(
        userId: current.id,
        currentPassword: currentPassword,
        newPassword: newPassword,
      );
      return true;
    });
    return ok ?? false;
  }

  Future<bool> updateProfile({
    String? fullName,
    String? username,
    String? phone,
    String? title,
    String? bio,
  }) async {
    final AppUser current = requireUser;
    final bool? ok = await guardAction<bool>(() async {
      final AppUser updated = await _deps.auth.updateProfile(
        userId: current.id,
        fullName: fullName,
        username: username,
        phone: phone,
        title: title,
        bio: bio,
      );
      await _applyUser(updated);
      return true;
    });
    return ok ?? false;
  }

  Future<bool> deleteAccount() async {
    final AppUser current = requireUser;
    final bool? ok = await guardAction<bool>(() async {
      await _deps.auth.deleteAccount(current.id);
      return true;
    });
    if (ok ?? false) {
      _user = null;
      _organization = null;
      safeNotify();
    }
    return ok ?? false;
  }

  Future<void> _applyUser(AppUser? user) async {
    _user = user;
    _organization = user?.organizationId == null
        ? null
        : await _deps.organizations.findById(user!.organizationId!);
    safeNotify();
  }
}
