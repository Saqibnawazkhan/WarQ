import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/error/failure.dart';
import '../../../core/utils/formatters.dart';
import '../../local/data_event_bus.dart';
import '../../models/models.dart';
import '../../remote/supabase_mappers.dart';
import '../grade_scale_repository.dart';
import 'supabase_repository_base.dart';

/// Grading scales backed by Supabase.
///
/// One row per organization, plus a single row with a null organization that is
/// the platform default. An independent teacher grades by that default, and so
/// does an organization that has never set its own — which is why [resolveFor]
/// falls back rather than failing.
///
/// The database validates the bands themselves: they must descend, cover every
/// percentage from 0 to 100 without a gap, and bottom out at zero. A scale that
/// does not comes back as a rejected write rather than a silently broken report.
class SupabaseGradeScaleRepository extends SupabaseRepositoryBase
    implements GradeScaleRepository {
  SupabaseGradeScaleRepository(super.client, super.bus);

  SupabaseQueryBuilder get _table => client.from('grade_scales');

  @override
  Future<GradeScale> resolveFor({String? organizationId}) {
    return read(() async {
      if (organizationId != null) {
        final Map<String, dynamic>? own = await _table
            .select('*')
            .eq('organization_id', organizationId)
            .maybeSingle();
        if (own != null) return Rows.gradeScale(own);
      }
      return await _platformDefault();
    });
  }

  @override
  Future<List<GradeScale>> list() {
    return read(() async {
      final List<Map<String, dynamic>> rows =
          await _table.select('*').order('created_at');
      return rows.map(Rows.gradeScale).toList(growable: false);
    });
  }

  @override
  Future<GradeScale?> findById(String id) {
    return read(() async {
      final Map<String, dynamic>? row =
          await _table.select('*').eq('id', id).maybeSingle();
      return row == null ? null : Rows.gradeScale(row);
    });
  }

  @override
  Future<GradeScale> saveForOrganization({
    required String organizationId,
    required String name,
    required List<GradeBand> bands,
    required double passPercent,
  }) {
    final String cleanName = Format.clean(name);
    if (cleanName.isEmpty) {
      throw const AppFailure.validation('Give the grading scale a name.');
    }
    if (bands.isEmpty) {
      throw const AppFailure.validation('A grading scale needs at least one band.');
    }

    // Upsert on organization_id rather than insert-or-update: the unique index
    // is what guarantees one scale per organization, so letting it arbitrate
    // avoids a lost update when the settings screen is open twice.
    return write(
      () async {
        final Map<String, dynamic> row = await _table.upsert(
          <String, dynamic>{
            'organization_id': organizationId,
            'name': cleanName,
            'bands': Rows.bandsToDb(bands),
            'pass_percent': passPercent,
            'updated_at': DateTime.now().toUtc().toIso8601String(),
          },
          onConflict: 'organization_id',
        ).select('*').single();
        return Rows.gradeScale(row);
      },
      touches: <DataEntity>{DataEntity.gradeScales},
    );
  }

  @override
  Future<GradeScale> resetToDefault(String organizationId) async {
    // Removing the organization's own row is what "reset" means here: with
    // nothing of their own, they grade by the platform default again, and the
    // default cannot drift out of step with a copy of itself.
    await write(
      () => _table.delete().eq('organization_id', organizationId),
      touches: <DataEntity>{DataEntity.gradeScales},
    );
    return read(_platformDefault);
  }

  /// The scale everyone falls back to.
  ///
  /// A project that has never had one seeded still has to grade, so this
  /// answers from the app's own defaults rather than failing — the bands are
  /// the same ones the database would have been seeded with.
  Future<GradeScale> _platformDefault() async {
    final Map<String, dynamic>? row =
        await _table.select('*').isFilter('organization_id', null).maybeSingle();
    if (row != null) return Rows.gradeScale(row);

    return GradeScale(
      id: 'default',
      name: 'Standard scale',
      bands: GradeScale.defaultBands,
      createdAt: DateTime.now(),
      isDefault: true,
    );
  }
}
