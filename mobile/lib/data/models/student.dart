import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// A learner record.
///
/// Students live at the teacher/organization level rather than inside a class
/// so the same person can be enrolled in several classes without duplication.
/// Enrollment is modelled separately by [ClassEnrollment].
///
/// Only [fullName] is required — roll number and every phone number are
/// optional per the product spec.
class Student {
  const Student({
    required this.id,
    required this.ownerTeacherId,
    required this.fullName,
    required this.createdAt,
    this.organizationId,
    this.rollNumber,
    this.studentPhone,
    this.fatherPhone,
    this.motherPhone,
    this.guardianName,
    this.email,
    this.address,
    this.notes,
    this.updatedAt,
  });

  factory Student.fromJson(Map<String, dynamic> json) {
    return Student(
      id: Json.string(json, 'id'),
      ownerTeacherId: Json.string(json, 'ownerTeacherId'),
      fullName: Json.string(json, 'fullName'),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      organizationId: Json.stringOrNull(json, 'organizationId'),
      rollNumber: Json.stringOrNull(json, 'rollNumber'),
      studentPhone: Json.stringOrNull(json, 'studentPhone'),
      fatherPhone: Json.stringOrNull(json, 'fatherPhone'),
      motherPhone: Json.stringOrNull(json, 'motherPhone'),
      guardianName: Json.stringOrNull(json, 'guardianName'),
      email: Json.stringOrNull(json, 'email'),
      address: Json.stringOrNull(json, 'address'),
      notes: Json.stringOrNull(json, 'notes'),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  final String id;

  /// The teacher who created the record; used for scoping in Phase 1.
  final String ownerTeacherId;
  final String fullName;
  final DateTime createdAt;
  final String? organizationId;

  /// Roll number / student number. Optional.
  final String? rollNumber;
  final String? studentPhone;
  final String? fatherPhone;
  final String? motherPhone;
  final String? guardianName;
  final String? email;
  final String? address;
  final String? notes;
  final DateTime? updatedAt;

  /// Key used for A–Z ordering; case-insensitive and whitespace tolerant.
  String get sortKey => fullName.trim().toLowerCase();

  /// First letter used for the alphabetical section headers.
  String get sectionLetter {
    final String key = sortKey;
    if (key.isEmpty) return '#';
    final String first = key[0].toUpperCase();
    return RegExp(r'[A-Z]').hasMatch(first) ? first : '#';
  }

  /// All contactable numbers paired with who they belong to. Empty entries are
  /// filtered out, which is what makes "skip recipients without a number"
  /// fall out naturally in the notification pipeline.
  List<({RecipientRelation relation, String phone})> get contactNumbers {
    final List<({RecipientRelation relation, String phone})> result =
        <({RecipientRelation relation, String phone})>[];
    void add(RecipientRelation relation, String? phone) {
      final String value = phone?.trim() ?? '';
      if (value.isNotEmpty) {
        result.add((relation: relation, phone: value));
      }
    }

    add(RecipientRelation.student, studentPhone);
    add(RecipientRelation.father, fatherPhone);
    add(RecipientRelation.mother, motherPhone);
    return result;
  }

  bool get hasAnyContact => contactNumbers.isNotEmpty;

  Student copyWith({
    String? fullName,
    String? rollNumber,
    bool clearRollNumber = false,
    String? studentPhone,
    bool clearStudentPhone = false,
    String? fatherPhone,
    bool clearFatherPhone = false,
    String? motherPhone,
    bool clearMotherPhone = false,
    String? guardianName,
    bool clearGuardianName = false,
    String? email,
    bool clearEmail = false,
    String? address,
    bool clearAddress = false,
    String? notes,
    bool clearNotes = false,
    String? organizationId,
    bool clearOrganization = false,
    DateTime? updatedAt,
  }) {
    return Student(
      id: id,
      ownerTeacherId: ownerTeacherId,
      fullName: fullName ?? this.fullName,
      createdAt: createdAt,
      organizationId:
          clearOrganization ? null : (organizationId ?? this.organizationId),
      rollNumber: clearRollNumber ? null : (rollNumber ?? this.rollNumber),
      studentPhone:
          clearStudentPhone ? null : (studentPhone ?? this.studentPhone),
      fatherPhone: clearFatherPhone ? null : (fatherPhone ?? this.fatherPhone),
      motherPhone: clearMotherPhone ? null : (motherPhone ?? this.motherPhone),
      guardianName:
          clearGuardianName ? null : (guardianName ?? this.guardianName),
      email: clearEmail ? null : (email ?? this.email),
      address: clearAddress ? null : (address ?? this.address),
      notes: clearNotes ? null : (notes ?? this.notes),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'ownerTeacherId': ownerTeacherId,
        'fullName': fullName,
        'createdAt': createdAt.toIso8601String(),
        'organizationId': organizationId,
        'rollNumber': rollNumber,
        'studentPhone': studentPhone,
        'fatherPhone': fatherPhone,
        'motherPhone': motherPhone,
        'guardianName': guardianName,
        'email': email,
        'address': address,
        'notes': notes,
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is Student && other.id == id;

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() => 'Student($id, $fullName)';
}
