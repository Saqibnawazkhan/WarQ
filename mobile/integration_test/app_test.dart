import 'dart:io';

import 'package:edu_manager/app/app.dart';
import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/constants/app_constants.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:edu_manager/domain/entities/student_performance.dart';
import 'package:edu_manager/domain/services/messaging/whatsapp_messaging_provider.dart';
import 'package:edu_manager/domain/services/report_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// On-device end-to-end tests.
///
/// Unlike the unit and widget suites, these run against the **real** platform:
/// the actual `shared_preferences` store, the real filesystem via
/// `path_provider`, and real PDF generation. They are the proof that the app
/// works on hardware, not just in the Flutter test harness.
///
/// Run with:
///   `flutter test integration_test -d <device-id>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  /// Wipes on-device storage so the demo seeder produces a known dataset.
  Future<AppDependencies> freshApp() async {
    final SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.clear();
    return AppDependencies.bootstrap();
  }

  /// Pumps until [finder] matches, instead of `pumpAndSettle`, which can hang
  /// on a progress indicator that is legitimately still spinning.
  Future<void> pumpUntil(
    WidgetTester tester,
    Finder finder, {
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final DateTime deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      await tester.pump(const Duration(milliseconds: 120));
      // Some finders (`.last`, `.at`) throw rather than report empty, so a
      // miss must not abort the wait.
      try {
        if (finder.evaluate().isNotEmpty) return;
      } on StateError {
        // Not matched yet — keep waiting.
      }
    }
    throw TestFailure('Timed out waiting for: $finder');
  }

  /// Drags the page until [finder] is built. A long `ListView` only builds the
  /// widgets near the viewport, so off-screen content is genuinely absent from
  /// the tree until scrolled to.
  Future<void> scrollUntil(
    WidgetTester tester,
    Finder finder, {
    Finder? scrollable,
    int maxDrags = 25,
  }) async {
    final Finder target = scrollable ?? find.byType(ListView).first;
    for (int i = 0; i < maxDrags; i++) {
      if (finder.evaluate().isNotEmpty) return;
      await tester.drag(target, const Offset(0, -350));
      await tester.pump(const Duration(milliseconds: 150));
    }
    if (finder.evaluate().isEmpty) {
      throw TestFailure('Never found after scrolling: $finder');
    }
  }

  /// Brings [finder] into the hit-testable area of the open bottom sheet.
  Future<void> revealInSheet(WidgetTester tester, Finder finder) async {
    for (int i = 0; i < 12; i++) {
      final Iterable<Element> matches = finder.evaluate();
      if (matches.isNotEmpty) {
        final RenderBox box = matches.first.renderObject! as RenderBox;
        final Offset centre =
            box.localToGlobal(box.size.center(Offset.zero));
        final Size screen = tester.view.physicalSize / tester.view.devicePixelRatio;
        if (centre.dy >= 0 && centre.dy <= screen.height) return;
      }
      await tester.drag(
        find.byType(SingleChildScrollView).last,
        const Offset(0, -220),
      );
      await tester.pump(const Duration(milliseconds: 150));
    }
  }

  Future<void> signIn(
    WidgetTester tester, {
    required String email,
  }) async {
    await pumpUntil(tester, find.text('Email or username'));
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      email,
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      DemoAccounts.password,
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
  }

  group('cold start and storage', () {
    testWidgets('seeds demo data into real device storage on first launch',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();

      // The seeder ran against the real shared_preferences store.
      expect(deps.database.users.length, greaterThanOrEqualTo(3));
      expect(deps.database.classes.length, greaterThanOrEqualTo(3));
      expect(deps.database.students.length, greaterThanOrEqualTo(20));
      expect(deps.database.attendanceRecords.length, greaterThan(100));

      // And it survives a reload from disk, which proves it was persisted and
      // not just held in memory.
      final AppDependencies reopened = await AppDependencies.bootstrap();
      expect(reopened.database.classes.length, deps.database.classes.length);
      expect(reopened.database.students.length, deps.database.students.length);

      await deps.dispose();
      await reopened.dispose();
    });

    testWidgets('the app boots to the sign-in screen',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      await tester.pumpWidget(EduManagerApp(dependencies: deps));

      await pumpUntil(tester, find.text('Email or username'));
      expect(find.text('Demo accounts'), findsOneWidget);

      await deps.dispose();
    });
  });

  group('teacher journey', () {
    testWidgets('signs in and lands on a populated dashboard',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      await tester.pumpWidget(EduManagerApp(dependencies: deps));

      await signIn(tester, email: DemoAccounts.teacherEmail);
      await pumpUntil(tester, find.text('Total classes'));

      expect(find.text('Ahmed Raza'), findsWidgets);
      expect(find.text('Total students'), findsOneWidget);
      expect(find.text('Present today'), findsOneWidget);
      expect(find.text('Absent today'), findsOneWidget);
      expect(find.text('Quick actions'), findsOneWidget);
      expect(find.byType(NavigationBar), findsOneWidget);

      await deps.dispose();
    });

    testWidgets('opens a class and shows the A-Z roster',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      await tester.pumpWidget(EduManagerApp(dependencies: deps));

      await signIn(tester, email: DemoAccounts.teacherEmail);
      await pumpUntil(tester, find.text('Total classes'));

      // Classes tab.
      await tester.tap(find.byIcon(Icons.class_outlined).first);
      await pumpUntil(tester, find.text('Software Engineering'));

      await tester.tap(find.text('Software Engineering').first);
      await pumpUntil(tester, find.textContaining('Students ('));

      // The seeded roster starts with Ahmed Bilal and is ordered A-Z.
      expect(find.text('Ahmed Bilal'), findsWidgets);
      expect(find.textContaining('Attendance ('), findsOneWidget);
      expect(find.textContaining('Marks ('), findsOneWidget);

      await deps.dispose();
    });

    testWidgets('marks attendance for today and persists it',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      final SchoolClass target = deps.database.classes.all.firstWhere(
        (SchoolClass c) => c.name == 'Software Engineering',
      );
      expect(
        await deps.attendance.sessionOn(classId: target.id, date: DateTime.now()),
        isNull,
        reason: 'the seeder deliberately leaves today unmarked',
      );

      await tester.pumpWidget(EduManagerApp(dependencies: deps));
      await signIn(tester, email: DemoAccounts.teacherEmail);
      await pumpUntil(tester, find.text('Total classes'));

      // Attendance tab -> the Software Engineering card -> all present -> save.
      // Tapping the named card rather than the first "Mark today's attendance"
      // button keeps the test pinned to the class it asserts on; the hub lists
      // pending classes most-recently-updated first.
      await tester.tap(find.byIcon(Icons.how_to_reg_outlined).first);
      await pumpUntil(tester, find.text('Pending today'));

      await tester.tap(find.text('Software Engineering').first);
      await pumpUntil(tester, find.text('All present'));

      await tester.tap(find.text('All present'));
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Save attendance'));
      // Back on the hub, the class has moved from "Pending today" into the
      // "Marked today" section.
      await pumpUntil(tester, find.text('Marked today'));

      // Verify it reached the real store, not just the widget tree.
      final AttendanceSession? saved = await deps.attendance.sessionOn(
        classId: target.id,
        date: DateTime.now(),
      );
      expect(saved, isNotNull);
      final List<AttendanceRecord> records =
          await deps.attendance.recordsForSession(saved!.id);
      expect(records, isNotEmpty);
      expect(
        records.every((AttendanceRecord r) => r.status == AttendanceStatus.present),
        isTrue,
      );

      await deps.dispose();
    });

    testWidgets('opens a student performance screen',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      await tester.pumpWidget(EduManagerApp(dependencies: deps));

      await signIn(tester, email: DemoAccounts.teacherEmail);
      await pumpUntil(tester, find.text('Total classes'));

      await tester.tap(find.byIcon(Icons.class_outlined).first);
      await pumpUntil(tester, find.text('Software Engineering'));
      await tester.tap(find.text('Software Engineering').first);
      await pumpUntil(tester, find.text('Ahmed Bilal'));

      await tester.tap(find.text('Ahmed Bilal').first);
      await pumpUntil(tester, find.text('Student information'));

      expect(find.text('Attendance'), findsWidgets);
      expect(find.text('Academic performance'), findsOneWidget);

      // The report button sits below the fold, so it is not built until the
      // list is scrolled to it.
      await scrollUntil(tester, find.text('Generate PDF report'));
      expect(find.text('Generate PDF report'), findsWidgets);

      await deps.dispose();
    });
  });

  group('absence notifications', () {
    testWidgets('marking a student absent prepares WhatsApp notices',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      final SchoolClass target = deps.database.classes.all.firstWhere(
        (SchoolClass c) => c.name == 'Software Engineering',
      );

      await tester.pumpWidget(EduManagerApp(dependencies: deps));
      await signIn(tester, email: DemoAccounts.teacherEmail);
      await pumpUntil(tester, find.text('Total classes'));

      await tester.tap(find.byIcon(Icons.how_to_reg_outlined).first);
      await pumpUntil(tester, find.text('Pending today'));
      await tester.tap(find.text('Software Engineering').first);
      await pumpUntil(tester, find.text('All present'));

      // Everyone present, then flip the first student to absent via the "A"
      // status button on their row.
      await tester.tap(find.text('All present'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('A').first);
      await tester.pump(const Duration(milliseconds: 300));

      await tester.tap(find.text('Save attendance'));

      // The dispatch sheet is the hand-off step: one row per guardian number.
      await pumpUntil(tester, find.text('Notify parents'));
      expect(find.text('Send'), findsWidgets);

      await revealInSheet(tester, find.text('Finish later'));
      await tester.tap(find.text('Finish later'));
      await pumpUntil(tester, find.text('Marked today'));

      // Notices are recorded and waiting, not silently dropped.
      final List<OutboundMessage> outbox = await deps.notifications.outbox();
      expect(outbox, isNotEmpty);
      // One absent student yields at most one notice per number on file
      // (student, father, mother).
      expect(outbox.length, inInclusiveRange(1, 3));
      expect(
        outbox.map((OutboundMessage m) => m.studentId).toSet(),
        hasLength(1),
      );
      expect(
        outbox.every((OutboundMessage m) => m.status == MessageStatus.queued),
        isTrue,
        reason: 'WhatsApp needs a tap, so nothing is sent automatically',
      );
      expect(
        outbox.every((OutboundMessage m) => m.classId == target.id),
        isTrue,
      );

      // Every queued notice resolves to a usable wa.me link.
      const WhatsAppMessagingProvider provider = WhatsAppMessagingProvider();
      for (final OutboundMessage message in outbox) {
        final Uri? link = provider.linkFor(
          phone: message.recipientPhone,
          body: message.body,
        );
        expect(link, isNotNull, reason: message.recipientPhone);
        expect(link!.host, 'wa.me');
        expect(link.queryParameters['text'], contains('marked absent'));
      }

      await deps.dispose();
    });
  });

  group('organization admin journey', () {
    testWidgets('signs in and sees organization-scoped data',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      await tester.pumpWidget(EduManagerApp(dependencies: deps));

      await signIn(tester, email: DemoAccounts.orgAdminEmail);
      await pumpUntil(tester, find.text('Bright Future Academy'));

      expect(find.text('Teachers'), findsWidgets);
      expect(find.text('Students'), findsWidgets);
      expect(find.text('Invite teacher'), findsWidgets);

      await deps.dispose();
    });
  });

  group('PDF generation on device', () {
    testWidgets('writes a student report to real device storage',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      final AppUser teacher = deps.database.users.all.firstWhere(
        (AppUser u) => u.email == DemoAccounts.teacherEmail,
      );
      final SchoolClass target = deps.database.classes.all.firstWhere(
        (SchoolClass c) => c.name == 'Software Engineering',
      );
      final ClassPerformance performance =
          await deps.analytics.classPerformance(target.id);
      final Student student = performance.students.first.student;

      final GeneratedReport report = await deps.reports.studentReport(
        studentId: student.id,
        teacher: teacher,
        classId: target.id,
      );

      expect(report.bytes.sublist(0, 4), <int>[0x25, 0x50, 0x44, 0x46]);

      // path_provider + real filesystem write.
      final String path = await deps.reports.saveToDevice(report);
      final File file = File(path);
      expect(file.existsSync(), isTrue);
      expect(await file.length(), report.bytes.length);
      expect(path, endsWith('.pdf'));

      await deps.dispose();
    });

    testWidgets('writes a class report to real device storage',
        (WidgetTester tester) async {
      final AppDependencies deps = await freshApp();
      final AppUser teacher = deps.database.users.all.firstWhere(
        (AppUser u) => u.email == DemoAccounts.teacherEmail,
      );
      final SchoolClass target = deps.database.classes.all.firstWhere(
        (SchoolClass c) => c.name == 'Software Engineering',
      );

      final GeneratedReport report = await deps.reports.classReport(
        classId: target.id,
        teacher: teacher,
      );

      expect(report.bytes.sublist(0, 4), <int>[0x25, 0x50, 0x44, 0x46]);
      expect(report.isLandscape, isTrue);

      final String path = await deps.reports.saveToDevice(report);
      expect(File(path).existsSync(), isTrue);

      await deps.dispose();
    });
  });
}
