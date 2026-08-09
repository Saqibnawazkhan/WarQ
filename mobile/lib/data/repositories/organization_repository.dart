import '../models/models.dart';

/// Organizations, their teachers and the invitation flow.
abstract class OrganizationRepository {
  Future<Organization?> findById(String organizationId);

  Future<Organization?> findByJoinCode(String joinCode);

  Future<Organization> update({
    required String organizationId,
    String? name,
    String? email,
    String? phone,
    String? address,
    String? website,
  });

  /// Every teacher (and admin) belonging to the organization, A–Z.
  Future<List<AppUser>> members(String organizationId);

  Future<List<AppUser>> teachers(String organizationId);

  /// Creates a pending invitation. Fails if an open invite already exists for
  /// the same email, or if the person is already a member.
  Future<Invitation> invite({
    required String organizationId,
    required String email,
    required String invitedByUserId,
    String? inviteeName,
    String? message,
  });

  Future<List<Invitation>> invitations(String organizationId);

  Future<Invitation> revokeInvitation(String invitationId);

  Future<Invitation> resendInvitation(String invitationId);

  /// Detaches a teacher from the organization. Their classes, students and
  /// history are preserved and stay with the teacher's own account.
  Future<void> removeTeacher({
    required String organizationId,
    required String teacherId,
    required String actorUserId,
  });

  /// Sets the grading scale used by every class in the organization.
  Future<Organization> setGradeScale({
    required String organizationId,
    required String gradeScaleId,
  });
}
