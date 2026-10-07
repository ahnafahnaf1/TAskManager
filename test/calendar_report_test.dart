import 'package:flutter_test/flutter_test.dart';
import 'package:task_scheduler/models/schedule_task.dart';
import 'package:task_scheduler/screens/calendar_screen.dart';
import 'package:task_scheduler/screens/report_screen.dart';

void main() {
  group('CalendarScreen Meeting Filter Logic', () {
    test('isMeetingTask detects various meeting keywords', () {
      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: 'Sprint Planning Meeting',
          scheduledTime: DateTime.now(),
        )),
        isTrue,
      );

      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: 'Client Zoom Call',
          scheduledTime: DateTime.now(),
        )),
        isTrue,
      );

      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: 'Candidate Interview',
          scheduledTime: DateTime.now(),
        )),
        isTrue,
      );

      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: 'Daily Standup',
          scheduledTime: DateTime.now(),
        )),
        isTrue,
      );

      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: '1:1 Sync with Manager',
          scheduledTime: DateTime.now(),
        )),
        isTrue,
      );

      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: 'Doctor Appointment',
          scheduledTime: DateTime.now(),
        )),
        isTrue,
      );

      // Non-meeting tasks
      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: 'Buy Groceries',
          scheduledTime: DateTime.now(),
        )),
        isFalse,
      );

      expect(
        CalendarScreen.isMeetingTask(ScheduleTask(
          title: 'Write Unit Tests',
          scheduledTime: DateTime.now(),
        )),
        isFalse,
      );
    });
  });

  group('ReportFilter Enum & Labels', () {
    test('All ReportFilter enum values have distinct labels and icons', () {
      expect(ReportFilter.values.length, 6);
      expect(ReportFilter.all.label, 'All Time');
      expect(ReportFilter.day.label, 'Day (Today)');
      expect(ReportFilter.week.label, 'This Week');
      expect(ReportFilter.month.label, 'This Month');
      expect(ReportFilter.year.label, 'This Year');
      expect(ReportFilter.custom.label, 'Custom Range');
    });
  });
}
