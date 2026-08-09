import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/id_generator.dart';
import '../../local/data_event_bus.dart';
import '../../local/local_database.dart';
import '../../models/models.dart';
import '../grade_scale_repository.dart';

/// On-device implementation of [GradeScaleRepository].
class LocalGradeScaleRepository implements GradeScaleRepository {
  LocalGradeScaleRepository(this._db);

  final LocalDatabase _db;

  @override
  Future<GradeScale> resolveFor({String? organizationId}) async {
    if (organizationId != null) {
      final Organization? organization = _db.organizations.byId(organizationId);
      final GradeScale? assigned = _db.gradeScales.byId(organization?.gradeScaleId);
      if (assigned != null) return assigned;

      final GradeScale? owned = _db.gradeScales.firstWhereOrNull(
        (GradeScale s) => s.organizationId == organizationId,
      );
      if (owned != null) return owned;
    }
    return _db.gradeScales.byId(GradeScale.defaultId) ??
        GradeScale.platformDefault();
  }

  @override
  Future<List<GradeScale>> list() async => _db.gradeScales.all;

  @override
  Future<GradeScale?> findById(String id) async => _db.gradeScales.byId(id);

  @override
  Future<GradeScale> saveForOrganization({
    required String organizationId,
    required String name,
    required List<GradeBand> bands,
    required double passPercent,
  }) async {
    _validate(bands);

    final GradeScale? existing = _db.gradeScales.firstWhereOrNull(
      (GradeScale s) => s.organizationId == organizationId,
    );

    final GradeScale scale = existing == null
        ? GradeScale(
            id: IdGenerator.generate('gsc'),
            name: Format.clean(name),
            bands: bands,
            createdAt: DateTime.now(),
            organizationId: organizationId,
            passPercent: passPercent,
          )
        : existing.copyWith(
            name: Format.clean(name),
            bands: bands,
            passPercent: passPercent,
            updatedAt: DateTime.now(),
          );

    await _db.gradeScales.put(scale);

    final Organization? organization = _db.organizations.byId(organizationId);
    if (organization != null && organization.gradeScaleId != scale.id) {
      await _db.organizations.put(
        organization.copyWith(gradeScaleId: scale.id, updatedAt: DateTime.now()),
      );
      _db.bus.emit(DataEntity.organizations, id: organizationId);
    }
    _db.bus.emit(DataEntity.gradeScales, id: scale.id);
    return scale;
  }

  @override
  Future<GradeScale> resetToDefault(String organizationId) async {
    final Organization? organization = _db.organizations.byId(organizationId);
    if (organization != null) {
      await _db.organizations.put(
        organization.copyWith(
          gradeScaleId: GradeScale.defaultId,
          updatedAt: DateTime.now(),
        ),
      );
      _db.bus.emit(DataEntity.organizations, id: organizationId);
    }
    await _db.gradeScales
        .deleteWhere((GradeScale s) => s.organizationId == organizationId);
    _db.bus.emit(DataEntity.gradeScales);
    return _db.gradeScales.byId(GradeScale.defaultId) ??
        GradeScale.platformDefault();
  }

  void _validate(List<GradeBand> bands) {
    if (bands.isEmpty) {
      throw const AppFailure.validation('Add at least one grade band.');
    }
    if (bands.any((GradeBand b) => Format.clean(b.label).isEmpty)) {
      throw const AppFailure.validation('Every grade band needs a label.');
    }
    if (bands.any((GradeBand b) => b.minPercent < 0 || b.minPercent > 100)) {
      throw const AppFailure.validation(
        'Grade thresholds must be between 0 and 100.',
      );
    }
    final Set<double> thresholds =
        bands.map((GradeBand b) => b.minPercent).toSet();
    if (thresholds.length != bands.length) {
      throw const AppFailure.validation(
        'Two grade bands cannot share the same threshold.',
      );
    }
    if (!bands.any((GradeBand b) => b.minPercent == 0)) {
      throw const AppFailure.validation(
        'The lowest band must start at 0 so every score has a grade.',
      );
    }
  }
}
