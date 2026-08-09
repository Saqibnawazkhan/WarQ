import '../../core/utils/json_utils.dart';

/// A class (course section) owned by one teacher.
///
/// Only [name] is mandatory; subject, section, session and description are
/// optional per the product spec.
class SchoolClass {
  const SchoolClass({
    required this.id,
    required this.teacherId,
    required this.name,
    required this.createdAt,
    this.organizationId,
    this.subject,
    this.section,
    this.session,
    this.description,
    this.colorSeed,
    this.archived = false,
    this.updatedAt,
  });

  factory SchoolClass.fromJson(Map<String, dynamic> json) {
    return SchoolClass(
      id: Json.string(json, 'id'),
      teacherId: Json.string(json, 'teacherId'),
      name: Json.string(json, 'name'),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      organizationId: Json.stringOrNull(json, 'organizationId'),
      subject: Json.stringOrNull(json, 'subject'),
      section: Json.stringOrNull(json, 'section'),
      session: Json.stringOrNull(json, 'session'),
      description: Json.stringOrNull(json, 'description'),
      colorSeed: Json.stringOrNull(json, 'colorSeed'),
      archived: Json.boolean(json, 'archived'),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  final String id;
  final String teacherId;
  final String name;
  final DateTime createdAt;
  final String? organizationId;
  final String? subject;

  /// e.g. "A", "Morning".
  final String? section;

  /// Academic year or term, e.g. "2026" or "2026-2027".
  final String? session;
  final String? description;
  final String? colorSeed;
  final bool archived;
  final DateTime? updatedAt;

  /// "Software Engineering · Section A · 2026" — omits blanks gracefully.
  String get subtitle {
    final List<String> parts = <String>[
      if (subject != null && subject != name) subject!,
      if (section != null) 'Section $section',
      if (session != null) session!,
    ];
    return parts.join(' · ');
  }

  /// A compact label used in dropdowns and report headers.
  String get displayName {
    if (section == null) return name;
    return '$name ($section)';
  }

  String get avatarKey => colorSeed ?? '$name$id';

  SchoolClass copyWith({
    String? name,
    String? subject,
    bool clearSubject = false,
    String? section,
    bool clearSection = false,
    String? session,
    bool clearSession = false,
    String? description,
    bool clearDescription = false,
    String? organizationId,
    bool clearOrganization = false,
    String? colorSeed,
    bool? archived,
    DateTime? updatedAt,
  }) {
    return SchoolClass(
      id: id,
      teacherId: teacherId,
      name: name ?? this.name,
      createdAt: createdAt,
      organizationId:
          clearOrganization ? null : (organizationId ?? this.organizationId),
      subject: clearSubject ? null : (subject ?? this.subject),
      section: clearSection ? null : (section ?? this.section),
      session: clearSession ? null : (session ?? this.session),
      description: clearDescription ? null : (description ?? this.description),
      colorSeed: colorSeed ?? this.colorSeed,
      archived: archived ?? this.archived,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'teacherId': teacherId,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'organizationId': organizationId,
        'subject': subject,
        'section': section,
        'session': session,
        'description': description,
        'colorSeed': colorSeed,
        'archived': archived,
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is SchoolClass && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
