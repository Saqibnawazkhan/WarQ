import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:printing/printing.dart';

import '../../core/error/failure.dart';
import '../../core/utils/date_utils.dart';
import '../../data/models/models.dart';
import '../../data/repositories/activity_repository.dart';
import '../../data/repositories/attendance_repository.dart';
import '../../data/repositories/class_repository.dart';
import '../../data/repositories/grade_scale_repository.dart';
import '../../data/repositories/organization_repository.dart';
import '../../data/repositories/student_repository.dart';
import '../entities/student_performance.dart';
import 'analytics_service.dart';
import 'pdf/class_report_document.dart';
import 'pdf/report_context.dart';
import 'pdf/student_report_document.dart';

/// A rendered PDF held in memory, ready to preview, share, print or save.
class GeneratedReport {
  const GeneratedReport({
    required this.bytes,
    required this.fileName,
    required this.title,
    required this.subtitle,
    required this.isLandscape,
  });

  final Uint8List bytes;
  final String fileName;
  final String title;
  final String subtitle;
  final bool isLandscape;

  PdfPageFormat get pageFormat =>
      isLandscape ? PdfPageFormat.a4.landscape : PdfPageFormat.a4;

  int get sizeInKb => (bytes.lengthInBytes / 1024).ceil();
}

/// Builds, saves and shares the PDF reports.
///
/// Screens never touch the `pdf`/`printing` packages directly — they ask this
/// service for a [GeneratedReport] and hand it to the preview screen.
class ReportService {
  ReportService({
    required AnalyticsService analytics,
    required ClassRepository classes,
    required StudentRepository students,
    required AttendanceRepository attendance,
    required GradeScaleRepository gradeScales,
    required OrganizationRepository organizations,
    required ActivityRepository activity,
  })  : _analytics = analytics,
        _classes = classes,
        _students = students,
        _attendance = attendance,
        _gradeScales = gradeScales,
        _organizations = organizations,
        _activity = activity;

  final AnalyticsService _analytics;
  final ClassRepository _classes;
  final StudentRepository _students;
  final AttendanceRepository _attendance;
  final GradeScaleRepository _gradeScales;
  final OrganizationRepository _organizations;
  final ActivityRepository _activity;

  /// Individual student report. [classId] scopes it to a single class; when
  /// omitted the report spans every class the student is enrolled in.
  Future<GeneratedReport> studentReport({
    required String studentId,
    required AppUser teacher,
    String? classId,
  }) async {
    final Student? student = await _students.findById(studentId);
    if (student == null) throw const AppFailure.notFound('That student');

    final StudentPerformance performance = await _analytics.studentPerformance(
      studentId: studentId,
      classId: classId,
    );
    final SchoolClass? schoolClass =
        classId == null ? null : await _classes.findById(classId);
    final ReportContext context = await _context(
      teacher: teacher,
      organizationId: schoolClass?.organizationId ?? teacher.organizationId,
    );

    final StudentReportDocument document = StudentReportDocument(
      performance: performance,
      context: context,
      schoolClass: schoolClass,
      attendanceHistory: await _attendanceHistory(
        studentId: studentId,
        classId: classId,
      ),
    );

    final Uint8List bytes = await (await document.build()).save();

    await _activity.record(
      actorUserId: teacher.id,
      actorName: teacher.displayName,
      organizationId: schoolClass?.organizationId ?? teacher.organizationId,
      type: ActivityType.reportGenerated,
      summary: 'Generated a report for ${student.fullName}',
      entityType: 'student',
      entityId: studentId,
      classId: classId,
    );

    return GeneratedReport(
      bytes: bytes,
      fileName: _fileName(<String>[
        'student-report',
        student.fullName,
        if (schoolClass != null) schoolClass.name,
      ]),
      title: '${student.fullName} — report',
      subtitle: schoolClass?.name ?? 'All classes',
      isLandscape: false,
    );
  }

  /// Complete class report: roster, attendance, marks matrix and grades.
  Future<GeneratedReport> classReport({
    required String classId,
    required AppUser teacher,
  }) async {
    final ClassPerformance performance =
        await _analytics.classPerformance(classId);
    final ReportContext context = await _context(
      teacher: teacher,
      organizationId: performance.schoolClass.organizationId,
    );

    // Beyond ~10 assessments the per-assessment matrix stops being legible on
    // A4 landscape, so it is omitted and the summary table carries the totals.
    final int assessmentCount = performance.assessmentCount;

    final ClassReportDocument document = ClassReportDocument(
      performance: performance,
      context: context,
      includeMarksMatrix: assessmentCount > 0 && assessmentCount <= 10,
    );

    final Uint8List bytes = await (await document.build()).save();

    await _activity.record(
      actorUserId: teacher.id,
      actorName: teacher.displayName,
      organizationId: performance.schoolClass.organizationId,
      type: ActivityType.reportGenerated,
      summary: 'Generated a class report for ${performance.schoolClass.name}',
      entityType: 'class',
      entityId: classId,
      classId: classId,
    );

    return GeneratedReport(
      bytes: bytes,
      fileName: _fileName(<String>['class-report', performance.schoolClass.name]),
      title: '${performance.schoolClass.name} — class report',
      subtitle: '${performance.studentCount} students',
      isLandscape: true,
    );
  }

  /// Opens the platform share sheet with the PDF attached.
  Future<void> share(GeneratedReport report) async {
    await Printing.sharePdf(bytes: report.bytes, filename: report.fileName);
  }

  /// Opens the platform print/save dialog.
  Future<void> printDocument(GeneratedReport report) async {
    await Printing.layoutPdf(
      onLayout: (PdfPageFormat _) async => report.bytes,
      name: report.fileName,
      format: report.pageFormat,
    );
  }

  /// Writes the PDF into the app's documents directory and returns its path.
  Future<String> saveToDevice(GeneratedReport report) async {
    try {
      final Directory directory = await getApplicationDocumentsDirectory();
      final Directory reportsDir =
          Directory('${directory.path}${Platform.pathSeparator}reports');
      if (!reportsDir.existsSync()) {
        reportsDir.createSync(recursive: true);
      }
      final String path =
          '${reportsDir.path}${Platform.pathSeparator}${report.fileName}';
      final File file = File(path);
      await file.writeAsBytes(report.bytes, flush: true);
      return path;
    } on FileSystemException catch (error) {
      throw AppFailure.storage(
        'Could not save the report to this device.',
        details: error,
      );
    }
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<ReportContext> _context({
    required AppUser teacher,
    String? organizationId,
  }) async {
    final Organization? organization = organizationId == null
        ? null
        : await _organizations.findById(organizationId);
    final GradeScale scale =
        await _gradeScales.resolveFor(organizationId: organizationId);
    return ReportContext(
      teacher: teacher,
      organization: organization,
      gradeScale: scale,
    );
  }

  Future<List<({DateTime date, AttendanceStatus status})>> _attendanceHistory({
    required String studentId,
    String? classId,
  }) async {
    final List<AttendanceRecord> records =
        await _attendance.recordsForStudent(studentId, classId: classId);
    if (records.isEmpty) {
      return const <({DateTime date, AttendanceStatus status})>[];
    }

    final Set<String> classIds =
        records.map((AttendanceRecord r) => r.classId).toSet();
    final Map<String, DateTime> sessionDates = <String, DateTime>{};
    for (final String id in classIds) {
      for (final AttendanceSession session
          in await _attendance.sessionsForClass(id)) {
        sessionDates[session.id] = session.date;
      }
    }

    final List<({DateTime date, AttendanceStatus status})> history =
        <({DateTime date, AttendanceStatus status})>[
      for (final AttendanceRecord record in records)
        if (sessionDates[record.sessionId] != null)
          (date: sessionDates[record.sessionId]!, status: record.status),
    ]..sort((({DateTime date, AttendanceStatus status}) a,
              ({DateTime date, AttendanceStatus status}) b) =>
          b.date.compareTo(a.date));
    return history;
  }

  /// Builds a filesystem-safe, dated file name.
  String _fileName(List<String> parts) {
    final String slug = parts
        .map((String part) => part
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '-')
            .replaceAll(RegExp(r'^-+|-+$'), ''))
        .where((String part) => part.isNotEmpty)
        .join('-');
    final String stamp = AppDate.toIso(DateTime.now());
    return '$slug-$stamp.pdf';
  }
}
