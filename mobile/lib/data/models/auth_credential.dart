import '../../core/utils/json_utils.dart';

/// Stored login secret for a user.
///
/// Phase 1 authenticates on-device, so the password is kept as a salted
/// SHA-256 digest rather than plain text. When the Phase 2 backend takes over
/// authentication this table simply stops being written.
class AuthCredential {
  const AuthCredential({
    required this.userId,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.updatedAt,
    this.username,
    this.resetCode,
    this.resetCodeExpiresAt,
  });

  factory AuthCredential.fromJson(Map<String, dynamic> json) {
    return AuthCredential(
      userId: Json.string(json, 'userId'),
      email: Json.string(json, 'email'),
      passwordHash: Json.string(json, 'passwordHash'),
      salt: Json.string(json, 'salt'),
      updatedAt: Json.dateTime(json, 'updatedAt', fallback: DateTime.now()),
      username: Json.stringOrNull(json, 'username'),
      resetCode: Json.stringOrNull(json, 'resetCode'),
      resetCodeExpiresAt: Json.dateTimeOrNull(json, 'resetCodeExpiresAt'),
    );
  }

  /// Doubles as the document id in the credential collection.
  final String userId;

  /// Lower-cased email used for lookup.
  final String email;
  final String passwordHash;
  final String salt;
  final DateTime updatedAt;

  /// Lower-cased username used for lookup, when the account has one.
  final String? username;

  /// Phase 1 password reset code (shown in-app; a real deployment mails it).
  final String? resetCode;
  final DateTime? resetCodeExpiresAt;

  bool get hasValidResetCode =>
      resetCode != null &&
      resetCodeExpiresAt != null &&
      DateTime.now().isBefore(resetCodeExpiresAt!);

  /// Identifier used by the collection store.
  String get id => userId;

  AuthCredential copyWith({
    String? email,
    String? passwordHash,
    String? salt,
    String? username,
    bool clearUsername = false,
    String? resetCode,
    bool clearResetCode = false,
    DateTime? resetCodeExpiresAt,
    DateTime? updatedAt,
  }) {
    return AuthCredential(
      userId: userId,
      email: email ?? this.email,
      passwordHash: passwordHash ?? this.passwordHash,
      salt: salt ?? this.salt,
      updatedAt: updatedAt ?? this.updatedAt,
      username: clearUsername ? null : (username ?? this.username),
      resetCode: clearResetCode ? null : (resetCode ?? this.resetCode),
      resetCodeExpiresAt: clearResetCode
          ? null
          : (resetCodeExpiresAt ?? this.resetCodeExpiresAt),
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'userId': userId,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'updatedAt': updatedAt.toIso8601String(),
        'username': username,
        'resetCode': resetCode,
        'resetCodeExpiresAt': resetCodeExpiresAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) =>
      other is AuthCredential && other.userId == userId;

  @override
  int get hashCode => userId.hashCode;
}

/// Persisted sign-in session, restored on app start.
class AuthSession {
  const AuthSession({
    required this.userId,
    required this.signedInAt,
    this.deviceLabel,
  });

  factory AuthSession.fromJson(Map<String, dynamic> json) {
    return AuthSession(
      userId: Json.string(json, 'userId'),
      signedInAt: Json.dateTime(json, 'signedInAt', fallback: DateTime.now()),
      deviceLabel: Json.stringOrNull(json, 'deviceLabel'),
    );
  }

  final String userId;
  final DateTime signedInAt;
  final String? deviceLabel;

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'userId': userId,
        'signedInAt': signedInAt.toIso8601String(),
        'deviceLabel': deviceLabel,
      });
}
