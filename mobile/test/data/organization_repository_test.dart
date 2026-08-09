import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/error/failure.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/domain/entities/dashboard_data.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/test_harness.dart';

void main() {
  late AppDependencies deps;
  late AppUser admin;
  late String organizationId;

  setUp(() async {
    deps = await createTestDependencies();
    admin = await deps.auth.registerOrganization(
      fullName: 'Fatima Khan',
      email: 'admin@test.com',
      password: 'password123',
      organizationName: 'Bright Future Academy',
    );
    organizationId = admin.organizationId!;
  });

  tearDown(() async => deps.dispose());

  Future<AppUser> joinTeacher({
    String email = 'sarah@test.com',
    String name = 'Sarah Malik',
  }) async {
    await deps.organizations.invite(
      organizationId: organizationId,
      email: email,
      invitedByUserId: admin.id,
    );
    return deps.auth.registerTeacher(
      fullName: name,
      email: email,
      password: 'password123',
    );
  }

  group('invitations', () {
    test('creates a pending invitation', () async {
      final Invitation invitation = await deps.organizations.invite(
        organizationId: organizationId,
        email: 'Sarah@Test.com',
        invitedByUserId: admin.id,
        inviteeName: 'Sarah Malik',
      );

      expect(invitation.email, 'sarah@test.com');
      expect(invitation.status, InvitationStatus.pending);
      expect(invitation.isActionable, isTrue);
      expect(invitation.token, isNotEmpty);
    });

    test('rejects a second open invitation for the same email', () async {
      await deps.organizations.invite(
        organizationId: organizationId,
        email: 'sarah@test.com',
        invitedByUserId: admin.id,
      );

      expect(
        () => deps.organizations.invite(
          organizationId: organizationId,
          email: 'sarah@test.com',
          invitedByUserId: admin.id,
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

    test('rejects inviting an existing member', () async {
      await joinTeacher();

      expect(
        () => deps.organizations.invite(
          organizationId: organizationId,
          email: 'sarah@test.com',
          invitedByUserId: admin.id,
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('revoking blocks the invitation', () async {
      final Invitation invitation = await deps.organizations.invite(
        organizationId: organizationId,
        email: 'sarah@test.com',
        invitedByUserId: admin.id,
      );

      final Invitation revoked =
          await deps.organizations.revokeInvitation(invitation.id);
      expect(revoked.status, InvitationStatus.revoked);
      expect(revoked.isActionable, isFalse);
    });

    test('cannot revoke an accepted invitation', () async {
      await joinTeacher();
      final List<Invitation> invitations =
          await deps.organizations.invitations(organizationId);

      expect(
        () => deps.organizations.revokeInvitation(invitations.single.id),
        throwsA(isA<AppFailure>()),
      );
    });

    test('resending reopens an expired invitation', () async {
      final Invitation invitation = await deps.organizations.invite(
        organizationId: organizationId,
        email: 'sarah@test.com',
        invitedByUserId: admin.id,
      );
      await deps.organizations.revokeInvitation(invitation.id);

      final Invitation resent =
          await deps.organizations.resendInvitation(invitation.id);
      expect(resent.status, InvitationStatus.pending);
      expect(resent.expiresAt.isAfter(DateTime.now()), isTrue);
    });
  });

  group('membership', () {
    test('lists teachers alphabetically', () async {
      await joinTeacher(email: 'zara@test.com', name: 'Zara Ali');
      await joinTeacher(email: 'amir@test.com', name: 'Amir Shah');

      final List<AppUser> teachers =
          await deps.organizations.teachers(organizationId);

      expect(
        teachers.map((AppUser t) => t.displayName).toList(),
        <String>['Amir Shah', 'Zara Ali'],
      );
    });

    test('removing a teacher detaches them but preserves their data', () async {
      final AppUser teacher = await joinTeacher();
      final SchoolClass schoolClass = await createTestClass(deps, teacher);
      final Student student =
          await addTestStudent(deps, teacher, schoolClass, name: 'Noor Fatima');

      await deps.organizations.removeTeacher(
        organizationId: organizationId,
        teacherId: teacher.id,
        actorUserId: admin.id,
      );

      expect(await deps.organizations.teachers(organizationId), isEmpty);

      // Their own records survive and simply leave the organization scope.
      final SchoolClass? kept = await deps.classes.findById(schoolClass.id);
      expect(kept, isNotNull);
      expect(kept!.organizationId, isNull);
      expect(kept.teacherId, teacher.id);

      final Student? keptStudent = await deps.students.findById(student.id);
      expect(keptStudent, isNotNull);
      expect(keptStudent!.organizationId, isNull);

      expect(
        await deps.classes.listForOrganization(organizationId),
        isEmpty,
        reason: 'the admin can no longer see the class',
      );
    });

    test('the owner cannot be removed', () async {
      expect(
        () => deps.organizations.removeTeacher(
          organizationId: organizationId,
          teacherId: admin.id,
          actorUserId: admin.id,
        ),
        throwsA(isA<AppFailure>()),
      );
    });

    test('a removed teacher is notified', () async {
      final AppUser teacher = await joinTeacher();
      await deps.organizations.removeTeacher(
        organizationId: organizationId,
        teacherId: teacher.id,
        actorUserId: admin.id,
      );

      final List<AppNotification> alerts =
          await deps.notifications.listForUser(teacher.id);
      expect(
        alerts.any((AppNotification n) => n.title.contains('Removed from')),
        isTrue,
      );
    });
  });

  group('organization dashboard', () {
    test('aggregates only this organization\'s data', () async {
      final AppUser member = await joinTeacher();
      final SchoolClass schoolClass = await createTestClass(deps, member);
      await addTestStudent(deps, member, schoolClass, name: 'Noor Fatima');

      // An unrelated individual teacher must not leak into the aggregates.
      final AppUser outsider = await deps.auth.registerTeacher(
        fullName: 'Outside Teacher',
        email: 'outside@test.com',
        password: 'password123',
      );
      final SchoolClass outsiderClass =
          await createTestClass(deps, outsider, name: 'Outside Class');
      await addTestStudent(deps, outsider, outsiderClass, name: 'Someone Else');

      final OrganizationDashboardData data =
          await deps.analytics.organizationDashboard(organizationId);

      expect(data.teacherCount, 1);
      expect(data.classCount, 1);
      expect(data.studentCount, 1);
      expect(data.organization?.name, 'Bright Future Academy');
    });

    test('grade scale changes apply to the organization', () async {
      final GradeScale saved = await deps.gradeScales.saveForOrganization(
        organizationId: organizationId,
        name: 'Academy scale',
        passPercent: 40,
        bands: const <GradeBand>[
          GradeBand(label: 'Distinction', minPercent: 75),
          GradeBand(label: 'Merit', minPercent: 55),
          GradeBand(label: 'Pass', minPercent: 40),
          GradeBand(label: 'Fail', minPercent: 0),
        ],
      );

      expect(saved.organizationId, organizationId);

      final GradeScale resolved =
          await deps.gradeScales.resolveFor(organizationId: organizationId);
      expect(resolved.id, saved.id);
      expect(resolved.bandFor(80).label, 'Distinction');
      expect(resolved.passPercent, 40);

      // Individual teachers keep the platform default.
      final GradeScale fallback = await deps.gradeScales.resolveFor();
      expect(fallback.id, GradeScale.defaultId);
    });

    test('a scale without a zero band is rejected', () {
      expect(
        () => deps.gradeScales.saveForOrganization(
          organizationId: organizationId,
          name: 'Broken',
          passPercent: 50,
          bands: const <GradeBand>[
            GradeBand(label: 'A', minPercent: 80),
            GradeBand(label: 'B', minPercent: 50),
          ],
        ),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
