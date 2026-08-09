import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// A person who can sign in to EDU Manager.
///
/// One table for every role keeps the future backend simple: role and
/// `organizationId` decide what the account can see.
class AppUser {
  const AppUser({
    required this.id,
    required this.fullName,
    required this.email,
    required this.role,
    required this.createdAt,
    this.username,
    this.phone,
    this.organizationId,
    this.status = AccountStatus.active,
    this.title,
    this.bio,
    this.avatarSeed,
    this.lastLoginAt,
    this.updatedAt,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: Json.string(json, 'id'),
      fullName: Json.string(json, 'fullName'),
      email: Json.string(json, 'email'),
      role: Json.enumValue(json, 'role', UserRole.values, UserRole.teacher),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      username: Json.stringOrNull(json, 'username'),
      phone: Json.stringOrNull(json, 'phone'),
      organizationId: Json.stringOrNull(json, 'organizationId'),
      status: Json.enumValue(
        json,
        'status',
        AccountStatus.values,
        AccountStatus.active,
      ),
      title: Json.stringOrNull(json, 'title'),
      bio: Json.stringOrNull(json, 'bio'),
      avatarSeed: Json.stringOrNull(json, 'avatarSeed'),
      lastLoginAt: Json.dateTimeOrNull(json, 'lastLoginAt'),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  final String id;
  final String fullName;
  final String email;
  final UserRole role;
  final DateTime createdAt;

  /// Optional alternative login handle.
  final String? username;
  final String? phone;

  /// `null` for an individual teacher who is not part of an organization.
  final String? organizationId;
  final AccountStatus status;

  /// e.g. "Senior Lecturer" — shown on reports next to the teacher name.
  final String? title;
  final String? bio;

  /// Stable seed for the generated avatar colour; defaults to the name.
  final String? avatarSeed;
  final DateTime? lastLoginAt;
  final DateTime? updatedAt;

  bool get isTeacher => role == UserRole.teacher;
  bool get isOrgAdmin => role == UserRole.orgAdmin;
  bool get belongsToOrganization => organizationId != null;
  String get displayName => fullName.trim().isEmpty ? email : fullName.trim();
  String get avatarKey => avatarSeed ?? displayName;

  /// The handle shown in the UI: username when present, otherwise the email.
  String get handle => username ?? email;

  AppUser copyWith({
    String? fullName,
    String? email,
    UserRole? role,
    String? username,
    bool clearUsername = false,
    String? phone,
    bool clearPhone = false,
    String? organizationId,
    bool clearOrganization = false,
    AccountStatus? status,
    String? title,
    bool clearTitle = false,
    String? bio,
    bool clearBio = false,
    String? avatarSeed,
    DateTime? lastLoginAt,
    DateTime? updatedAt,
  }) {
    return AppUser(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      role: role ?? this.role,
      createdAt: createdAt,
      username: clearUsername ? null : (username ?? this.username),
      phone: clearPhone ? null : (phone ?? this.phone),
      organizationId:
          clearOrganization ? null : (organizationId ?? this.organizationId),
      status: status ?? this.status,
      title: clearTitle ? null : (title ?? this.title),
      bio: clearBio ? null : (bio ?? this.bio),
      avatarSeed: avatarSeed ?? this.avatarSeed,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'fullName': fullName,
        'email': email,
        'role': role.name,
        'createdAt': createdAt.toIso8601String(),
        'username': username,
        'phone': phone,
        'organizationId': organizationId,
        'status': status.name,
        'title': title,
        'bio': bio,
        'avatarSeed': avatarSeed,
        'lastLoginAt': lastLoginAt?.toIso8601String(),
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is AppUser && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'AppUser($id, $email, ${role.name})';
}
