import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:task_scheduler/widgets/confirmation_dialog.dart';

void main() {
  testWidgets('ConfirmationDialog shows title, message, and returns false when cancelled', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.confirmDelete(
                    context,
                    taskTitle: 'Urgent Client Review',
                  );
                },
                child: const Text('Show Dialog'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to open dialog
    await tester.tap(find.text('Show Dialog'));
    await tester.pumpAndSettle();

    // Verify dialog contents
    expect(find.text('Delete Task Permanently?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to permanently delete "Urgent Client Review"? This action cannot be undone.'),
      findsOneWidget,
    );
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.text('Delete Permanently'), findsOneWidget);

    // Tap Cancel
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify dialog is dismissed and result is false
    expect(find.text('Delete Task Permanently?'), findsNothing);
    expect(result, isFalse);
  });

  testWidgets('ConfirmationDialog returns true when confirmed', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.confirmComplete(
                    context,
                    taskTitle: 'Prepare Quarterly Report',
                  );
                },
                child: const Text('Complete Task'),
              );
            },
          ),
        ),
      ),
    );

    // Tap button to open dialog
    await tester.tap(find.text('Complete Task'));
    await tester.pumpAndSettle();

    // Verify dialog contents
    expect(find.text('Complete Task?'), findsOneWidget);
    expect(
      find.text('Are you sure you want to mark "Prepare Quarterly Report" as completed? This will silence all upcoming pre-deadline alarms.'),
      findsOneWidget,
    );
    expect(find.text('Mark Completed'), findsOneWidget);

    // Tap Confirm
    await tester.tap(find.text('Mark Completed'));
    await tester.pumpAndSettle();

    // Verify dialog is dismissed and result is true
    expect(find.text('Complete Task?'), findsNothing);
    expect(result, isTrue);
  });

  testWidgets('ConfirmationDialog discard dialog works properly', (WidgetTester tester) async {
    bool? result;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: Builder(
            builder: (context) {
              return ElevatedButton(
                onPressed: () async {
                  result = await ConfirmationDialog.confirmDiscard(context);
                },
                child: const Text('Discard'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('Discard'));
    await tester.pumpAndSettle();

    expect(find.text('Discard Changes?'), findsOneWidget);
    expect(find.text('Keep Editing'), findsOneWidget);
    expect(find.text('Discard'), findsWidgets); // button in dialog and original button

    // Tap "Keep Editing"
    await tester.tap(find.text('Keep Editing'));
    await tester.pumpAndSettle();

    expect(find.text('Discard Changes?'), findsNothing);
    expect(result, isFalse);
  });
}
