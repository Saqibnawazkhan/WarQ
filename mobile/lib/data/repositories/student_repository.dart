import '../models/models.dart';

/// Fields accepted when creating or editing a student.
///
/// Everything except [fullName] is optional, matching the product spec.
class StudentDraft {
  const StudentDraft({
    required this.fullName,
    this.rollNumber,
    this.studentPhone,
    this.fatherPhone,
    this.motherPhone,
    this.guardianName,
    this.email,
    this.address,
    this.notes,
  });

  final String fullName;
  final String? rollNumber;
  final String? studentPhone;
  final String? fatherPhone;
  final String? motherPhone;
  final String? guardianName;
  final String? email;
  final String? address;
  final String? notes;
}

/// Students and their class enrollments.
abstract class StudentRepository {
  /// Actively enrolled students of a class, sorted A–Z by name.
  Future<List<Student>> listForClass(String classId);

  /// Every student created by a teacher, sorted A–Z. Used by global search and
  /// by the "enroll an existing student" picker.
  Future<List<Student>> listForTeacher(String teacherId);

  Future<List<Student>> listForOrganization(String organizationId);

  Future<Student?> findById(String studentId);

  /// Creates the student and, when [classId] is given, enrolls them.
  Future<Student> create({
    required String teacherId,
    required StudentDraft draft,
    String? classId,
    String? organizationId,
  });

  Future<Student> update(String studentId, StudentDraft draft);

  /// Deletes the student record along with their attendance and marks.
  Future<void> delete(String studentId);

  Future<ClassEnrollment> enroll({
    required String classId,
    required String studentId,
  });

  /// Detaches the student from the class while preserving history.
  Future<void> unenroll({required String classId, required String studentId});

  /// Class ids the student is actively enrolled in.
  Future<List<String>> classIdsFor(String studentId);

  Future<List<ClassEnrollment>> enrollmentsForClass(String classId);
}
