import 'package:edu_manager/app/app.dart';
import 'package:edu_manager/app/app_dependencies.dart';
import 'package:edu_manager/core/constants/app_constants.dart';
import 'package:edu_manager/data/models/models.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'helpers/test_harness.dart';

/// End-to-end widget coverage of the sign-in flow and role-based routing.
void main() {
  late AppDependencies deps;

  setUp(() async {
    deps = await createTestDependencies();
  });

  tearDown(() async => deps.dispose());

  /// Pumps the app and lets the session bootstrap settle.
  Future<void> pumpApp(WidgetTester tester) async {
    await tester.pumpWidget(EduManagerApp(dependencies: deps));
    await tester.pumpAndSettle();
  }

  testWidgets('shows the sign-in screen when nobody is authenticated',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Sign in'), findsWidgets);
    expect(find.text('Email or username'), findsOneWidget);
    expect(find.text('Password'), findsOneWidget);
    expect(find.text('Create an account'), findsOneWidget);
  });

  testWidgets('validates empty credentials instead of submitting',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Email or username is required.'), findsOneWidget);
    expect(find.text('Password is required.'), findsOneWidget);
  });

  testWidgets('rejects an unknown account with a friendly message',
      (WidgetTester tester) async {
    await pumpApp(tester);

    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'nobody@example.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(
      find.text('Incorrect email or password. Please try again.'),
      findsOneWidget,
    );
  });

  testWidgets('a teacher lands on the teacher dashboard',
      (WidgetTester tester) async {
    final AppUser teacher = await registerTestTeacher(
      deps,
      fullName: 'Ahmed Raza',
      email: 'ahmed@test.com',
    );
    // Registration signs the user in; sign back out so the login flow is used.
    await deps.auth.signOut(teacher);

    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'ahmed@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Ahmed Raza'), findsWidgets);
    expect(find.text('Total classes'), findsOneWidget);
    expect(find.text('Quick actions'), findsOneWidget);
    // The five-destination bottom navigation from the spec.
    expect(find.byType(NavigationBar), findsOneWidget);
    expect(find.text('Attendance'), findsWidgets);
    // Labelled "Marks": "Assessments" wraps onto two lines in a fifth of a
    // phone screen at the current text size and breaks the bar's alignment.
    expect(find.text('Marks'), findsWidgets);
  });

  testWidgets('an organization admin lands on the organization dashboard',
      (WidgetTester tester) async {
    final AppUser admin = await deps.auth.registerOrganization(
      fullName: 'Fatima Khan',
      email: 'admin@test.com',
      password: 'password123',
      organizationName: 'Bright Future Academy',
    );
    await deps.auth.signOut(admin);

    await pumpApp(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Email or username'),
      'admin@test.com',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Password'),
      'password123',
    );
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in'));
    await tester.pumpAndSettle();

    expect(find.text('Bright Future Academy'), findsWidgets);
    expect(find.text('Teachers'), findsWidgets);
    expect(find.text('Invite teacher'), findsWidgets);
  });

  testWidgets('restores an existing session without showing sign-in',
      (WidgetTester tester) async {
    await registerTestTeacher(deps, fullName: 'Ahmed Raza');

    await pumpApp(tester);

    expect(find.text('Email or username'), findsNothing);
    expect(find.text('Total classes'), findsOneWidget);
  });

  testWidgets('an empty account is guided towards creating a class',
      (WidgetTester tester) async {
    await registerTestTeacher(deps);

    await pumpApp(tester);

    expect(find.text('No classes yet'), findsOneWidget);
    expect(find.text('Create a class'), findsWidgets);
  });

  testWidgets('demo credentials are offered on the sign-in screen',
      (WidgetTester tester) async {
    await pumpApp(tester);

    expect(find.text('Demo accounts'), findsOneWidget);
    expect(
      find.text('Password for all demo accounts: ${DemoAccounts.password}'),
      findsOneWidget,
    );
  });
}
