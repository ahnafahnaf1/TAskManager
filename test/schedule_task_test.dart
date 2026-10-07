import 'package:flutter_test/flutter_test.dart';
import 'package:task_scheduler/models/schedule_task.dart';
import 'package:task_scheduler/services/notification_service.dart';

void main() {
  group('ScheduleTask Model Tests', () {
    test('Task serialization toMap and fromMap roundtrip', () {
      final scheduledDate = DateTime(2026, 10, 5, 18, 30);
      final task = ScheduleTask(
        id: 42,
        title: 'Production Deployment',
        scheduledTime: scheduledDate,
        status: 'pending',
      );

      final map = task.toMap();
      expect(map['id'], 42);
      expect(map['title'], 'Production Deployment');
      expect(map['scheduledTime'], scheduledDate.toIso8601String());
      expect(map['status'], 'pending');

      final reconstructed = ScheduleTask.fromMap(map);
      expect(reconstructed.id, 42);
      expect(reconstructed.title, 'Production Deployment');
      expect(reconstructed.scheduledTime, scheduledDate);
      expect(reconstructed.status, 'pending');
      expect(reconstructed.isPending, isTrue);
      expect(reconstructed.isCompleted, isFalse);
      expect(reconstructed.isCancelled, isFalse);
    });

    test('copyWith updates specified fields correctly', () {
      final task = ScheduleTask(
        id: 1,
        title: 'Original Title',
        scheduledTime: DateTime(2026, 10, 5, 10, 0),
        status: 'pending',
      );

      final completedTask = task.copyWith(status: 'completed');
      expect(completedTask.id, 1);
      expect(completedTask.title, 'Original Title');
      expect(completedTask.isCompleted, isTrue);
      expect(completedTask.isPending, isFalse);

      final renamedTask = task.copyWith(title: 'Updated Title');
      expect(renamedTask.title, 'Updated Title');
      expect(renamedTask.status, 'pending');
    });

    test('Deterministic Notification IDs formula: (taskId * 1000) + index', () {
      const taskId = 15;
      final expectedIds = [15000, 15001, 15002, 15003];

      for (int i = 0; i < 4; i++) {
        final derivedId = NotificationService.getNotificationId(taskId, i);
        expect(derivedId, equals(expectedIds[i]));
      }
    });

    test('Exact legacy pre-deadline intervals are 60, 45, 30, and 15 minutes', () {
      expect(
        NotificationService.reminderOffsetsInMinutes,
        equals([60, 45, 30, 15]),
      );
    });

    test('Dynamic calculateOffsets generates correct pre-deadline intervals', () {
      final now = DateTime(2026, 10, 5, 10, 0);
      final dueTime = DateTime(2026, 10, 5, 10, 45); // 45 minutes ahead

      final offsets = NotificationService.instance.calculateOffsets(
        scheduledTime: dueTime,
        fromTime: now,
        customInterval: 15,
        customWindow: 60,
      );

      // Should generate 30 and 15 minutes before deadline (15 and 30 minutes after now)
      expect(offsets, equals([30, 15]));
    });

    test('1-minute interval generates 60 sequential pre-deadline alert offsets for 60m window', () {
      final now = DateTime(2026, 10, 7, 10, 0);
      final dueTime = DateTime(2026, 10, 7, 12, 0); // 2 hours ahead

      final offsets = NotificationService.instance.calculateOffsets(
        scheduledTime: dueTime,
        fromTime: now,
        customInterval: 1,
        customWindow: 60,
      );

      // Should generate all 60 offsets from 60 down to 1
      expect(offsets.length, equals(60));
      expect(offsets.first, equals(60));
      expect(offsets.last, equals(1));
      expect(offsets[1], equals(59));
    });

    test('getAllOffsetsForTask returns all offsets for configured window and interval', () {
      final offsets15m = NotificationService.instance.getAllOffsetsForTask(
        customInterval: 15,
        customWindow: 60,
      );
      expect(offsets15m, equals([60, 45, 30, 15]));

      final offsets1m = NotificationService.instance.getAllOffsetsForTask(
        customInterval: 1,
        customWindow: 60,
      );
      expect(offsets1m.length, equals(60));
      expect(offsets1m.first, equals(60));
      expect(offsets1m.last, equals(1));
    });
  });
}
