import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../../app/app_dependencies.dart';
import '../../../../core/extensions/context_extensions.dart';
import '../../../../core/routing/route_args.dart';
import '../../../../core/routing/route_names.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/utils/date_utils.dart';
import '../../../../core/utils/formatters.dart';
import '../../../../data/models/models.dart';
import '../../../../domain/entities/attendance_summary.dart';
import '../../../../domain/entities/student_performance.dart';
import '../../../../domain/services/report_service.dart';
import '../../../state/session_controller.dart';
import '../../../state/student_profile_controller.dart';
import '../../../widgets/charts/bar_chart.dart';
import '../../../widgets/charts/chart_data.dart';
import '../../../widgets/charts/donut_chart.dart';
import '../../../widgets/charts/trend_chart.dart';
import '../../../widgets/common/app_avatar.dart';
import '../../../widgets/common/app_badge.dart';
import '../../../widgets/common/app_card.dart';
import '../../../widgets/common/stat_tile.dart';
import '../../../widgets/feedback/dialogs.dart';
import '../../../widgets/feedback/state_views.dart';
import '../../../widgets/layout/app_page.dart';

/// Student profile and performance.
///
/// [readOnly] is used by the organization admin's monitoring view, which may
/// inspect a student but must not edit or delete the teacher's records.
class StudentDetailScreen extends StatelessWidget {
  const StudentDetailScreen({
    super.key,
    required this.args,
    this.readOnly = false,
  });

  final StudentDetailArgs args;
  final bool readOnly;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<StudentProfileController>(
      create: (BuildContext context) => StudentProfileController(
        context.read<AppDependencies>(),
        args.studentId,
        classId: args.classId,
      )..load(),
      child: _StudentDetailView(readOnly: readOnly),
    );
  }
}

class _StudentDetailView extends StatelessWidget {
  const _StudentDetailView({required this.readOnly});

  final bool readOnly;

  Future<void> _generateReport(
    BuildContext context,
    StudentProfileController controller,
  ) async {
    final Student? student = controller.student;
    if (student == null) return;

    final AppDependencies deps = context.read<AppDependencies>();
    final AppUser teacher = context.read<SessionController>().requireUser;

    try {
      final GeneratedReport report = await withBlockingProgress(
        context,
        message: 'Building report…',
        () => deps.reports.studentReport(
          studentId: student.id,
          teacher: teacher,
          classId: controller.classId,
        ),
      );
      if (!context.mounted) return;
      Navigator.of(context).pushNamed(
        Routes.reportPreview,
        arguments: ReportPreviewArgs(report: report),
      );
    } catch (_) {
      if (!context.mounted) return;
      context.showError('Could not generate the report. Please try again.');
    }
  }

  Future<void> _delete(
    BuildContext context,
    StudentProfileController controller,
  ) async {
    final Student? student = controller.student;
    if (student == null) return;

    final bool confirmed = await showConfirmDialog(
      context,
      title: 'Delete ${student.fullName}?',
      message: 'This permanently deletes the student along with their '
          'attendance records and marks in every class.',
      confirmLabel: 'Delete',
      isDestructive: true,
      icon: Icons.delete_outline_rounded,
    );
    if (!confirmed || !context.mounted) return;

    final bool ok = await controller.deleteStudent();
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
      context.showSuccess('${student.fullName} deleted.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final StudentProfileController controller =
        context.watch<StudentProfileController>();
    final Student? student = controller.student;
    final StudentPerformance? performance = controller.performance;

    return Scaffold(
      appBar: AppBar(
        title: Text(student?.fullName ?? 'Student'),
        actions: <Widget>[
          if (!readOnly)
            IconButton(
              tooltip: 'Student report',
              onPressed: () => _generateReport(context, controller),
              icon: const Icon(Icons.picture_as_pdf_outlined),
            ),
          if (!readOnly)
            PopupMenuButton<String>(
            onSelected: (String value) {
              switch (value) {
                case 'edit':
                  if (student != null) {
                    Navigator.of(context).pushNamed(
                      Routes.studentForm,
                      arguments: StudentFormArgs(
                        classId: controller.classId,
                        existing: student,
                      ),
                    );
                  }
                case 'attendance':
                  Navigator.of(context).pushNamed(
                    Routes.attendanceHistory,
                    arguments: AttendanceHistoryArgs(
                      studentId: controller.studentId,
                      classId: controller.classId,
                    ),
                  );
                case 'delete':
                  _delete(context, controller);
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              const PopupMenuItem<String>(
                value: 'edit',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.edit_outlined),
                  title: Text('Edit student'),
                ),
              ),
              const PopupMenuItem<String>(
                value: 'attendance',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.history_rounded),
                  title: Text('Attendance history'),
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem<String>(
                value: 'delete',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    Icons.delete_outline_rounded,
                    color: context.semantic.danger,
                  ),
                  title: Text(
                    'Delete student',
                    style: TextStyle(color: context.semantic.danger),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ControllerStateView(
        controller: controller,
        loading: const SkeletonList(itemCount: 4),
        builder: (BuildContext context) {
          if (student == null || performance == null) {
            return const ErrorView(message: 'This student could not be loaded.');
          }
          return AppPageBody(
            onRefresh: controller.refresh,
            children: <Widget>[
              _ProfileHeader(
                student: student,
                performance: performance,
                className: controller.schoolClass?.name,
              ),
              const Gap.xl(),
              _InformationCard(
                student: student,
                classes: controller.enrolledClasses,
              ),
              const Gap.xl(),
              _AttendanceCard(summary: performance.attendance),
              const Gap.xl(),
              _AcademicCard(performance: performance),
              if (controller.gradedResults.isNotEmpty) ...<Widget>[
                const Gap.xl(),
                SectionCard(
                  title: 'Marks progression',
                  subtitle: 'Percentage scored in each graded assessment',
                  child: TrendChart(
                    points: <TrendPoint>[
                      for (final AssessmentResult result
                          in controller.gradedResults)
                        TrendPoint(
                          label: Format.truncate(result.assessment.name, 12),
                          value: result.percentage ?? 0,
                        ),
                    ],
                  ),
                ),
              ],
              const Gap.xl(),
              _AssessmentsCard(performance: performance),
              if (controller.attendanceLog.isNotEmpty) ...<Widget>[
                const Gap.xl(),
                _AttendanceLogCard(entries: controller.attendanceLog),
              ],
              const Gap.xxl(),
              if (!readOnly)
                FilledButton.icon(
                  onPressed: () => _generateReport(context, controller),
                  icon: const Icon(Icons.picture_as_pdf_rounded),
                  label: const Text('Generate PDF report'),
                ),
              const Gap.xxl(),
            ],
          );
        },
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({
    required this.student,
    required this.performance,
    this.className,
  });

  final Student student;
  final StudentPerformance performance;
  final String? className;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(name: student.fullName, seed: student.id, size: 60),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      student.fullName,
                      style: context.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      <String>[
                        if (student.rollNumber != null) student.rollNumber!,
                        if (className != null) className!,
                      ].join(' · '),
                      style: context.text.bodySmall
                          ?.copyWith(color: context.semantic.mutedText),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: AppSpacing.sm,
                      children: <Widget>[
                        GradeBadge(
                          grade: performance.grade?.label,
                          percent: performance.percentage,
                          dense: true,
                        ),
                        AttendanceBadge(
                          percent: performance.attendance.percentage,
                          dense: true,
                        ),
                        if (performance.isAtRisk)
                          const AppBadge(
                            'Needs attention',
                            tone: BadgeTone.warning,
                            icon: Icons.warning_amber_rounded,
                            dense: true,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _InformationCard extends StatelessWidget {
  const _InformationCard({required this.student, required this.classes});

  final Student student;
  final List<SchoolClass> classes;

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    context.showInfo('$label copied.');
  }

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Student information',
      child: Column(
        children: <Widget>[
          DetailRow(
            label: 'Roll / student number',
            value: student.rollNumber ?? '—',
            icon: Icons.tag_rounded,
          ),
          DetailRow(
            label: 'Student phone',
            value: student.studentPhone ?? '—',
            icon: Icons.smartphone_rounded,
            onTap: student.studentPhone == null
                ? null
                : () => _copy(context, student.studentPhone!, 'Student phone'),
          ),
          DetailRow(
            label: "Father's phone",
            value: student.fatherPhone ?? '—',
            icon: Icons.man_rounded,
            onTap: student.fatherPhone == null
                ? null
                : () => _copy(context, student.fatherPhone!, "Father's phone"),
          ),
          DetailRow(
            label: "Mother's phone",
            value: student.motherPhone ?? '—',
            icon: Icons.woman_rounded,
            onTap: student.motherPhone == null
                ? null
                : () => _copy(context, student.motherPhone!, "Mother's phone"),
          ),
          if (student.guardianName != null)
            DetailRow(
              label: 'Guardian',
              value: student.guardianName!,
              icon: Icons.family_restroom_rounded,
            ),
          if (student.email != null)
            DetailRow(
              label: 'Email',
              value: student.email!,
              icon: Icons.alternate_email_rounded,
            ),
          if (student.address != null)
            DetailRow(
              label: 'Address',
              value: student.address!,
              icon: Icons.home_outlined,
            ),
          if (!student.hasAnyContact) ...<Widget>[
            const Gap.sm(),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: context.semantic.warningContainer,
                borderRadius: BorderRadius.circular(AppRadii.sm),
              ),
              child: Row(
                children: <Widget>[
                  Icon(
                    Icons.info_outline_rounded,
                    size: 16,
                    color: context.semantic.warning,
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'No phone number on file — absence notifications cannot '
                      'be sent for this student.',
                      style: context.text.bodySmall?.copyWith(
                        color: context.semantic.onWarningContainer,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
          if (classes.isNotEmpty) ...<Widget>[
            const Gap.md(),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: AppSpacing.sm,
                runSpacing: AppSpacing.sm,
                children: <Widget>[
                  for (final SchoolClass schoolClass in classes)
                    AppBadge(
                      schoolClass.name,
                      tone: BadgeTone.brand,
                      icon: Icons.class_outlined,
                      dense: true,
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AttendanceCard extends StatelessWidget {
  const _AttendanceCard({required this.summary});

  final AttendanceSummary summary;

  @override
  Widget build(BuildContext context) {
    if (!summary.hasData) {
      return SectionCard(
        title: 'Attendance',
        child: Text(
          'No attendance has been recorded yet.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.semantic.mutedText),
        ),
      );
    }

    return SectionCard(
      title: 'Attendance',
      subtitle: '${summary.totalSessions} recorded '
          'session${summary.totalSessions == 1 ? '' : 's'}',
      child: Column(
        children: <Widget>[
          DonutChart(
            slices: <ChartSlice>[
              ChartSlice(
                label: 'Present',
                value: summary.present.toDouble(),
                color: context.semantic.success,
              ),
              ChartSlice(
                label: 'Absent',
                value: summary.absent.toDouble(),
                color: context.semantic.danger,
              ),
              if (summary.late > 0)
                ChartSlice(
                  label: 'Late',
                  value: summary.late.toDouble(),
                  color: context.semantic.warning,
                ),
              if (summary.shortLeave > 0)
                ChartSlice(
                  label: 'Short leave',
                  value: summary.shortLeave.toDouble(),
                  color: context.semantic.info,
                ),
            ],
            centerValue: Format.percentOrDash(summary.percentage, decimals: 0),
            centerLabel: 'attendance',
          ),
          const Gap.lg(),
          LabeledProgressBar(
            label: 'Attendance rate',
            value: (summary.percentage ?? 0) / 100,
            trailingLabel: Format.percentOrDash(summary.percentage),
            color: summary.percentageOrZero >= 75
                ? context.semantic.success
                : context.semantic.warning,
          ),
        ],
      ),
    );
  }
}

class _AcademicCard extends StatelessWidget {
  const _AcademicCard({required this.performance});

  final StudentPerformance performance;

  @override
  Widget build(BuildContext context) {
    return SectionCard(
      title: 'Academic performance',
      subtitle: performance.hasMarks
          ? '${performance.gradedCount} of ${performance.results.length} '
              'assessments graded'
          : 'No marks recorded yet',
      child: Column(
        children: <Widget>[
          StatGrid(
            columns: 3,
            tiles: <Widget>[
              StatTile(
                label: 'Marks obtained',
                value: performance.hasMarks
                    ? Format.marks(performance.obtainedTotal)
                    : '—',
                icon: Icons.functions_rounded,
              ),
              StatTile(
                label: 'Total marks',
                value: performance.hasMarks
                    ? Format.marks(performance.maxTotal)
                    : '—',
                icon: Icons.calculate_outlined,
              ),
              StatTile(
                label: 'Percentage',
                value: Format.percentOrDash(performance.percentage, decimals: 0),
                icon: Icons.percent_rounded,
                accent: context.semantic.info,
                caption: performance.grade?.label,
              ),
            ],
          ),
          if (performance.bestResult != null ||
              performance.weakestResult != null) ...<Widget>[
            const Gap.lg(),
            if (performance.bestResult != null)
              DetailRow(
                label: 'Strongest assessment',
                value: '${performance.bestResult!.assessment.name} · '
                    '${Format.percentOrDash(performance.bestResult!.percentage, decimals: 0)}',
                icon: Icons.trending_up_rounded,
                valueColor: context.semantic.success,
              ),
            if (performance.weakestResult != null)
              DetailRow(
                label: 'Needs work',
                value: '${performance.weakestResult!.assessment.name} · '
                    '${Format.percentOrDash(performance.weakestResult!.percentage, decimals: 0)}',
                icon: Icons.trending_down_rounded,
                valueColor: context.semantic.warning,
              ),
          ],
        ],
      ),
    );
  }
}

class _AssessmentsCard extends StatelessWidget {
  const _AssessmentsCard({required this.performance});

  final StudentPerformance performance;

  @override
  Widget build(BuildContext context) {
    if (performance.results.isEmpty) {
      return SectionCard(
        title: 'Assessments',
        child: Text(
          'No assessments have been created yet.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.semantic.mutedText),
        ),
      );
    }

    return SectionCard(
      title: 'Assessments',
      child: Column(
        children: <Widget>[
          for (final AssessmentResult result in performance.results.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          result.assessment.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall,
                        ),
                        Text(
                          '${result.assessment.typeLabel} · '
                          '${AppDate.formatShort(result.assessment.date)}',
                          style: context.text.labelSmall
                              ?.copyWith(color: context.semantic.mutedText),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: <Widget>[
                      Text(
                        result.wasAbsent
                            ? 'Absent'
                            : Format.fraction(
                                result.mark?.marksObtained,
                                result.total,
                              ),
                        style: context.text.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 3),
                      GradeBadge(
                        grade: result.grade?.label,
                        percent: result.percentage,
                        dense: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _AttendanceLogCard extends StatelessWidget {
  const _AttendanceLogCard({required this.entries});

  final List<StudentAttendanceEntry> entries;

  @override
  Widget build(BuildContext context) {
    final List<StudentAttendanceEntry> visible = entries.take(12).toList();

    return SectionCard(
      title: 'Recent attendance',
      subtitle: entries.length > visible.length
          ? 'Showing the last ${visible.length} of ${entries.length} sessions'
          : null,
      child: Column(
        children: <Widget>[
          for (final StudentAttendanceEntry entry in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      AppDate.format(entry.date),
                      style: context.text.bodyMedium,
                    ),
                  ),
                  Text(
                    entry.className,
                    style: context.text.labelSmall
                        ?.copyWith(color: context.semantic.mutedText),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  AttendanceStatusChip(entry.status, dense: true),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
