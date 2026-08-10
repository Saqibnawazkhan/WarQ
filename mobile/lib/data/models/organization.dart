import '../../core/utils/json_utils.dart';

/// A school, college or academy that groups teachers together.
///
/// Individual teachers have no organization; their data is scoped to their own
/// user id instead.
class Organization {
  const Organization({
    required this.id,
    required this.name,
    required this.ownerUserId,
    required this.createdAt,
    this.city,
    this.joinCode,
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
      city: Json.stringOrNull(json, 'city'),
      joinCode: Json.stringOrNull(json, 'joinCode'),
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

  /// Required when an organization registers itself; drives the platform
  /// admin's search.
  final String? city;

  /// Short human-readable code, kept for display only. Teachers join through a
  /// tokenised invitation, never by quoting this.
  final String? joinCode;
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
    String? city,
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
      city: city ?? this.city,
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
        'city': city,
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
