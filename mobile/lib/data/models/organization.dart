import '../../core/utils/json_utils.dart';

/// A school, college or academy that groups teachers together.
///
/// Individual teachers have no organization; their data is scoped to their own
/// user id instead.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.joinCode,
    required this.ownerUserId,
    required this.createdAt,
    this.email,
    this.phone,
    this.address,
    this.website,
    this.gradeScaleId,
    this.updatedAt,
  });

  factory Organization.fromJson(Map<String, dynamic> json) {
    return Organization(
      id: Json.string(json, 'id'),
      name: Json.string(json, 'name'),
      joinCode: Json.string(json, 'joinCode'),
      ownerUserId: Json.string(json, 'ownerUserId'),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      email: Json.stringOrNull(json, 'email'),
      phone: Json.stringOrNull(json, 'phone'),
      address: Json.stringOrNull(json, 'address'),
      website: Json.stringOrNull(json, 'website'),
      gradeScaleId: Json.stringOrNull(json, 'gradeScaleId'),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  final String id;
  final String name;

  /// Short human-readable code teachers can quote when joining.
  final String joinCode;
  final String ownerUserId;
  final DateTime createdAt;
  final String? email;
  final String? phone;
  final String? address;
  final String? website;

  /// Organization-wide grading scale; falls back to the platform default.
  final String? gradeScaleId;
  final DateTime? updatedAt;

  Organization copyWith({
    String? name,
    String? email,
    bool clearEmail = false,
    String? phone,
    bool clearPhone = false,
    String? address,
    bool clearAddress = false,
    String? website,
    bool clearWebsite = false,
    String? gradeScaleId,
    DateTime? updatedAt,
  }) {
    return Organization(
      id: id,
      name: name ?? this.name,
      joinCode: joinCode,
      ownerUserId: ownerUserId,
      createdAt: createdAt,
      email: clearEmail ? null : (email ?? this.email),
      phone: clearPhone ? null : (phone ?? this.phone),
      address: clearAddress ? null : (address ?? this.address),
      website: clearWebsite ? null : (website ?? this.website),
      gradeScaleId: gradeScaleId ?? this.gradeScaleId,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'name': name,
        'joinCode': joinCode,
        'ownerUserId': ownerUserId,
        'createdAt': createdAt.toIso8601String(),
        'email': email,
        'phone': phone,
        'address': address,
        'website': website,
        'gradeScaleId': gradeScaleId,
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is Organization && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
