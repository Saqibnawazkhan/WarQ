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
        // The name is the profile card's headline now, so repeating it here
        // would only push the same words twice down the top of the screen.
        title: const Text('Student performance'),
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
              _ProfileCard(
                student: student,
                performance: performance,
                schoolClass: controller.schoolClass,
                classes: controller.enrolledClasses,
              ),
              const Gap.xl(),
              _ContactsCard(student: student),
              const Gap.xl(),
              _AttendanceCard(summary: performance.attendance),
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

/// Track and fill on its own.
///
/// `LabeledProgressBar` brings its own caption typography; here the label and
/// the figure belong to the card's own heading row and to the assessment row,
/// so only the bar itself is wanted.
class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.color});

  static const double _height = AppSpacing.sm;

  /// 0–1.
  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(_height),
      child: LinearProgressIndicator(
        value: value.isNaN ? 0 : value.clamp(0, 1),
        minHeight: _height,
        backgroundColor: context.semantic.subtleBorder,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }
}

/// Ceiling for the grade pill at the end of the profile row.
///
/// A grade scale is teacher-configurable and its band label is free text, so a
/// long one would otherwise size the pill off the card — the pill is laid out
/// before the name and takes whatever width it asks for. Bounding it makes the
/// label ellipsize inside the pill instead. `StudentTileStats` bounds the
/// roster row for the same reason.
const double _gradeBadgeMaxWidth = 112;

/// Resolves a score to a colour through the badge rule, so a bar, its figure
/// and the grade pill beside them can never disagree.
Color _scoreColor(BuildContext context, double? percent) {
  return switch (GradeBadge.toneForPercent(percent)) {
    BadgeTone.success => context.semantic.success,
    BadgeTone.brand => context.colors.primary,
    BadgeTone.warning => context.semantic.warning,
    BadgeTone.danger => context.semantic.danger,
    BadgeTone.info => context.semantic.info,
    BadgeTone.neutral => context.semantic.mutedText,
  };
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({
    required this.student,
    required this.performance,
    required this.classes,
    this.schoolClass,
  });

  final Student student;
  final StudentPerformance performance;
  final List<SchoolClass> classes;

  /// Only set when the profile is scoped to one class.
  final SchoolClass? schoolClass;

  @override
  Widget build(BuildContext context) {
    final SchoolClass? scoped = schoolClass;
    final String? subject = scoped?.subject;
    final String? session = scoped?.session;
    final List<String> identity = <String>[
      if (student.rollNumber != null) student.rollNumber!,
      if (scoped != null) scoped.name,
      // A class often carries its subject as its name; printing both would
      // read as a stutter.
      if (subject != null && subject != scoped?.name) subject,
      if (session != null) session,
    ];

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              AppAvatar(name: student.fullName, seed: student.id, size: 56),
              const SizedBox(width: AppSpacing.lg),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      student.fullName,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleLarge
                          ?.copyWith(fontWeight: FontWeight.w700),
                    ),
                    if (identity.isNotEmpty) ...<Widget>[
                      const Gap.xs(),
                      Text(
                        identity.join(' · '),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: context.text.bodySmall
                            ?.copyWith(color: context.semantic.mutedText),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              ConstrainedBox(
                constraints:
                    const BoxConstraints(maxWidth: _gradeBadgeMaxWidth),
                child: GradeBadge(
                  grade: performance.grade?.label,
                  percent: performance.percentage,
                ),
              ),
            ],
          ),
          if (performance.isAtRisk) ...<Widget>[
            const Gap.lg(),
            const AppBadge(
              'Needs attention',
              tone: BadgeTone.warning,
              icon: Icons.warning_amber_rounded,
              dense: true,
            ),
          ],
          if (classes.isNotEmpty) ...<Widget>[
            const Gap.lg(),
            Wrap(
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
          ],
        ],
      ),
    );
  }
}

class _ContactsCard extends StatelessWidget {
  const _ContactsCard({required this.student});

  final Student student;

  void _copy(BuildContext context, String value, String label) {
    Clipboard.setData(ClipboardData(text: value));
    context.showInfo('$label copied.');
  }

  @override
  Widget build(BuildContext context) {
    final List<({RecipientRelation relation, String phone})> numbers =
        student.contactNumbers;

    return SectionCard(
      title: 'Contacts',
      subtitle: 'Absence alerts go to these numbers',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final ({RecipientRelation relation, String phone}) contact
              in numbers)
            DetailRow(
              label: contact.relation.label,
              value: contact.phone,
              // The row label alone ("Father") does not survive being dropped
              // into the confirmation sentence.
              onTap: () => _copy(
                context,
                contact.phone,
                "${contact.relation.label}'s number",
              ),
            ),
          if (numbers.isEmpty)
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
          if (student.guardianName != null)
            DetailRow(label: 'Guardian', value: student.guardianName!),
          if (student.email != null)
            DetailRow(label: 'Email', value: student.email!),
          if (student.address != null)
            DetailRow(label: 'Address', value: student.address!),
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
    final Color tone = summary.percentageOrZero >= 75
        ? context.semantic.success
        : context.semantic.warning;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: <Widget>[
              Expanded(
                child: Text(
                  'Attendance',
                  style: context.text.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Text(
                Format.percentOrDash(summary.percentage, decimals: 0),
                style: context.text.titleLarge?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: summary.hasData ? tone : context.semantic.mutedText,
                ),
              ),
            ],
          ),
          if (!summary.hasData) ...<Widget>[
            const Gap.md(),
            Text(
              'No attendance has been recorded yet.',
              style: context.text.bodyMedium
                  ?.copyWith(color: context.semantic.mutedText),
            ),
          ] else ...<Widget>[
            const Gap.lg(),
            _Bar(value: (summary.percentage ?? 0) / 100, color: tone),
            const Gap.md(),
            Text(
              <String>[
                '${summary.present} present',
                '${summary.absent} absent',
                '${summary.late} late',
                '${summary.shortLeave} short leave',
                Format.plural(summary.totalSessions, 'session'),
              ].join('  ·  '),
              style: context.text.bodySmall
                  ?.copyWith(color: context.semantic.mutedText),
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
        title: 'Assessment performance',
        child: Text(
          'No assessments have been created yet.',
          style: context.text.bodyMedium
              ?.copyWith(color: context.semantic.mutedText),
        ),
      );
    }

    final String overall = performance.hasMarks
        ? <String>[
            Format.fraction(performance.obtainedTotal, performance.maxTotal),
            Format.percentOrDash(performance.percentage, decimals: 0),
            if (performance.grade != null) 'Grade ${performance.grade!.label}',
          ].join(' · ')
        : 'Not graded yet';

    return SectionCard(
      title: 'Assessment performance',
      subtitle: performance.hasMarks
          ? '${performance.gradedCount} of ${performance.results.length} '
              'assessments graded'
          : 'No marks recorded yet',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          for (final AssessmentResult result in performance.results.reversed)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.lg),
              child: Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: Text(
                      result.assessment.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.titleSmall,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    flex: 4,
                    child: _Bar(
                      value: (result.percentage ?? 0) / 100,
                      color: _scoreColor(context, result.percentage),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  // Left free to take its natural width: the two bars beside it
                  // give way instead, so a wide total can never truncate into a
                  // figure that reads as the wrong mark.
                  Text(
                    result.wasAbsent
                        ? 'Absent'
                        : Format.fraction(
                            result.mark?.marksObtained,
                            result.total,
                          ),
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color:
                          result.wasAbsent ? context.semantic.danger : null,
                    ),
                  ),
                ],
              ),
            ),
          Divider(height: AppSpacing.lg, color: context.semantic.subtleBorder),
          Padding(
            padding: const EdgeInsets.only(top: AppSpacing.lg),
            child: Row(
              children: <Widget>[
                Text(
                  'Overall',
                  style: context.text.titleSmall
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Text(
                    overall,
                    textAlign: TextAlign.end,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: performance.hasMarks
                          ? _scoreColor(context, performance.percentage)
                          : context.semantic.mutedText,
                    ),
                  ),
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
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: <Widget>[
                    Container(
                      width: AppSpacing.xs,
                      decoration: BoxDecoration(
                        color: AttendanceStatusChip.colorFor(
                          context,
                          entry.status,
                        ),
                        borderRadius: BorderRadius.circular(AppRadii.pill),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: <Widget>[
                          Text(
                            AppDate.format(entry.date),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium
                                ?.copyWith(fontWeight: FontWeight.w600),
                          ),
                          Text(
                            entry.className,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.labelMedium
                                ?.copyWith(color: context.semantic.mutedText),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppSpacing.md),
                    // Stretch would otherwise pull the pill to the full row
                    // height and turn it into a block.
                    Center(
                      child: AttendanceStatusChip(entry.status, dense: true),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
