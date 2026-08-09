import '../models/models.dart';

/// Grading scales.
///
/// Phase 1 exposes read access plus editing of an organization's own scale.
/// The structure already supports several scales so per-class or per-subject
/// grading can be added later without a migration.
abstract class GradeScaleRepository {
  /// The scale that applies to [organizationId], falling back to the platform
  /// default for individual teachers.
  Future<GradeScale> resolveFor({String? organizationId});

  Future<List<GradeScale>> list();

  Future<GradeScale?> findById(String id);

  /// Creates or updates the organization's scale.
  Future<GradeScale> saveForOrganization({
    required String organizationId,
    required String name,
    required List<GradeBand> bands,
    required double passPercent,
  });

  Future<GradeScale> resetToDefault(String organizationId);
}
