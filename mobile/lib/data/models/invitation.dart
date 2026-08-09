import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// An invitation for a teacher to join an organization.
///
/// Phase 1 creates and tracks invitations locally; delivery over
/// email/WhatsApp is handled by the messaging layer so it can be wired to a
/// real provider later without touching this model.
class Invitation {
  const Invitation({
    required this.id,
    required this.organizationId,
    required this.email,
    required this.token,
    required this.invitedByUserId,
    required this.createdAt,
    required this.expiresAt,
    this.role = UserRole.teacher,
    this.status = InvitationStatus.pending,
    this.inviteeName,
    this.message,
    this.acceptedAt,
    this.acceptedByUserId,
  });

  factory Invitation.fromJson(Map<String, dynamic> json) {
    return Invitation(
      id: Json.string(json, 'id'),
      organizationId: Json.string(json, 'organizationId'),
      email: Json.string(json, 'email'),
      token: Json.string(json, 'token'),
      invitedByUserId: Json.string(json, 'invitedByUserId'),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      expiresAt: Json.dateTime(json, 'expiresAt', fallback: DateTime.now()),
      role: Json.enumValue(json, 'role', UserRole.values, UserRole.teacher),
      status: Json.enumValue(
        json,
        'status',
        InvitationStatus.values,
        InvitationStatus.pending,
      ),
      inviteeName: Json.stringOrNull(json, 'inviteeName'),
      message: Json.stringOrNull(json, 'message'),
      acceptedAt: Json.dateTimeOrNull(json, 'acceptedAt'),
      acceptedByUserId: Json.stringOrNull(json, 'acceptedByUserId'),
    );
  }

  final String id;
  final String organizationId;
  final String email;
  final String token;
  final String invitedByUserId;
  final DateTime createdAt;
  final DateTime expiresAt;
  final UserRole role;
  final InvitationStatus status;
  final String? inviteeName;
  final String? message;
  final DateTime? acceptedAt;
  final String? acceptedByUserId;

  /// Status with expiry applied, so a stale `pending` row reads as `expired`
  /// without needing a background job.
  InvitationStatus get effectiveStatus {
    if (status == InvitationStatus.pending && DateTime.now().isAfter(expiresAt)) {
      return InvitationStatus.expired;
    }
    return status;
  }

  bool get isActionable => effectiveStatus == InvitationStatus.pending;

  Invitation copyWith({
    InvitationStatus? status,
    DateTime? acceptedAt,
    String? acceptedByUserId,
    DateTime? expiresAt,
    String? message,
    bool clearMessage = false,
  }) {
    return Invitation(
      id: id,
      organizationId: organizationId,
      email: email,
      token: token,
      invitedByUserId: invitedByUserId,
      createdAt: createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      role: role,
      status: status ?? this.status,
      inviteeName: inviteeName,
      message: clearMessage ? null : (message ?? this.message),
      acceptedAt: acceptedAt ?? this.acceptedAt,
      acceptedByUserId: acceptedByUserId ?? this.acceptedByUserId,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'organizationId': organizationId,
        'email': email,
        'token': token,
        'invitedByUserId': invitedByUserId,
        'createdAt': createdAt.toIso8601String(),
        'expiresAt': expiresAt.toIso8601String(),
        'role': role.name,
        'status': status.name,
        'inviteeName': inviteeName,
        'message': message,
        'acceptedAt': acceptedAt?.toIso8601String(),
        'acceptedByUserId': acceptedByUserId,
      });

  @override
  bool operator ==(Object other) => other is Invitation && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
