import 'dart:typed_data';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('AndroidNotificationDetails supports additionalFlags and insistent flag', () {
    // Android FLAG_INSISTENT is 4
    final details = AndroidNotificationDetails(
      'test_channel',
      'Test Channel',
      additionalFlags: Int32List.fromList([4]),
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'stop_alarm_action',
          'Stop Alarm',
          cancelNotification: true,
          showsUserInterface: true,
        ),
      ],
    );

    expect(details.additionalFlags, isNotNull);
    expect(details.additionalFlags!.contains(4), isTrue);
    expect(details.actions!.length, 1);
    expect(details.actions!.first.id, 'stop_alarm_action');
  });
}
