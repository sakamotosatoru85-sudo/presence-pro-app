import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:app/main.dart'; // ← Make sure this matches your folder

void main() {
  testWidgets('App starts with LoginScreen', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceProApp());

    // Verify LoginScreen is shown
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('Attendance Pro'), findsOneWidget);
    expect(find.text('Login as Lecturer'), findsOneWidget);
    expect(find.text('Login as Student'), findsOneWidget);
  });

  testWidgets('Lecturer login flow', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceProApp());

    // Enter credentials
    await tester.enterText(find.byType(TextField).first, 'demo@lecturer.com');
    await tester.enterText(find.byType(TextField).last, '123');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login as Lecturer'));
    await tester.pumpAndSettle();

    // Should be in LecturerScreen
    expect(find.text('Share Code'), findsOneWidget);
    expect(find.text('Export CSV'), findsOneWidget);
  });

  testWidgets('Student login flow', (WidgetTester tester) async {
    await tester.pumpWidget(const AttendanceProApp());

    // Enter student ID
    await tester.enterText(find.byType(TextField).first, 'S1001');
    await tester.tap(find.widgetWithText(ElevatedButton, 'Login as Student'));
    await tester.pumpAndSettle();

    // Should be in StudentScreen
    expect(find.text('Enter attendance code'), findsOneWidget);
    expect(find.byType(TextField), findsNWidgets(2)); // ID + Code
  });
}