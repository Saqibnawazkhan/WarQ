import '../../core/utils/json_utils.dart';

/// One band of a grading scale, e.g. `A+` for 90% and above.
class GradeBand {
  const GradeBand({
    required this.label,
    required this.minPercent,
    this.gpa,
    this.remark,
  });

  factory GradeBand.fromJson(Map<String, dynamic> json) {
    return GradeBand(
      label: Json.string(json, 'label', fallback: '—'),
      minPercent: Json.number(json, 'minPercent'),
      gpa: Json.numberOrNull(json, 'gpa'),
      remark: Json.stringOrNull(json, 'remark'),
    );
  }

  final String label;

  /// Inclusive lower bound. The upper bound is implied by the next band.
  final double minPercent;
  final double? gpa;
  final String? remark;

  GradeBand copyWith({
    String? label,
    double? minPercent,
    double? gpa,
    bool clearGpa = false,
    String? remark,
    bool clearRemark = false,
  }) {
    return GradeBand(
      label: label ?? this.label,
      minPercent: minPercent ?? this.minPercent,
      gpa: clearGpa ? null : (gpa ?? this.gpa),
      remark: clearRemark ? null : (remark ?? this.remark),
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'label': label,
        'minPercent': minPercent,
        'gpa': gpa,
        'remark': remark,
      });

  @override
  bool operator ==(Object other) =>
      other is GradeBand &&
      other.label == label &&
      other.minPercent == minPercent;

  @override
  int get hashCode => Object.hash(label, minPercent);
}

/// A complete grading scale.
///
/// Phase 1 ships the default scale from the spec. The model already carries an
/// `organizationId`, so making the scale configurable per organization later is
/// a UI change rather than a schema change.
class GradeScale {
  /// Bands are sorted highest-threshold-first on construction so [bandFor]
  /// can resolve a grade with a single top-down scan, whatever order the
  /// caller supplied them in.
  GradeScale({
    required this.id,
    required this.name,
    required List<GradeBand> bands,
    required this.createdAt,
    this.organizationId,
    this.isDefault = false,
    this.passPercent = 50,
    this.updatedAt,
  }) : bands = _sorted(bands);

  factory GradeScale.fromJson(Map<String, dynamic> json) {
    final List<GradeBand> bands = Json.mapList(json, 'bands')
        .map(GradeBand.fromJson)
        .toList(growable: false);
    return GradeScale(
      id: Json.string(json, 'id'),
      name: Json.string(json, 'name', fallback: 'Default scale'),
      bands: bands.isEmpty ? defaultBands : bands,
      createdAt: Json.dateTime(json, 'createdAt', fallback: DateTime.now()),
      organizationId: Json.stringOrNull(json, 'organizationId'),
      isDefault: Json.boolean(json, 'isDefault'),
      passPercent: Json.number(json, 'passPercent', fallback: 50),
      updatedAt: Json.dateTimeOrNull(json, 'updatedAt'),
    );
  }

  /// Platform default from the product spec.
  static const List<GradeBand> defaultBands = <GradeBand>[
    GradeBand(label: 'A+', minPercent: 90, gpa: 4.0, remark: 'Outstanding'),
    GradeBand(label: 'A', minPercent: 80, gpa: 3.7, remark: 'Excellent'),
    GradeBand(label: 'B', minPercent: 70, gpa: 3.0, remark: 'Good'),
    GradeBand(label: 'C', minPercent: 60, gpa: 2.0, remark: 'Satisfactory'),
    GradeBand(label: 'D', minPercent: 50, gpa: 1.0, remark: 'Needs improvement'),
    GradeBand(label: 'F', minPercent: 0, gpa: 0.0, remark: 'Fail'),
  ];

  static const String defaultId = 'grade_scale_default';

  factory GradeScale.platformDefault() => GradeScale(
        id: defaultId,
        name: 'Standard scale',
        bands: defaultBands,
        createdAt: DateTime.fromMillisecondsSinceEpoch(0),
        isDefault: true,
      );

  final String id;
  final String name;

  /// Always kept sorted by [GradeBand.minPercent] descending.
  final List<GradeBand> bands;
  final DateTime createdAt;
  final String? organizationId;
  final bool isDefault;

  /// Minimum percentage considered a pass.
  final double passPercent;
  final DateTime? updatedAt;

  static List<GradeBand> _sorted(List<GradeBand> input) {
    final List<GradeBand> copy = List<GradeBand>.of(input);
    copy.sort((GradeBand a, GradeBand b) => b.minPercent.compareTo(a.minPercent));
    return List<GradeBand>.unmodifiable(copy);
  }

  /// The band a percentage falls into. Never returns null — the lowest band
  /// acts as the catch-all.
  GradeBand bandFor(double percent) {
    for (final GradeBand band in bands) {
      if (percent >= band.minPercent) return band;
    }
    return bands.isEmpty
        ? const GradeBand(label: 'F', minPercent: 0)
        : bands.last;
  }

  /// Inclusive display range for a band, e.g. `80 – 89.9`.
  ({double min, double? max}) rangeFor(GradeBand band) {
    final int index = bands.indexOf(band);
    if (index <= 0) return (min: band.minPercent, max: null);
    return (min: band.minPercent, max: bands[index - 1].minPercent);
  }

  GradeScale copyWith({
    String? name,
    List<GradeBand>? bands,
    String? organizationId,
    bool? isDefault,
    double? passPercent,
    DateTime? updatedAt,
  }) {
    return GradeScale(
      id: id,
      name: name ?? this.name,
      bands: bands ?? this.bands,
      createdAt: createdAt,
      organizationId: organizationId ?? this.organizationId,
      isDefault: isDefault ?? this.isDefault,
      passPercent: passPercent ?? this.passPercent,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  Map<String, dynamic> toJson() => Json.compact(<String, dynamic>{
        'id': id,
        'name': name,
        'bands': bands.map((GradeBand b) => b.toJson()).toList(),
        'createdAt': createdAt.toIso8601String(),
        'organizationId': organizationId,
        'isDefault': isDefault,
        'passPercent': passPercent,
        'updatedAt': updatedAt?.toIso8601String(),
      });

  @override
  bool operator ==(Object other) => other is GradeScale && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
