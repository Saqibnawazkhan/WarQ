import '../models/models.dart';

/// Fields accepted when creating or editing a class. Only [name] is required.
class ClassDraft {
  const ClassDraft({
    required this.name,
    this.subject,
    this.section,
    this.session,
    this.description,
  });

  final String name;
  final String? subject;
  final String? section;
  final String? session;
  final String? description;
}

/// CRUD for classes plus the aggregate counts the list screens need.
abstract class ClassRepository {
  /// Classes owned by [teacherId], newest first unless [alphabetical].
  Future<List<SchoolClass>> listForTeacher(
    String teacherId, {
    bool includeArchived = false,
    bool alphabetical = false,
  });

  /// Every class inside an organization — the organization admin view.
  Future<List<SchoolClass>> listForOrganization(
    String organizationId, {
    bool includeArchived = false,
  });

  Future<SchoolClass?> findById(String classId);

  Future<SchoolClass> create({
    required String teacherId,
    required ClassDraft draft,
    String? organizationId,
  });

  Future<SchoolClass> update(String classId, ClassDraft draft);

  Future<SchoolClass> setArchived(String classId, bool archived);

  /// Removes the class and all attendance, assessments and enrollments that
  /// belong to it. Student records themselves are preserved.
  Future<void> delete(String classId);

  /// Number of actively enrolled students per class id.
  Future<Map<String, int>> studentCounts(Iterable<String> classIds);
}
