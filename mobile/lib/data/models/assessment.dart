import '../../core/utils/date_utils.dart';
import '../../core/utils/json_utils.dart';
import 'enums.dart';

/// A piece of graded work belonging to a class: quiz, assignment, midterm,
/// final exam, presentation, project or a custom type.
class Assessment {
  const Assessment({
    required this.id,
    required this.classId,
    required this.name,
    required this.type,
    required this.date,
    required this.totalMarks,
    required this.createdByUserId,
    required this.createdAt,
    this.customTypeLabel,
    this.description,
    this.weight,
    this.published = true,
    this.updatedAt,
  });

  factory Assessment.fromJson(Map<String, dynamic> json) {
    return Assessment(
      id: Json.string(json, 'id'),
      classId: Json.string(json, 'classId'),
      name: Json.string(json, 'name'),
      type: Json.enumValue(
        json,
        'type',
        AssessmentType.values,
        AssessmentType.quiz,
      ),
      date: AppDate.parseIso(Json.stringOrNull(json, 'date')) ?? AppDate.today(),
      totalMarks: Json.number(json, 'totalMarks', fallback: 100),
      createdByUserId: Json.string(json, 'createdByUserId'),
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      customTypeLabel: Json.stringOrNull(json, 'customTypeLabel'),
      description: Json.stringOrNull(json, 'description'),
      weight: Json.numberOrNull(json, 'weight'),
      published: Json.boolean(json, 'published', fallback: true),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  final String id;
  final String classId;
  final String name;
  final AssessmentType type;
  final DateTime date;
  final double totalMarks;
  final String createdByUserId;
  final DateTime createdAt;

  /// Used only when [type] is [AssessmentType.custom].
  final String? customTypeLabel;
  final String? description;

  /// Optional weighting for a future weighted-average grading mode. When null
  /// the assessment contributes its raw marks to the total.
  final double? weight;
  final bool published;
  final DateTime? updatedAt;

  /// Human label for the type, honouring a custom label when provided.
  String get typeLabel {
    if (type == AssessmentType.custom) {
      final String? custom = customTypeLabel?.trim();
      if (custom != null && custom.isNotEmpty) return custom;
    }
    return type.label;
  }

  Assessment copyWith({
    String? name,
    AssessmentType? type,
    String? customTypeLabel,
    bool clearCustomTypeLabel = false,
    DateTime? date,
    double? totalMarks,
    String? description,
    bool clearDescription = false,
    double? weight,
    bool clearWeight = false,
    bool? published,
    DateTime? updatedAt,
  }) {
    return Assessment(
      id: id,
      classId: classId,
      name: name ?? this.name,
      type: type ?? this.type,
      date: date ?? this.date,
      totalMarks: totalMarks ?? this.totalMarks,
      createdByUserId: createdByUserId,
      createdAt: createdAt,
      customTypeLabel: clearCustomTypeLabel
          ? null
          : (customTypeLabel ?? this.customTypeLabel),
      description: clearDescription ? null : (description ?? this.description),
      weight: clearWeight ? null : (weight ?? this.weight),
      published: published ?? this.published,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'classId': classId,
        'name': name,
        'type': type.name,
        'date': AppDate.toIso(date),
        'totalMarks': totalMarks,
        'createdByUserId': createdByUserId,
        'createdAt': createdAt.toIso8601String(),
        'customTypeLabel': customTypeLabel,
        'description': description,
        'weight': weight,
        'published': published,
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is Assessment && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
