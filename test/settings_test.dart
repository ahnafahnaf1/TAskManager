import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_scheduler/screens/settings_screen.dart';
import 'package:task_scheduler/widgets/permission_dialog.dart';

void main() {
  testWidgets('SettingsScreen renders main settings tiles and opens modals', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Verify main screen cards are present without endless scrolling
    expect(find.text('Settings & Alarm Debugger'), findsOneWidget);
    expect(find.text('Pre-Deadline Alert Intervals'), findsOneWidget);
    expect(find.text('Alarm Ringtone & Sound'), findsOneWidget);
    expect(find.text('System Permissions'), findsOneWidget);
    expect(find.text('Alarm Testing Station'), findsOneWidget);
    expect(find.text('Background & Battery Optimization'), findsOneWidget);
    expect(find.text('About Task Scheduler'), findsOneWidget);

    // Tap Pre-Deadline Alert Intervals to open its popup modal
    await tester.tap(find.text('Pre-Deadline Alert Intervals'));
    await tester.pumpAndSettle();

    expect(find.text('Alert Frequency (Interval Minutes)'), findsOneWidget);
    expect(find.text('15 min (Default)'), findsOneWidget);
    expect(find.text('Save Interval Timing'), findsOneWidget);

    // Close modal
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Tap Alarm Testing Station to open testing modal
    await tester.ensureVisible(find.text('Alarm Testing Station'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Alarm Testing Station'));
    await tester.pumpAndSettle();

    expect(find.text('Alarm Testing & Debug Station'), findsOneWidget);
    expect(find.text('1 min (Recommended)'), findsOneWidget);
    expect(find.textContaining('Ring Test Alarm Right Now'), findsOneWidget);
    expect(find.textContaining('Start Alarm Test'), findsOneWidget);

    // Close modal
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();
  });

  testWidgets('Selecting an alarm ringtone in modal updates the active badge', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: SettingsScreen(),
      ),
    );

    await tester.pumpAndSettle();

    // Tap Alarm Ringtone & Sound to open the modal
    await tester.tap(find.text('Alarm Ringtone & Sound'));
    await tester.pumpAndSettle();

    expect(find.text('Digital Bedside Clock'), findsWidgets);
    expect(find.text('Emergency Siren Alarm'), findsOneWidget);
    expect(find.text('Classic Twin Bell'), findsOneWidget);
    expect(find.text('Custom Sound from Phone'), findsOneWidget);
    expect(find.text('Choose'), findsOneWidget);
    expect(find.text('ACTIVE'), findsWidgets);

    // Tap Emergency Siren in the modal
    await tester.tap(find.text('Emergency Siren Alarm'));
    await tester.pumpAndSettle();

    // Emergency Siren is now selected with active badge
    expect(find.text('ACTIVE'), findsWidgets);
    expect(find.textContaining('Emergency Siren'), findsWidgets);

    // Close modal
    await tester.tap(find.byTooltip('Close'));
    await tester.pumpAndSettle();

    // Verify main card subtitle reflects the new sound
    expect(find.textContaining('Emergency Siren Alarm'), findsWidgets);
  });

  testWidgets('PermissionDialog renders both required permissions', (WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: PermissionDialog(onPermissionsUpdated: () {}),
        ),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Permissions Required'), findsOneWidget);
    expect(find.text('Notification Alerts'), findsOneWidget);
    expect(find.textContaining('Exact Alarms'), findsOneWidget);
    expect(find.textContaining('Background'), findsOneWidget);
    expect(find.byType(ElevatedButton), findsOneWidget);
  });
}
