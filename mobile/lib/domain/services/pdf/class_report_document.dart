import 'package:pdf/widgets.dart' as pw;

import '../../../core/utils/date_utils.dart';
import '../../../core/utils/formatters.dart';
import '../../../data/models/models.dart';
import '../../entities/student_performance.dart';
import 'pdf_theme.dart';
import 'report_context.dart';

/// Builds the complete class report.
///
/// Laid out in landscape because the marks matrix is wide: one column per
/// assessment plus attendance, total, percentage and grade.
class ClassReportDocument {
  const ClassReportDocument({
    required this.performance,
    required this.context,
    this.includeMarksMatrix = true,
  });

  final ClassPerformance performance;
  final ReportContext context;

  /// The per-assessment matrix is dropped when there are too many assessments
  /// to stay readable on one page width.
  final bool includeMarksMatrix;

  /// Placeholder printed where a value is missing.
  static const String _blank = '-';

  SchoolClass get schoolClass => performance.schoolClass;

  /// Assessments in chronological order, taken from the first student's
  /// results (every student carries the same assessment list).
  List<Assessment> get _assessments {
    if (performance.students.isEmpty) return const <Assessment>[];
    return performance.students.first.results
        .map((AssessmentResult r) => r.assessment)
        .toList(growable: false);
  }

  Future<pw.Document> build() async {
    final pw.Document document = pw.Document(
      title: 'Class report - ${schoolClass.name}',
      author: context.teacher.displayName,
      creator: 'EDU Manager',
      subject: 'Class performance report',
    );

    document.addPage(
      pw.MultiPage(
        pageTheme: PdfTheme.pageTheme(landscape: true),
        header: (pw.Context ctx) => ctx.pageNumber == 1
            ? pw.SizedBox()
            : pw.Padding(
                padding: const pw.EdgeInsets.only(bottom: 10),
                child: PdfTheme.pdfText(
                  '${schoolClass.name} - class report',
                  style: PdfTheme.subtitle,
                ),
              ),
        footer: (pw.Context ctx) =>
            PdfTheme.footer(ctx, AppDate.formatDateTime(context.generatedAt)),
        build: (pw.Context ctx) => <pw.Widget>[
          _header(),
          pw.SizedBox(height: 16),
          _classInformation(),
          pw.SizedBox(height: 14),
          _summaryMetrics(),
          pw.SizedBox(height: 14),
          _gradeDistribution(),
          pw.SizedBox(height: 14),
          _studentTable(),
          if (includeMarksMatrix && _assessments.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 14),
            _marksMatrix(),
          ],
          if (performance.atRisk.isNotEmpty) ...<pw.Widget>[
            pw.SizedBox(height: 14),
            _attentionSection(),
          ],
        ],
      ),
    );

    return document;
  }

  // ---------------------------------------------------------------------------

  pw.Widget _header() {
    return PdfTheme.header(
      title: 'Class Performance Report',
      subtitle: schoolClass.subtitle.isEmpty
          ? schoolClass.name
          : '${schoolClass.name} | ${schoolClass.subtitle}',
      meta: <String>[
        context.issuerName,
        'Teacher: ${context.teacher.displayName}',
        'Generated ${AppDate.format(context.generatedAt)}',
      ],
    );
  }

  pw.Widget _classInformation() {
    return PdfTheme.card(
      child: PdfTheme.fieldGrid(
        <({String label, String value})>[
          (label: 'Class name', value: schoolClass.name),
          (label: 'Subject', value: schoolClass.subject ?? _blank),
          (label: 'Section', value: schoolClass.section ?? _blank),
          (label: 'Session', value: schoolClass.session ?? _blank),
          (label: 'Teacher', value: context.teacherLine),
          (
            label: 'Organization',
            value: context.organization?.name ?? 'Individual teacher'
          ),
        ],
        columns: 3,
      ),
    );
  }

  pw.Widget _summaryMetrics() {
    final double? average = performance.averagePercentage;
    final double? attendance = performance.averageAttendance;

    return PdfTheme.metricRow(<pw.Widget>[
      PdfTheme.metric('Students', '${performance.studentCount}'),
      PdfTheme.metric('Assessments', '${performance.assessmentCount}'),
      PdfTheme.metric('Attendance sessions', '${performance.sessionCount}'),
      PdfTheme.metric(
        'Average attendance',
        Format.percentOrDash(attendance),
        background: PdfTheme.softColorForPercent(attendance),
        valueColor: PdfTheme.colorForPercent(attendance),
      ),
      PdfTheme.metric(
        'Class average',
        Format.percentOrDash(average),
        background: PdfTheme.softColorForPercent(average),
        valueColor: PdfTheme.colorForPercent(average),
      ),
    ]);
  }

  pw.Widget _gradeDistribution() {
    final Map<String, int> distribution = performance.gradeDistribution;
    final int total = distribution.values.fold<int>(0, (int a, int b) => a + b);

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading(
          'Grade distribution',
          trailing: total == 0
              ? 'No graded students yet'
              : '$total graded student${total == 1 ? '' : 's'}',
        ),
        PdfTheme.card(
          child: pw.Column(
            children: <pw.Widget>[
              for (final MapEntry<String, int> entry in distribution.entries)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.center,
                    children: <pw.Widget>[
                      pw.SizedBox(
                        width: 34,
                        child: PdfTheme.pdfText(entry.key, style: PdfTheme.value),
                      ),
                      pw.Expanded(
                        child: PdfTheme.bar(
                          total == 0 ? 0 : entry.value / total,
                          color: PdfTheme.brand,
                          height: 8,
                        ),
                      ),
                      pw.SizedBox(width: 8),
                      pw.SizedBox(
                        width: 70,
                        child: PdfTheme.pdfText(
                          total == 0
                              ? '0'
                              : '${entry.value} '
                                  '(${Format.percent(entry.value / total * 100, decimals: 0)})',
                          style: PdfTheme.tableCell,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  pw.Widget _studentTable() {
    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading('Student summary', trailing: 'Sorted A-Z'),
        if (performance.students.isEmpty)
          PdfTheme.card(
            child: PdfTheme.pdfText(
              'No students are enrolled in this class yet.',
              style: PdfTheme.tableCell,
            ),
          )
        else
          PdfTheme.table(
            headers: const <String>[
              '#',
              'Student',
              'Roll no.',
              'Present',
              'Absent',
              'Attendance',
              'Marks',
              'Percentage',
              'Grade',
            ],
            columnWidths: const <int, pw.TableColumnWidth>{
              0: pw.FlexColumnWidth(0.5),
              1: pw.FlexColumnWidth(3),
              2: pw.FlexColumnWidth(1.6),
              3: pw.FlexColumnWidth(1),
              4: pw.FlexColumnWidth(1),
              5: pw.FlexColumnWidth(1.4),
              6: pw.FlexColumnWidth(1.6),
              7: pw.FlexColumnWidth(1.4),
              8: pw.FlexColumnWidth(1),
            },
            alignments: const <pw.Alignment>[
              pw.Alignment.centerLeft,
              pw.Alignment.centerLeft,
              pw.Alignment.centerLeft,
              pw.Alignment.centerRight,
              pw.Alignment.centerRight,
              pw.Alignment.centerRight,
              pw.Alignment.centerRight,
              pw.Alignment.centerRight,
              pw.Alignment.center,
            ],
            rows: <List<String>>[
              for (int i = 0; i < performance.students.length; i++)
                _studentRow(i, performance.students[i]),
            ],
          ),
      ],
    );
  }

  List<String> _studentRow(int index, StudentPerformance student) {
    return <String>[
      '${index + 1}',
      student.student.fullName,
      student.student.rollNumber ?? _blank,
      '${student.attendance.present}',
      '${student.attendance.absent}',
      Format.percentOrDash(student.attendance.percentage),
      student.hasMarks
          ? '${Format.marks(student.obtainedTotal)}/${Format.marks(student.maxTotal)}'
          : _blank,
      Format.percentOrDash(student.percentage),
      student.grade?.label ?? _blank,
    ];
  }

  pw.Widget _marksMatrix() {
    final List<Assessment> assessments = _assessments;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading(
          'Marks by assessment',
          trailing:
              '${assessments.length} assessment${assessments.length == 1 ? '' : 's'}',
        ),
        PdfTheme.table(
          headers: <String>[
            'Student',
            for (final Assessment assessment in assessments)
              '${assessment.name}\n(${Format.marks(assessment.totalMarks)})',
            'Total',
          ],
          columnWidths: <int, pw.TableColumnWidth>{
            0: const pw.FlexColumnWidth(2.6),
            for (int i = 0; i < assessments.length; i++)
              i + 1: const pw.FlexColumnWidth(1),
            assessments.length + 1: const pw.FlexColumnWidth(1.3),
          },
          alignments: <pw.Alignment>[
            pw.Alignment.centerLeft,
            for (int i = 0; i < assessments.length; i++) pw.Alignment.centerRight,
            pw.Alignment.centerRight,
          ],
          rows: <List<String>>[
            for (final StudentPerformance student in performance.students)
              <String>[
                student.student.fullName,
                for (final AssessmentResult result in student.results)
                  result.wasAbsent
                      ? 'Abs'
                      : Format.marksOrDash(result.mark?.marksObtained),
                student.hasMarks
                    ? '${Format.marks(student.obtainedTotal)}/${Format.marks(student.maxTotal)}'
                    : _blank,
              ],
          ],
        ),
      ],
    );
  }

  pw.Widget _attentionSection() {
    final List<StudentPerformance> risky = performance.atRisk;

    return pw.Column(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: <pw.Widget>[
        PdfTheme.sectionHeading(
          'Students needing attention',
          trailing: '${risky.length} of ${performance.studentCount}',
        ),
        PdfTheme.card(
          background: PdfTheme.warningSoft,
          borderColor: PdfTheme.warning,
          child: pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: <pw.Widget>[
              for (final StudentPerformance student in risky)
                pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 4),
                  child: PdfTheme.pdfText(
                    '${student.student.fullName} - '
                    'attendance ${Format.percentOrDash(student.attendance.percentage)}, '
                    'marks ${Format.percentOrDash(student.percentage)}'
                    '${_reasonFor(student)}',
                    style: PdfTheme.tableCell,
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  String _reasonFor(StudentPerformance student) {
    final List<String> reasons = <String>[
      if (student.hasLowAttendance) 'low attendance',
      if (student.isUnderperforming) 'below passing marks',
    ];
    return reasons.isEmpty ? '' : ' (${reasons.join(', ')})';
  }
}
