import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/error/failure.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/data/repositories/auth_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await createTestDependencies();
  });

  tearDown(() async => deps.dispose());

  group('registration', () {
    test('creates a teacher account that can sign in', () async {
      final AppUser created = await deps.auth.registerTeacher(
        fullName: 'Ahmed Raza',
        email: 'Ahmed@Example.com',
        password: 'password123',
      );

      expect(created.role, UserRole.teacher);
      expect(created.email, 'ahmed@example.com', reason: 'emails normalise');
      expect(created.organizationId, isNull);

      final AppUser signedIn = await deps.auth.signIn(
        identifier: 'ahmed@example.com',
        password: 'password123',
      );
      expect(signedIn.id, created.id);
    });

    test('creates an organization plus its admin', () async {
      final AppUser admin = await deps.auth.registerOrganization(
        fullName: 'Fatima Khan',
        email: 'admin@example.com',
        password: 'password123',
        organizationName: 'Bright Future Academy',
      );

      expect(admin.role, UserRole.orgAdmin);
      expect(admin.organizationId, isNotNull);

      final Organization? organization =
          await deps.organizations.findById(admin.organizationId!);
      expect(organization?.name, 'Bright Future Academy');
      expect(organization?.ownerUserId, admin.id);
    });

    test('rejects a duplicate email', () async {
      await deps.auth.registerTeacher(
        fullName: 'First',
        email: 'dup@example.com',
        password: 'password123',
      );

      expect(
        () => deps.auth.registerTeacher(
          fullName: 'Second',
          email: 'dup@example.com',
          password: 'password123',
        ),
        throwsA(
          isA<AppFailure>().having(
            (AppFailure f) => f.code,
            'code',
            FailureCode.conflict,
          ),
        ),
      );
    });

    test('rejects a password shorter than the minimum', () async {
      expect(
        () => deps.auth.registerTeacher(
          fullName: 'Short',
          email: 'short@example.com',
          password: '123',
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('a pending invitation makes the new teacher join the organization',
        () async {
      final AppUser admin = await deps.auth.registerOrganization(
        fullName: 'Fatima Khan',
        email: 'admin2@example.com',
        password: 'password123',
        organizationName: 'Bright Future Academy',
      );
      await deps.organizations.invite(
        organizationId: admin.organizationId!,
        email: 'sarah@example.com',
        invitedByUserId: admin.id,
      );

      final AppUser teacher = await deps.auth.registerTeacher(
        fullName: 'Sarah Malik',
        email: 'sarah@example.com',
        password: 'password123',
      );

      expect(teacher.organizationId, admin.organizationId);

      final List<Invitation> invitations =
          await deps.organizations.invitations(admin.organizationId!);
      expect(invitations.single.status, InvitationStatus.accepted);
      expect(invitations.single.acceptedByUserId, teacher.id);
    });
  });

  group('sign in', () {
    setUp(() async {
      await deps.auth.registerTeacher(
        fullName: 'Ahmed Raza',
        email: 'ahmed@example.com',
        password: 'password123',
      );
    });

    test('rejects a wrong password without revealing the account exists',
        () async {
      Object? emailError;
      Object? passwordError;

      try {
        await deps.auth.signIn(
          identifier: 'nobody@example.com',
          password: 'password123',
        );
      } catch (error) {
        emailError = error;
      }
      try {
        await deps.auth.signIn(
          identifier: 'ahmed@example.com',
          password: 'wrong-password',
        );
      } catch (error) {
        passwordError = error;
      }

      expect(emailError, isA<AppFailure>());
      expect(passwordError, isA<AppFailure>());
      expect(
        (emailError! as AppFailure).message,
        (passwordError! as AppFailure).message,
      );
    });

    test('restores a persisted session', () async {
      final AppUser? restored = await deps.auth.restoreSession();
      expect(restored?.email, 'ahmed@example.com');
    });

    test('signing out clears the session', () async {
      final AppUser user = (await deps.auth.restoreSession())!;
      await deps.auth.signOut(user);
      expect(await deps.auth.restoreSession(), isNull);
    });
  });

  group('password management', () {
    late AppUser user;

    setUp(() async {
      user = await deps.auth.registerTeacher(
        fullName: 'Ahmed Raza',
        email: 'ahmed@example.com',
        password: 'password123',
      );
    });

    test('changes the password when the current one is correct', () async {
      await deps.auth.changePassword(
        userId: user.id,
        currentPassword: 'password123',
        newPassword: 'newpassword1',
      );

      final AppUser signedIn = await deps.auth.signIn(
        identifier: 'ahmed@example.com',
        password: 'newpassword1',
      );
      expect(signedIn.id, user.id);
    });

    test('refuses to change the password with the wrong current one', () {
      expect(
        () => deps.auth.changePassword(
          userId: user.id,
          currentPassword: 'not-it',
          newPassword: 'newpassword1',
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('reset flow issues a code that sets a new password', () async {
      final PasswordResetTicket ticket =
          await deps.auth.requestPasswordReset('ahmed@example.com');
      expect(ticket.code, hasLength(6));

      await deps.auth.resetPassword(
        email: 'ahmed@example.com',
        code: ticket.code,
        newPassword: 'resetpassword1',
      );

      final AppUser signedIn = await deps.auth.signIn(
        identifier: 'ahmed@example.com',
        password: 'resetpassword1',
      );
      expect(signedIn.id, user.id);
    });

    test('rejects an incorrect reset code', () async {
      await deps.auth.requestPasswordReset('ahmed@example.com');
      expect(
        () => deps.auth.resetPassword(
          email: 'ahmed@example.com',
          code: '000000',
          newPassword: 'resetpassword1',
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });

  group('profile', () {
    test('updates the profile and keeps the username index in sync', () async {
      final AppUser user = await deps.auth.registerTeacher(
        fullName: 'Ahmed Raza',
        email: 'ahmed@example.com',
        password: 'password123',
      );

      final AppUser updated = await deps.auth.updateProfile(
        userId: user.id,
        fullName: 'Ahmed R. Khan',
        username: 'AhmedK',
        title: 'Senior Lecturer',
      );

      expect(updated.fullName, 'Ahmed R. Khan');
      expect(updated.username, 'ahmedk');
      expect(updated.title, 'Senior Lecturer');

      final AppUser byUsername = await deps.auth.signIn(
        identifier: 'ahmedk',
        password: 'password123',
      );
      expect(byUsername.id, user.id);
    });
  });
}
