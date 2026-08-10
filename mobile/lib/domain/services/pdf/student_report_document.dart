import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../entities/attendance_summary.dart';
import '../../entities/student_performance.dart';
import 'pdf_theme.dart';
import 'report_context.dart';

/// Builds the individual student report.
///
/// Sections mirror the product spec: student information, class and teacher,
/// attendance with percentage, every assessment with marks and grade, and the
/// overall result.
///
/// All text goes through [PdfTheme.pdfText], which folds typographic
/// characters to ASCII so the built-in PDF font can render them.
class StudentReportDocument {
  const StudentReportDocument({
    required this.performance,
    required this.context,
    this.schoolClass,
    this.attendanceHistory = const <({DateTime date, AttendanceStatus status})>[],
    this.includeAttendanceLog = true,
  });

  final StudentPerformance performance;
  final ReportContext context;
  final SchoolClass? schoolClass;

  /// Most recent sessions, newest first. Trimmed when the report is long.
  final List<({DateTime date, AttendanceStatus status})> attendanceHistory;
  final bool includeAttendanceLog;

  /// Placeholder printed where a value is missing.
  static const String _blank = '-';

  Student get student => performance.student;

  Future<pw.Document> build() async {
    final pw.Document document = pw.Document(
      title: 'Student report - ${student.fullName}',
      author: context.teacher.displayName,
      creator: 'WarQ',
      subject: 'Academic performance report',
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: PdfTheme.pageTheme(),
        header: (pw.Context ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: PdfTheme.pdfText(
                  '${student.fullName} - student report',
                  style: PdfTheme.subtitle,
                ),
              ),
        footer: (pw.Context ctx) =>
            PdfTheme.footer(ctx, AppDate.formatDateTime(context.generatedAt)),
        build: (pw.Context ctx) => <pw.Widget>[
          _header(),
          pw.SizedBox(height: 16),
          _studentInformation(),
          pw.SizedBox(height: 14),
          _attendanceSection(),
          pw.SizedBox(height: 14),
          _academicSection(),
          pw.SizedBox(height: 14),
          _overallSection(),
          if (includeAttendanceLog && attendanceHistory.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 14),
            _attendanceLog(),
          ],
          pw.SizedBox(height: 18),
          _signatureBlock(),
        ],
      ),
    );

    return document;
  }

  // ---------------------------------------------------------------------------

  pw.Widget _header() {
    return PdfTheme.header(
      title: 'Student Performance Report',
      subtitle: schoolClass == null
          ? 'All classes'
          : '${schoolClass!.name}'
              '${schoolClass!.subtitle.isEmpty ? '' : ' | ${schoolClass!.subtitle}'}',
      meta: <String>[
        context.issuerName,
        'Teacher: ${context.teacher.displayName}',
        'Generated ${AppDate.format(context.generatedAt)}',
      ],
    );
  }

  pw.Widget _studentInformation() {
    final List<({String label, String value})> fields =
        <({String label, String value})>[
      (label: 'Student name', value: student.fullName),
      (label: 'Roll number', value: student.rollNumber ?? _blank),
      (
        label: 'Class',
        value: schoolClass?.displayName ?? performance.className ?? _blank
      ),
      (label: 'Session', value: schoolClass?.session ?? _blank),
      (label: 'Student phone', value: student.studentPhone ?? _blank),
      (label: 'Father phone', value: student.fatherPhone ?? _blank),
      (label: 'Mother phone', value: student.motherPhone ?? _blank),
      (label: 'Email', value: student.email ?? _blank),
      (label: 'Guardian', value: student.guardianName ?? _blank),
    ];

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading('Student information'),
        PdfTheme.card(child: PdfTheme.fieldGrid(fields)),
      ],
    );
  }

  pw.Widget _attendanceSection() {
    final AttendanceSummary attendance = performance.attendance;
    final double? percent = attendance.percentage;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading(
          'Attendance',
          trailing: attendance.hasData
              ? '${attendance.totalSessions} recorded '
                  'session${attendance.totalSessions == 1 ? '' : 's'}'
              : null,
        ),
        if (!attendance.hasData)
          PdfTheme.card(
            child: PdfTheme.pdfText(
              'No attendance has been recorded for this student yet.',
              style: PdfTheme.tableCell,
            ),
          )
        else
          pw.Column(
            children: <pw.Widget>[
              PdfTheme.metricRow(<pw.Widget>[
                PdfTheme.metric('Total classes', '${attendance.totalSessions}'),
                PdfTheme.metric('Present', '${attendance.present}'),
                PdfTheme.metric('Absent', '${attendance.absent}'),
                PdfTheme.metric('Late', '${attendance.late}'),
                PdfTheme.metric(
                  'Attendance',
                  Format.percentOrDash(percent),
                  background: PdfTheme.softColorForPercent(percent),
                  valueColor: PdfTheme.colorForPercent(percent),
                ),
              ]),
              pw.SizedBox(height: 8),
              PdfTheme.bar(
                (percent ?? 0) / 100,
                color: PdfTheme.colorForPercent(percent),
                height: 8,
              ),
              if (attendance.shortLeave > 0) ...<pw.Widget>[
                pw.SizedBox(height: 6),
                PdfTheme.pdfText(
                  '${attendance.shortLeave} short leave '
                  'session${attendance.shortLeave == 1 ? '' : 's'} '
                  'excluded from the percentage.',
                  style: PdfTheme.label,
                ),
              ],
            ],
          ),
      ],
    );
  }

  pw.Widget _academicSection() {
    final List<AssessmentResult> results = performance.results;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading(
          'Assessments and marks',
          trailing: results.isEmpty
              ? null
              : '${performance.gradedCount} of ${results.length} graded',
        ),
        if (results.isEmpty)
          PdfTheme.card(
            child: PdfTheme.pdfText(
              'No assessments have been created for this class yet.',
              style: PdfTheme.tableCell,
            ),
          )
        else
          PdfTheme.table(
            headers: const <String>[
              'Assessment',
              'Type',
              'Date',
              'Marks',
              'Total',
              '%',
              'Grade',
            ],
            columnWidths: const <int, pw.TableColumnWidth>{
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.6),
              2: pw.FlexColumnWidth(1.5),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1),
              6: pw.FlexColumnWidth(1),
            },
            alignments: const <pw.Alignment>[
              pw.Alignment.centerLeft,
              pw.Alignment.centerLeft,
              pw.Alignment.centerLeft,
              pw.Alignment.centerRight,
              pw.Alignment.centerRight,
              pw.Alignment.centerRight,
              pw.Alignment.center,
            ],
            rows: <List<String>>[
              for (final AssessmentResult result in results)
                <String>[
                  result.assessment.name,
                  result.assessment.typeLabel,
                  AppDate.formatShort(result.assessment.date),
                  result.wasAbsent
                      ? 'Absent'
                      : Format.marksOrDash(result.mark?.marksObtained),
                  Format.marks(result.total),
                  Format.percentOrDash(result.percentage),
                  result.grade?.label ?? _blank,
                ],
            ],
          ),
      ],
    );
  }

  pw.Widget _overallSection() {
    final double? percent = performance.percentage;
    final GradeBand? grade = performance.grade;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading('Overall performance'),
        PdfTheme.card(
          background: PdfTheme.softColorForPercent(percent),
          borderColor: PdfTheme.colorForPercent(percent),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              pw.Expanded(
                flex: 3,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    PdfTheme.pdfText(
                      'TOTAL MARKS OBTAINED',
                      style: PdfTheme.label,
                    ),
                    pw.SizedBox(height: 3),
                    PdfTheme.pdfText(
                      performance.hasMarks
                          ? '${Format.marks(performance.obtainedTotal)} '
                              '/ ${Format.marks(performance.maxTotal)}'
                          : 'Not graded yet',
                      style: PdfTheme.metricValue,
                    ),
                    if (performance.pendingCount > 0) ...<pw.Widget>[
                      pw.SizedBox(height: 3),
                      PdfTheme.pdfText(
                        '${performance.pendingCount} assessment'
                        '${performance.pendingCount == 1 ? '' : 's'} not graded '
                        'and excluded from this total.',
                        style: PdfTheme.label,
                      ),
                    ],
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    PdfTheme.pdfText('PERCENTAGE', style: PdfTheme.label),
                    pw.SizedBox(height: 3),
                    PdfTheme.pdfText(
                      Format.percentOrDash(percent),
                      style: PdfTheme.metricValue.copyWith(
                        color: PdfTheme.colorForPercent(percent),
                      ),
                    ),
                  ],
                ),
              ),
              pw.Expanded(
                flex: 2,
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: <pw.Widget>[
                    PdfTheme.pdfText('GRADE', style: PdfTheme.label),
                    pw.SizedBox(height: 3),
                    PdfTheme.pdfText(
                      grade?.label ?? _blank,
                      style: PdfTheme.metricValue.copyWith(
                        color: PdfTheme.colorForPercent(percent),
                      ),
                    ),
                    if (grade?.remark != null)
                      PdfTheme.pdfText(grade!.remark!, style: PdfTheme.label),
                  ],
                ),
              ),
            ],
          ),
        ),
        pw.SizedBox(height: 8),
        PdfTheme.pdfText(
          'Grading scale: ${context.gradeScale.name} - '
          '${_scaleDescription(context.gradeScale)}',
          style: PdfTheme.label,
        ),
      ],
    );
  }

  pw.Widget _attendanceLog() {
    final List<({DateTime date, AttendanceStatus status})> rows =
        attendanceHistory.take(40).toList();

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading(
          'Attendance log',
          trailing: attendanceHistory.length > rows.length
              ? 'Showing the ${rows.length} most recent sessions'
              : null,
        ),
        PdfTheme.table(
          headers: const <String>['Date', 'Day', 'Status'],
          columnWidths: const <int, pw.TableColumnWidth>{
            0: pw.FlexColumnWidth(2),
            1: pw.FlexColumnWidth(1.4),
            2: pw.FlexColumnWidth(1.4),
          },
          rows: <List<String>>[
            for (final ({DateTime date, AttendanceStatus status}) row in rows)
              <String>[
                AppDate.format(row.date),
                AppDate.formatWeekday(row.date),
                row.status.label,
              ],
          ],
        ),
      ],
    );
  }

  pw.Widget _signatureBlock() {
    return pw.Row(
      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
      children: <pw.Widget>[
        _signatureLine('Class teacher'),
        _signatureLine('Parent / Guardian'),
      ],
    );
  }

  pw.Widget _signatureLine(String label) {
    return pw.SizedBox(
      width: 180,
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: <pw.Widget>[
          pw.SizedBox(height: 22),
          pw.Container(height: 0.7, color: PdfTheme.border),
          pw.SizedBox(height: 4),
          PdfTheme.pdfText(label, style: PdfTheme.label),
        ],
      ),
    );
  }

  String _scaleDescription(GradeScale scale) {
    return scale.bands
        .map((GradeBand band) {
          final ({double min, double? max}) range = scale.rangeFor(band);
          final String upper =
              range.max == null ? '100' : Format.marks(range.max! - 0.1);
          return '${band.label} ${Format.marks(range.min)}-$upper';
        })
        .join(' | ');
  }
}
