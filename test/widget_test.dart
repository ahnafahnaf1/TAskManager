import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_scheduler/models/schedule_task.dart';
import 'package:task_scheduler/services/notification_service.dart';
import 'package:task_scheduler/widgets/task_tile.dart';

void main() {
  testWidgets('TaskTile renders title, status, alerts, and edit action', (WidgetTester tester) async {
    final task = ScheduleTask(
      id: 7,
      title: 'Database Migration',
      scheduledTime: DateTime.now().add(const Duration(hours: 3)),
      status: 'pending',
    );

    bool completedTriggered = false;
    bool cancelledTriggered = false;
    bool editTriggered = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TaskTile(
            task: task,
            onComplete: () => completedTriggered = true,
            onCancel: () => cancelledTriggered = true,
            onEdit: () => editTriggered = true,
          ),
        ),
      ),
    );

    expect(find.text('Database Migration'), findsOneWidget);
    expect(find.text('PENDING'), findsOneWidget);
    expect(find.textContaining('Next Alert'), findsOneWidget);

    // Tap edit button
    await tester.tap(find.byIcon(Icons.edit_note_rounded));
    expect(editTriggered, isTrue);

    // Tap complete button
    await tester.tap(find.byIcon(Icons.check_circle_outline_rounded));
    expect(completedTriggered, isTrue);

    // Tap cancel button
    await tester.tap(find.byIcon(Icons.highlight_off_rounded));
    expect(cancelledTriggered, isTrue);
  });

  testWidgets('TaskTile cleanly renders 1-minute interval next alert without debug clutter', (WidgetTester tester) async {
    // Set 1-minute interval
    await NotificationService.instance.updateAlertTiming(intervalMinutes: 1, windowMinutes: 60);

    final task = ScheduleTask(
      id: 99,
      title: 'Quick 1m Interval Task',
      scheduledTime: DateTime.now().add(const Duration(hours: 2)),
      status: 'pending',
    );

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: TaskTile(
              task: task,
              onComplete: () {},
              onCancel: () {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('Quick 1m Interval Task'), findsOneWidget);
    expect(find.textContaining('Next Alert'), findsOneWidget);
    expect(find.textContaining('every 1m'), findsWidgets);

    // Verify debug scheduled alert times list is removed from user view
    expect(find.textContaining('Scheduled Alert Times'), findsNothing);

    // Reset back to 15m default
    await NotificationService.instance.updateAlertTiming(intervalMinutes: 15, windowMinutes: 60);
  });
}
