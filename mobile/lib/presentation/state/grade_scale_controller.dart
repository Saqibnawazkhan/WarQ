import '../../app/app_dependencies.dart';
import '../../data/local/data_event_bus.dart';
import '../../data/models/models.dart';
import 'base_controller.dart';

/// Backs the grading scale screen.
///
/// Individual teachers see the platform default read-only; organization admins
/// can edit their organization's scale, which every class in the organization
/// then grades against.
class GradeScaleController extends BaseController {
  GradeScaleController(this._deps, this._user) {
    listenTo(_deps.database.bus, <DataEntity>{
      DataEntity.gradeScales,
      DataEntity.organizations,
    });
  }

  final AppDependencies _deps;
  final AppUser _user;

  GradeScale? _scale;
  List<GradeBand> _draftBands = const <GradeBand>[];
  double _draftPassPercent = 50;
  String _draftName = '';

  GradeScale? get scale => _scale;
  List<GradeBand> get draftBands => _draftBands;
  double get draftPassPercent => _draftPassPercent;
  String get draftName => _draftName;

  /// Only an organization admin may change the scale in Phase 1.
  bool get canEdit => _user.isOrgAdmin && _user.organizationId != null;

  bool get isCustom => _scale?.organizationId != null;

  bool get hasChanges {
    final GradeScale? current = _scale;
    if (current == null) return false;
    if (_draftName != current.name) return true;
    if (_draftPassPercent != current.passPercent) return true;
    if (_draftBands.length != current.bands.length) return true;
    for (int i = 0; i < _draftBands.length; i++) {
      if (_draftBands[i] != current.bands[i]) return true;
    }
    return false;
  }

  @override
  Future<void> load({bool refreshing = false}) async {
    await guardLoad(
      () async {
        _scale = await _deps.gradeScales.resolveFor(
          organizationId: _user.organizationId,
        );
        _resetDraft();
      },
      refreshing: refreshing,
    );
  }

  void _resetDraft() {
    final GradeScale? current = _scale;
    _draftBands = current == null
        ? const <GradeBand>[]
        : List<GradeBand>.of(current.bands);
    _draftPassPercent = current?.passPercent ?? 50;
    _draftName = current?.name ?? 'Custom scale';
  }

  void discardChanges() {
    _resetDraft();
    safeNotify();
  }

  void setName(String value) {
    if (_draftName == value) return;
    _draftName = value;
    safeNotify();
  }

  void setPassPercent(double value) {
    final double clamped = value.clamp(0, 100);
    if (_draftPassPercent == clamped) return;
    _draftPassPercent = clamped;
    safeNotify();
  }

  void updateBand(int index, {String? label, double? minPercent, String? remark}) {
    if (index < 0 || index >= _draftBands.length) return;
    final List<GradeBand> next = List<GradeBand>.of(_draftBands);
    next[index] = next[index].copyWith(
      label: label,
      minPercent: minPercent,
      remark: remark,
    );
    _draftBands = _sorted(next);
    safeNotify();
  }

  void addBand() {
    final List<GradeBand> next = List<GradeBand>.of(_draftBands)
      ..add(const GradeBand(label: 'New', minPercent: 45));
    _draftBands = _sorted(next);
    safeNotify();
  }

  void removeBand(int index) {
    if (index < 0 || index >= _draftBands.length) return;
    if (_draftBands.length <= 2) return;
    final List<GradeBand> next = List<GradeBand>.of(_draftBands)..removeAt(index);
    _draftBands = _sorted(next);
    safeNotify();
  }

  Future<bool> save() async {
    final String? organizationId = _user.organizationId;
    if (organizationId == null) return false;

    final GradeScale? saved = await guardAction<GradeScale>(
      () => _deps.gradeScales.saveForOrganization(
        organizationId: organizationId,
        name: _draftName,
        bands: _draftBands,
        passPercent: _draftPassPercent,
      ),
    );
    if (saved == null) return false;

    _scale = saved;
    _resetDraft();
    await _deps.activity.record(
      actorUserId: _user.id,
      actorName: _user.displayName,
      organizationId: organizationId,
      type: ActivityType.gradeScaleUpdated,
      summary: 'Updated the grading scale',
    );
    safeNotify();
    return true;
  }

  Future<bool> resetToDefault() async {
    final String? organizationId = _user.organizationId;
    if (organizationId == null) return false;
    final GradeScale? reset = await guardAction<GradeScale>(
      () => _deps.gradeScales.resetToDefault(organizationId),
    );
    if (reset == null) return false;
    _scale = reset;
    _resetDraft();
    safeNotify();
    return true;
  }

  List<GradeBand> _sorted(List<GradeBand> bands) {
    final List<GradeBand> copy = List<GradeBand>.of(bands)
      ..sort((GradeBand a, GradeBand b) => b.minPercent.compareTo(a.minPercent));
    return copy;
  }
}
