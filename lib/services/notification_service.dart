import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/intl.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import '../models/schedule_task.dart';
import 'db_service.dart';

class AlarmRingtone {
  final String id;
  final String name;
  final String subtitle;
  final String rawResourceName;
  final IconData icon;
  final String category;

  const AlarmRingtone({
    required this.id,
    
    required this.name,
    required this.subtitle,
    required this.rawResourceName,
    required this.icon,
    this.category = 'Alarm',
  });
}

/// Top-level background notification response handler invoked when notification action
/// buttons (such as "Stop Alarm") are tapped while the app is in the background or terminated.
@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse notificationResponse) {
  if (notificationResponse.id != null) {
    FlutterLocalNotificationsPlugin().cancel(id: notificationResponse.id!);
  }
}

class NotificationService {
  NotificationService._internal();
  static final NotificationService instance = NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notificationsPlugin =
      FlutterLocalNotificationsPlugin();

  static const MethodChannel _audioChannel =
      MethodChannel('com.example.taskscheduler/alarm_sound');

  static const List<AlarmRingtone> availableRingtones = [
    // Standard / Classic Alarms
    AlarmRingtone(
      id: 'alarm_digital',
      name: 'Digital Bedside Clock',
      subtitle: 'Electronic 4-burst fast beep alarm cadence',
      rawResourceName: 'alarm_digital',
      icon: Icons.alarm_rounded,
      category: 'Alarm',
    ),
    AlarmRingtone(
      id: 'alarm_siren',
      name: 'Emergency Siren Alarm',
      subtitle: 'Loud undulating high-urgency wailing siren',
      rawResourceName: 'alarm_siren',
      icon: Icons.warning_amber_rounded,
      category: 'Alarm',
    ),
    AlarmRingtone(
      id: 'alarm_bell',
      name: 'Classic Twin Bell',
      subtitle: 'High-speed mechanical twin-bell hammer chime',
      rawResourceName: 'alarm_bell',
      icon: Icons.notifications_active_rounded,
      category: 'Alarm',
    ),
    AlarmRingtone(
      id: 'alarm_urgent_pulse',
      name: 'Industrial Urgent Pulse',
      subtitle: 'Continuous rapid double-pulse alert tone',
      rawResourceName: 'alarm_urgent_pulse',
      icon: Icons.crisis_alert_rounded,
      category: 'Alarm',
    ),
    AlarmRingtone(
      id: 'alarm_chime',
      name: 'Melodic Wake-Up Chime',
      subtitle: 'Bright ascending marimba wake-up arpeggio',
      rawResourceName: 'alarm_chime',
      icon: Icons.music_note_rounded,
      category: 'Alarm',
    ),
    AlarmRingtone(
      id: 'system_alarm',
      name: 'System Default Alarm',
      subtitle: 'Phone native standard alarm sound (STREAM_ALARM)',
      rawResourceName: 'system_alarm',
      icon: Icons.phone_android_rounded,
      category: 'Alarm',
    ),

    // Simple Notification Sounds
    AlarmRingtone(
      id: 'sound_simple_ping',
      name: 'Subtle Ping',
      subtitle: 'Clean crisp single notification ping tone',
      rawResourceName: 'sound_simple_ping',
      icon: Icons.notifications_none_rounded,
      category: 'Simple Notification',
    ),
    AlarmRingtone(
      id: 'sound_bubble_pop',
      name: 'Bubble Pop',
      subtitle: 'Gentle cheerful rounded notification pop',
      rawResourceName: 'sound_bubble_pop',
      icon: Icons.bubble_chart_rounded,
      category: 'Simple Notification',
    ),
    AlarmRingtone(
      id: 'sound_gentle_ding',
      name: 'Gentle Glass Ding',
      subtitle: 'Minimal pleasant glass bell chime with natural tail',
      rawResourceName: 'sound_gentle_ding',
      icon: Icons.filter_vintage_rounded,
      category: 'Simple Notification',
    ),

    // Alert Sounds
    AlarmRingtone(
      id: 'sound_radar_beep',
      name: 'Radar Pulse Alert',
      subtitle: 'Tactical rhythmic dual-frequency radar sweep',
      rawResourceName: 'sound_radar_beep',
      icon: Icons.radar_rounded,
      category: 'Alert Sound',
    ),
    AlarmRingtone(
      id: 'sound_electronic_buzz',
      name: 'Electronic Buzzer',
      subtitle: 'Sharp attention-grabbing alert buzz cadence',
      rawResourceName: 'sound_electronic_buzz',
      icon: Icons.bolt_rounded,
      category: 'Alert Sound',
    ),
    AlarmRingtone(
      id: 'sound_caution_staccato',
      name: 'Caution Staccato',
      subtitle: 'Three fast urgent warning pulse bursts',
      rawResourceName: 'sound_caution_staccato',
      icon: Icons.priority_high_rounded,
      category: 'Alert Sound',
    ),

    // Long Sounds
    AlarmRingtone(
      id: 'sound_continuous_beacon',
      name: 'Continuous Beacon',
      subtitle: 'Extended 3-second harmonic acoustic alarm sequence',
      rawResourceName: 'sound_continuous_beacon',
      icon: Icons.waves_rounded,
      category: 'Long Sound',
    ),
    AlarmRingtone(
      id: 'sound_extended_klaxon',
      name: 'Extended Klaxon Horn',
      subtitle: 'Long dual-tone alternating industrial cadence',
      rawResourceName: 'sound_extended_klaxon',
      icon: Icons.campaign_rounded,
      category: 'Long Sound',
    ),
    AlarmRingtone(
      id: 'sound_persistent_loop',
      name: 'Persistent Ring',
      subtitle: 'Long rhythmic ringing chime alarm cycle',
      rawResourceName: 'sound_persistent_loop',
      icon: Icons.loop_rounded,
      category: 'Long Sound',
    ),

    // Melody Sounds
    AlarmRingtone(
      id: 'sound_celesta_harmony',
      name: 'Morning Celesta',
      subtitle: 'Peaceful 4-note ascending musical chime arpeggio',
      rawResourceName: 'sound_celesta_harmony',
      icon: Icons.piano_rounded,
      category: 'Melody',
    ),
    AlarmRingtone(
      id: 'sound_zen_harp',
      name: 'Zen Garden Harp',
      subtitle: 'Calming pentatonic acoustic harp melody',
      rawResourceName: 'sound_zen_harp',
      icon: Icons.spa_rounded,
      category: 'Melody',
    ),
    AlarmRingtone(
      id: 'sound_flute_breeze',
      name: 'Breeze Arpeggio',
      subtitle: 'Gentle acoustic woodwind melodic flourish',
      rawResourceName: 'sound_flute_breeze',
      icon: Icons.air_rounded,
      category: 'Melody',
    ),

    // Low Volume / Gentle Sounds
    AlarmRingtone(
      id: 'sound_soft_woodblock',
      name: 'Soft Woodblock',
      subtitle: 'Warm mellow low-volume acoustic percussion tap',
      rawResourceName: 'sound_soft_woodblock',
      icon: Icons.touch_app_rounded,
      category: 'Low Volume',
    ),
    AlarmRingtone(
      id: 'sound_whisper_chime',
      name: 'Whisper Chime',
      subtitle: 'Delicate low-intensity crystalline chime',
      rawResourceName: 'sound_whisper_chime',
      icon: Icons.volume_down_rounded,
      category: 'Low Volume',
    ),
    AlarmRingtone(
      id: 'sound_warm_ambient',
      name: 'Warm Ambient Glow',
      subtitle: 'Soft low-volume resonant bell with ambient tail',
      rawResourceName: 'sound_warm_ambient',
      icon: Icons.wb_twilight_rounded,
      category: 'Low Volume',
    ),
  ];

  String _activeSoundId = 'alarm_digital';
  String get activeSoundId => _activeSoundId;

  String? _customRingtoneUri;
  String? get customRingtoneUri => _customRingtoneUri;

  String? _customRingtoneTitle;
  String? get customRingtoneTitle => _customRingtoneTitle;

  AlarmRingtone get currentRingtone {
    if (_activeSoundId == 'custom' && _customRingtoneUri != null && _customRingtoneUri!.isNotEmpty) {
      return AlarmRingtone(
        id: 'custom',
        name: (_customRingtoneTitle != null && _customRingtoneTitle!.isNotEmpty)
            ? _customRingtoneTitle!
            : 'Custom Device Ringtone',
        subtitle: 'Audio from device storage / ringtones',
        rawResourceName: _customRingtoneUri!,
        icon: Icons.phonelink_ring_rounded,
        category: 'Device Custom',
      );
    }
    return availableRingtones.firstWhere(
      (r) => r.id == _activeSoundId || r.rawResourceName == _activeSoundId,
      orElse: () => availableRingtones.first,
    );
  }

  static String getChannelIdForSound(String soundId) =>
      'task_continuous_alarm_${soundId}_v5';

  static String getChannelNameForSound(String soundId) =>
      'Task Continuous Alarms ($soundId)';

  static const String channelDescription =
      'High-priority continuous looping alarm sound and vibration delivered at pre-deadline intervals and at task deadline until stopped';

  /// Offsets in minutes before scheduled deadline (legacy default)
  static const List<int> reminderOffsetsInMinutes = [60, 45, 30, 15];

  /// Due time alert index
  static const int dueTimeOffsetIndex = 999;

  /// User-configurable pre-deadline alert interval in minutes (e.g. 1, 2, 5, 10, 15, 20, 30)
  int _alertIntervalMinutes = 15;
  int get alertIntervalMinutes => _alertIntervalMinutes;

  /// User-configurable lead-time window in minutes before deadline (e.g. 60, 30, 120)
  int _alertWindowMinutes = 60;
  int get alertWindowMinutes => _alertWindowMinutes;

  /// Custom repeating vibration pattern: wait 0ms, vibrate 800ms, pause 200ms, vibrate 800ms, pause 200ms, vibrate 800ms
  static final Int64List alertVibrationPattern =
      Int64List.fromList([0, 800, 200, 800, 200, 800]);

  /// Android FLAG_INSISTENT (value = 4): repeats alarm sound and vibration in an infinite loop until dismissed
  static final Int32List insistentFlag = Int32List.fromList([4]);

  /// Notifier to notify UI when settings (sound, interval, window) or tasks change so UI updates instantly without refresh
  final ValueNotifier<int> settingsVersionNotifier = ValueNotifier<int>(0);

  void notifySettingsChanged() {
    settingsVersionNotifier.value++;
  }

  bool _isInitialized = false;

  /// Full initialization of Timezone database and Local Notifications plugin
  Future<void> initialize() async {
    if (_isInitialized) return;

    // 1. Initialize timezone database
    tz.initializeTimeZones();
    _configureLocalTimeZone();

    // 2. Android Initialization Settings
    const androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    // 3. iOS / Darwin Initialization Settings
    const darwinSettings = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );

    // 4. Combined Initialization Settings
    final initializationSettings = InitializationSettings(
      android: androidSettings,
      iOS: darwinSettings,
      macOS: darwinSettings,
    );

    // 5. Initialize plugin with response handler to stop alarms on tap/action
    await _notificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('Notification response actionId: ${response.actionId}, id: ${response.id}');
        if (response.id != null) {
          _notificationsPlugin.cancel(id: response.id!);
        }
      },
      onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
    );

    // 6. Load saved alarm ringtone and create channel
    try {
      final savedSound = await DBService.instance.getSetting(
        'selected_alarm_sound',
        defaultValue: 'alarm_digital',
      );
      _activeSoundId = savedSound ?? 'alarm_digital';
      _customRingtoneUri = await DBService.instance.getSetting('custom_ringtone_uri');
      _customRingtoneTitle = await DBService.instance.getSetting('custom_ringtone_title');
    } catch (_) {
      _activeSoundId = 'alarm_digital';
    }

    await _createAndroidNotificationChannel(_activeSoundId);

    // 7. Load saved pre-deadline alert interval and window
    try {
      final savedInterval = await DBService.instance.getSetting('alert_interval_minutes');
      if (savedInterval != null) {
        final parsed = int.tryParse(savedInterval);
        if (parsed != null && parsed > 0) _alertIntervalMinutes = parsed;
      }
      final savedWindow = await DBService.instance.getSetting('alert_window_minutes');
      if (savedWindow != null) {
        final parsed = int.tryParse(savedWindow);
        if (parsed != null && parsed > 0) _alertWindowMinutes = parsed;
      }
    } catch (_) {}

    _isInitialized = true;
  }

  /// Configures local timezone matching device current time offset
  void _configureLocalTimeZone() {
    try {
      final now = DateTime.now();
      final offsetMs = now.timeZoneOffset.inMilliseconds;

      tz.Location? matchedLocation;
      try {
        matchedLocation = tz.getLocation(now.timeZoneName);
      } catch (_) {
        // Fallback to match by current timezone offset
        for (final loc in tz.timeZoneDatabase.locations.values) {
          if (loc.currentTimeZone.offset == offsetMs) {
            matchedLocation = loc;
            break;
          }
        }
      }

      if (matchedLocation != null) {
        tz.setLocalLocation(matchedLocation);
      }
    } catch (e) {
      debugPrint('Error configuring local timezone: $e');
    }
  }

  /// Creates Android notification channel with max importance, alarm sound, and looping vibration
  Future<void> _createAndroidNotificationChannel([String? soundId]) async {
    final active = soundId ?? _activeSoundId;
    final String chId;
    final String chName;
    final AndroidNotificationSound notifSound;

    if (active == 'custom' && _customRingtoneUri != null && _customRingtoneUri!.isNotEmpty) {
      chId = 'task_continuous_alarm_custom_${_customRingtoneUri.hashCode}_v5';
      chName = 'Task Continuous Alarms (${_customRingtoneTitle ?? "Custom Sound"})';
      notifSound = UriAndroidNotificationSound(_customRingtoneUri!);
    } else if (active == 'system_alarm') {
      chId = getChannelIdForSound('system_alarm');
      chName = getChannelNameForSound('system_alarm');
      notifSound = const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    } else {
      chId = getChannelIdForSound(active);
      chName = getChannelNameForSound(active);
      notifSound = RawResourceAndroidNotificationSound(active);
    }

    final androidNotificationChannel = AndroidNotificationChannel(
      chId,
      chName,
      description: channelDescription,
      importance: Importance.max,
      playSound: true,
      sound: notifSound,
      enableVibration: true,
      vibrationPattern: alertVibrationPattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      showBadge: true,
    );

    try {
      final androidPlugin = _notificationsPlugin
          .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin>();

      if (androidPlugin != null) {
        await androidPlugin.createNotificationChannel(androidNotificationChannel);
      }
    } catch (e) {
      debugPrint('Channel creation skipped in test/non-Android environment: $e');
    }
  }

  /// Opens native Android ringtone / audio picker to select a custom ringtone from the mobile phone
  Future<Map<String, String>?> pickCustomRingtone() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _audioChannel.invokeMethod<Map>('pickRingtone', {
          'existingUri': _customRingtoneUri,
        });
        if (result != null) {
          final uri = result['uri']?.toString();
          final title = result['title']?.toString();
          if (uri != null && uri.isNotEmpty) {
            return {
              'uri': uri,
              'title': (title != null && title.isNotEmpty) ? title : 'Custom Phone Ringtone',
            };
          }
        }
      } catch (e) {
        debugPrint('Error picking custom ringtone: $e');
      }
    }
    return null;
  }

  /// Sets custom ringtone URI & title as the active alarm sound, creates channel, and persists
  Future<void> updateCustomRingtone({
    required String uri,
    required String title,
  }) async {
    _customRingtoneUri = uri;
    _customRingtoneTitle = title;
    _activeSoundId = 'custom';
    try {
      await DBService.instance.setSetting('selected_alarm_sound', 'custom');
      await DBService.instance.setSetting('custom_ringtone_uri', uri);
      await DBService.instance.setSetting('custom_ringtone_title', title);
    } catch (e) {
      debugPrint('Error saving custom ringtone: $e');
    }
    await _createAndroidNotificationChannel('custom');
    notifySettingsChanged();
  }

  /// Changes the user's active alarm ringtone, persists to DB, and registers the Android channel
  Future<void> updateActiveRingtone(String soundId) async {
    _activeSoundId = soundId;
    try {
      await DBService.instance.setSetting('selected_alarm_sound', soundId);
    } catch (e) {
      debugPrint('Error saving alarm sound preference: $e');
    }
    await _createAndroidNotificationChannel(soundId);
    notifySettingsChanged();
  }

  /// Updates user-preferred pre-deadline alert interval (in minutes), persists, and reschedules pending tasks
  Future<void> updateAlertInterval(int minutes) async {
    if (minutes <= 0) return;
    _alertIntervalMinutes = minutes;
    try {
      await DBService.instance.setSetting('alert_interval_minutes', minutes.toString());
    } catch (e) {
      debugPrint('Error saving alert interval: $e');
    }
    await rescheduleAllPendingTasks();
  }

  /// Updates user-preferred alert start window (in minutes before deadline), persists, and reschedules pending tasks
  Future<void> updateAlertWindow(int minutes) async {
    if (minutes <= 0) return;
    _alertWindowMinutes = minutes;
    try {
      await DBService.instance.setSetting('alert_window_minutes', minutes.toString());
    } catch (e) {
      debugPrint('Error saving alert window: $e');
    }
    await rescheduleAllPendingTasks();
  }

  /// Updates both alert interval and window simultaneously, persists, and reschedules all pending tasks
  Future<void> updateAlertTiming({
    required int intervalMinutes,
    required int windowMinutes,
  }) async {
    if (intervalMinutes > 0) _alertIntervalMinutes = intervalMinutes;
    if (windowMinutes > 0) _alertWindowMinutes = windowMinutes;
    try {
      await DBService.instance.setSetting('alert_interval_minutes', _alertIntervalMinutes.toString());
      await DBService.instance.setSetting('alert_window_minutes', _alertWindowMinutes.toString());
    } catch (e) {
      debugPrint('Error saving alert timing: $e');
    }
    await rescheduleAllPendingTasks();
  }

  /// Reschedules all pending tasks in the database with the newly selected interval and window
  Future<void> rescheduleAllPendingTasks() async {
    try {
      final allTasks = await DBService.instance.getAllTasks();
      final pendingTasks = allTasks.where((t) => t.isPending).toList();
      debugPrint(
        'Rescheduling ${pendingTasks.length} pending tasks with interval: $_alertIntervalMinutes min, window: $_alertWindowMinutes min...',
      );
      for (final task in pendingTasks) {
        await scheduleTaskAlerts(task);
      }
    } catch (e) {
      debugPrint('Notice: rescheduleAllPendingTasks: $e');
    }
    notifySettingsChanged();
  }

  /// Returns all standard pre-deadline offsets in descending order (e.g. [60, 59, ..., 1] for 1m interval)
  List<int> getAllOffsetsForTask({
    int? customInterval,
    int? customWindow,
  }) {
    final interval = (customInterval != null && customInterval > 0)
        ? customInterval
        : _alertIntervalMinutes;
    final window = (customWindow != null && customWindow > 0)
        ? customWindow
        : _alertWindowMinutes;

    final List<int> offsets = [];
    int offset = (window ~/ interval) * interval;
    while (offset > 0) {
      offsets.add(offset);
      offset -= interval;
    }
    return offsets;
  }

  /// Check whether notifications are enabled
  Future<bool> checkNotificationPermission() async {
    if (kIsWeb) return false;
    try {
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.areNotificationsEnabled() ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error checking notification permission: $e');
      return false;
    }
  }

  /// Check whether exact alarms are enabled (or request permission on Android)
  Future<bool> checkExactAlarmPermission() async {
    return await requestExactAlarmsPermission();
  }

  /// Request notification permissions on Android and iOS
  Future<bool> requestNotificationsPermission() async {
    try {
      if (kIsWeb) return false;

      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();

        if (androidPlugin != null) {
          final granted =
              await androidPlugin.requestNotificationsPermission() ?? false;
          return granted;
        }
      } else if (Platform.isIOS || Platform.isMacOS) {
        final iosPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                IOSFlutterLocalNotificationsPlugin>();

        if (iosPlugin != null) {
          final granted = await iosPlugin.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          );
          return granted ?? false;
        }
      }
    } catch (e) {
      debugPrint('Permission request error: $e');
    }
    return false;
  }

  /// Request exact alarms permission on Android (opens alarm settings if needed)
  Future<bool> requestExactAlarmsPermission() async {
    try {
      if (kIsWeb) return false;
      if (Platform.isAndroid) {
        final androidPlugin = _notificationsPlugin
            .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin>();
        return await androidPlugin?.requestExactAlarmsPermission() ?? false;
      }
      return true;
    } catch (e) {
      debugPrint('Error requesting exact alarm permission: $e');
      return false;
    }
  }

  /// Checks whether battery optimizations are ignored (unrestricted background)
  Future<bool> isBatteryOptimizationIgnored() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result =
            await _audioChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
        return result ?? false;
      } catch (e) {
        debugPrint('Error checking battery optimization: $e');
        return false;
      }
    }
    return true;
  }

  /// 1-Tap native dialog requesting battery optimization exemption (Unrestricted)
  Future<bool> requestIgnoreBatteryOptimization() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result = await _audioChannel
            .invokeMethod<bool>('requestIgnoreBatteryOptimizations');
        return result ?? false;
      } catch (e) {
        debugPrint('Error requesting battery optimization: $e');
        return false;
      }
    }
    return true;
  }

  /// Opens OEM Auto-Start settings (ZTE, Xiaomi, Oppo, Vivo, Samsung, Huawei)
  Future<bool> openAutoStartSettings() async {
    if (!kIsWeb && Platform.isAndroid) {
      try {
        final result =
            await _audioChannel.invokeMethod<bool>('openAutoStartSettings');
        return result ?? false;
      } catch (e) {
        debugPrint('Error opening auto start settings: $e');
        return false;
      }
    }
    return false;
  }

  /// Computes deterministic notification ID for a task and offset index: (taskId * 1000) + index
  static int getNotificationId(int taskId, int index) {
    return (taskId * 1000) + index;
  }

  /// Calculates dynamic pre-deadline reminder offsets in minutes before scheduled deadline
  List<int> calculateOffsets({
    required DateTime scheduledTime,
    required DateTime fromTime,
    int? customInterval,
    int? customWindow,
  }) {
    final interval = (customInterval != null && customInterval > 0)
        ? customInterval
        : _alertIntervalMinutes;
    final window = (customWindow != null && customWindow > 0)
        ? customWindow
        : _alertWindowMinutes;

    final totalMinutesUntilDue = scheduledTime.difference(fromTime).inMinutes;
    if (totalMinutesUntilDue <= 0) return [];

    final effectiveWindow = totalMinutesUntilDue < window
        ? totalMinutesUntilDue
        : window;

    final List<int> offsets = [];

    int offset = (effectiveWindow ~/ interval) * interval;
    while (offset > 0) {
      final alertTime = scheduledTime.subtract(Duration(minutes: offset));
      // Schedule if alertTime is at least 15 seconds in the future
      if (alertTime.isAfter(fromTime.add(const Duration(seconds: 15)))) {
        offsets.add(offset);
      }
      offset -= interval;
    }

    return offsets;
  }

  /// High importance notification details for continuous looping sound and vibration until stopped
  NotificationDetails _buildNotificationDetails({
    required String taskTitle,
    required String ticker,
    required String contentTitle,
    required String summaryText,
  }) {
    final String chId;
    final String chName;
    final AndroidNotificationSound notifSound;

    if (_activeSoundId == 'custom' && _customRingtoneUri != null && _customRingtoneUri!.isNotEmpty) {
      chId = 'task_continuous_alarm_custom_${_customRingtoneUri.hashCode}_v5';
      chName = 'Task Continuous Alarms (${_customRingtoneTitle ?? "Custom Sound"})';
      notifSound = UriAndroidNotificationSound(_customRingtoneUri!);
    } else if (_activeSoundId == 'system_alarm') {
      chId = getChannelIdForSound('system_alarm');
      chName = getChannelNameForSound('system_alarm');
      notifSound = const UriAndroidNotificationSound('content://settings/system/alarm_alert');
    } else {
      chId = getChannelIdForSound(_activeSoundId);
      chName = getChannelNameForSound(_activeSoundId);
      notifSound = RawResourceAndroidNotificationSound(_activeSoundId);
    }

    final androidDetails = AndroidNotificationDetails(
      chId,
      chName,
      channelDescription: channelDescription,
      importance: Importance.max,
      priority: Priority.max,
      playSound: true,
      sound: notifSound,
      enableVibration: true,
      vibrationPattern: alertVibrationPattern,
      audioAttributesUsage: AudioAttributesUsage.alarm,
      category: AndroidNotificationCategory.alarm,
      fullScreenIntent: true,
      autoCancel: true,
      visibility: NotificationVisibility.public,
      icon: '@mipmap/ic_launcher',
      largeIcon: const DrawableResourceAndroidBitmap('@mipmap/ic_launcher'),
      // FLAG_INSISTENT: loops the audio and vibration continuously until user dismisses or taps stop!
      additionalFlags: insistentFlag,
      actions: <AndroidNotificationAction>[
        const AndroidNotificationAction(
          'stop_alarm_action',
          'Stop Alarm',
          cancelNotification: true,
          showsUserInterface: false,
        ),
      ],
      ticker: ticker,
      styleInformation: BigTextStyleInformation(
        summaryText,
        contentTitle: contentTitle,
      ),
    );

    const darwinDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
      interruptionLevel: InterruptionLevel.timeSensitive,
    );

    return NotificationDetails(
      android: androidDetails,
      iOS: darwinDetails,
      macOS: darwinDetails,
    );
  }

  /// Schedules the pre-deadline reminder notifications at user-defined intervals AND due-time alarm
  Future<void> scheduleTaskAlerts(ScheduleTask task) async {
    if (task.id == null) {
      debugPrint('Cannot schedule alerts for task without an ID.');
      return;
    }

    if (!task.isPending) {
      debugPrint('Task ${task.id} is not pending. Skipping alert scheduling.');
      return;
    }

    // 0. Cancel any existing alerts for this task to avoid duplicate/stale alarms
    await cancelTaskAlerts(task.id!);

    final now = DateTime.now();
    final timeFormat = DateFormat.jm();
    final scheduledFormatted = timeFormat.format(task.scheduledTime);

    final canExact = await checkExactAlarmPermission();
    final primaryScheduleMode = canExact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;

    // Calculate dynamic offsets based on user's configured interval (e.g. 1m, 2m, 5m, 10m, 15m)
    final offsets = calculateOffsets(
      scheduledTime: task.scheduledTime,
      fromTime: now,
    );

    debugPrint(
      'Scheduling task #${task.id} ("${task.title}"): ${offsets.length} interval alerts ($offsets min before) + due alarm',
    );

    // 1. Schedule interval alerts
    for (int i = 0; i < offsets.length; i++) {
      final offsetMinutes = offsets[i];
      final alertDateTime = task.scheduledTime.subtract(
        Duration(minutes: offsetMinutes),
      );

      final notificationId = getNotificationId(task.id!, i);
      final tzAlertDateTime = tz.TZDateTime.from(alertDateTime, tz.local);

      final details = _buildNotificationDetails(
        taskTitle: task.title,
        ticker: 'Alarm Ringing: ${task.title} (Due in $offsetMinutes min)',
        contentTitle: 'Alarm: ${task.title} ($offsetMinutes min left)',
        summaryText:
            'Task "${task.title}" is due in $offsetMinutes minutes at $scheduledFormatted. Looping continuous alarm active until stopped.',
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          id: notificationId,
          title: 'Alarm Ringing ($offsetMinutes min left)',
          body: '"${task.title}" is due at $scheduledFormatted. Tap to stop alarm.',
          scheduledDate: tzAlertDateTime,
          notificationDetails: details,
          androidScheduleMode: primaryScheduleMode,
          payload: task.id.toString(),
        );

        debugPrint(
          'Scheduled alert #$notificationId for task "${task.title}" at $tzAlertDateTime ($offsetMinutes min prior)',
        );
      } catch (e) {
        debugPrint('Failed primary alarmClock schedule for #$notificationId: $e. Retrying in exactAllowWhileIdle mode...');
        try {
          await _notificationsPlugin.zonedSchedule(
            id: notificationId,
            title: 'Alarm Ringing ($offsetMinutes min left)',
            body: '"${task.title}" is due at $scheduledFormatted. Tap to stop alarm.',
            scheduledDate: tzAlertDateTime,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: task.id.toString(),
          );
        } catch (err) {
          debugPrint('exactAllowWhileIdle also failed for #$notificationId: $err. Retrying inexact...');
          try {
            await _notificationsPlugin.zonedSchedule(
              id: notificationId,
              title: 'Alarm Ringing ($offsetMinutes min left)',
              body: '"${task.title}" is due at $scheduledFormatted. Tap to stop alarm.',
              scheduledDate: tzAlertDateTime,
              notificationDetails: details,
              androidScheduleMode: AndroidScheduleMode.inexact,
              payload: task.id.toString(),
            );
          } catch (_) {}
        }
      }
    }

    // 2. Schedule Due-Time Alarm (at actual deadline)
    if (task.scheduledTime.isAfter(now)) {
      final dueNotificationId = getNotificationId(task.id!, dueTimeOffsetIndex);
      final tzDueDateTime = tz.TZDateTime.from(task.scheduledTime, tz.local);

      final dueDetails = _buildNotificationDetails(
        taskTitle: task.title,
        ticker: 'DEADLINE REACHED: ${task.title}',
        contentTitle: 'DEADLINE: ${task.title}',
        summaryText:
            'Task "${task.title}" is due NOW at $scheduledFormatted! Alarm will ring continuously until stopped.',
      );

      try {
        await _notificationsPlugin.zonedSchedule(
          id: dueNotificationId,
          title: 'TASK DEADLINE REACHED!',
          body: '"${task.title}" is due right now ($scheduledFormatted). Tap to stop alarm.',
          scheduledDate: tzDueDateTime,
          notificationDetails: dueDetails,
          androidScheduleMode: primaryScheduleMode,
          payload: task.id.toString(),
        );
        debugPrint(
          'Scheduled due-time alert #$dueNotificationId for task "${task.title}" at $tzDueDateTime',
        );
      } catch (e) {
        debugPrint('Failed primary alarmClock due schedule #$dueNotificationId: $e. Retrying in exactAllowWhileIdle mode...');
        try {
          await _notificationsPlugin.zonedSchedule(
            id: dueNotificationId,
            title: 'TASK DEADLINE REACHED!',
            body: '"${task.title}" is due right now ($scheduledFormatted). Tap to stop alarm.',
            scheduledDate: tzDueDateTime,
            notificationDetails: dueDetails,
            androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
            payload: task.id.toString(),
          );
        } catch (err) {
          debugPrint('exactAllowWhileIdle also failed for due alert #$dueNotificationId: $err. Retrying inexact...');
          try {
            await _notificationsPlugin.zonedSchedule(
              id: dueNotificationId,
              title: 'TASK DEADLINE REACHED!',
              body: '"${task.title}" is due right now ($scheduledFormatted). Tap to stop alarm.',
              scheduledDate: tzDueDateTime,
              notificationDetails: dueDetails,
              androidScheduleMode: AndroidScheduleMode.inexact,
              payload: task.id.toString(),
            );
          } catch (_) {}
        }
      }
    }
  }

  /// Cancels all scheduled notification IDs associated with [taskId] (interval alerts + due time)
  Future<void> cancelTaskAlerts(int taskId) async {
    final futures = <Future<void>>[];
    for (int i = 0; i < 200; i++) {
      futures.add(_notificationsPlugin.cancel(id: (taskId * 1000) + i));
    }
    futures.add(_notificationsPlugin.cancel(id: (taskId * 1000) + dueTimeOffsetIndex));
    // Also cancel legacy indices 0..10 just in case
    for (int i = 0; i <= 10; i++) {
      futures.add(_notificationsPlugin.cancel(id: (taskId * 10) + i));
    }
    try {
      await Future.wait(futures);
    } catch (e) {
      debugPrint('Error cancelling task alerts for $taskId: $e');
    }
    debugPrint('Cancelled all alerts for task $taskId');
  }

  /// Fires an immediate test alarm with looping sound and vibration right now
  Future<void> triggerImmediateTestAlarm({
    String title = 'Test Alarm',
    String body = 'Testing continuous looping sound and vibration. Tap "Stop Alarm" to dismiss.',
  }) async {
    final details = _buildNotificationDetails(
      taskTitle: title,
      ticker: '$title Ringing Now',
      contentTitle: '$title Ringing',
      summaryText: body,
    );

    await _notificationsPlugin.show(
      id: 999999,
      title: '$title Ringing!',
      body: body,
      notificationDetails: details,
      payload: 'test_immediate',
    );
  }

  /// Schedules a test alarm in [seconds] seconds (e.g. 60s for 1 min test)
  Future<void> scheduleTestAlarm({
    required int seconds,
    int testNotificationId = 999998,
    String title = '1-Minute Test Alarm',
    String body = 'Test alarm triggered after interval. Looping sound active.',
  }) async {
    final targetTime = DateTime.now().add(Duration(seconds: seconds));
    final tzTargetTime = tz.TZDateTime.from(targetTime, tz.local);

    final canExact = await checkExactAlarmPermission();
    final scheduleMode = canExact
        ? AndroidScheduleMode.alarmClock
        : AndroidScheduleMode.exactAllowWhileIdle;

    final details = _buildNotificationDetails(
      taskTitle: title,
      ticker: 'Test Alarm Ringing',
      contentTitle: '$title Ringing',
      summaryText: body,
    );

    try {
      await _notificationsPlugin.zonedSchedule(
        id: testNotificationId,
        title: '$title Ringing!',
        body: body,
        scheduledDate: tzTargetTime,
        notificationDetails: details,
        androidScheduleMode: scheduleMode,
        payload: 'test_scheduled',
      );
      debugPrint('Scheduled test alarm #$testNotificationId for $tzTargetTime ($seconds s from now)');
    } catch (e) {
      debugPrint('Primary alarmClock test schedule failed ($e). Retrying exactAllowWhileIdle...');
      try {
        await _notificationsPlugin.zonedSchedule(
          id: testNotificationId,
          title: '$title Ringing!',
          body: body,
          scheduledDate: tzTargetTime,
          notificationDetails: details,
          androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
          payload: 'test_scheduled',
        );
      } catch (err) {
        debugPrint('exactAllowWhileIdle test failed ($err). Retrying inexact...');
        try {
          await _notificationsPlugin.zonedSchedule(
            id: testNotificationId,
            title: '$title Ringing!',
            body: body,
            scheduledDate: tzTargetTime,
            notificationDetails: details,
            androidScheduleMode: AndroidScheduleMode.inexact,
            payload: 'test_scheduled',
          );
        } catch (_) {}
      }
    }
  }

  /// Cancels a test alarm
  Future<void> cancelTestAlarm([int testNotificationId = 999998]) async {
    await _notificationsPlugin.cancel(id: testNotificationId);
  }

  /// Stops a single ringing alarm notification immediately
  Future<void> stopRingingAlarm(int notificationId) async {
    await _notificationsPlugin.cancel(id: notificationId);
  }

  /// Plays an authentic looping alarm preview through STREAM_ALARM
  Future<void> playAlarmPreview(String soundName) async {
    try {
      await _audioChannel.invokeMethod('playAlarmPreview', {'sound': soundName});
    } catch (e) {
      debugPrint('Error playing alarm preview: $e');
    }
  }

  /// Stops any running alarm audio preview immediately
  Future<void> stopAlarmPreview() async {
    try {
      await _audioChannel.invokeMethod('stopAlarmPreview');
    } catch (e) {
      debugPrint('Error stopping alarm preview: $e');
    }
  }

  /// Stops currently active/ringing alarms without cancelling future scheduled task alarms
  Future<void> stopAllRingingAlarms() async {
    await stopAlarmPreview();
    try {
      final activeNotifs = await _notificationsPlugin.getActiveNotifications();
      for (final a in activeNotifs) {
        if (a.id != null) {
          await _notificationsPlugin.cancel(id: a.id!);
        }
      }
    } catch (e) {
      debugPrint('Error clearing active notifications: $e');
    }
    // Also cancel test notification IDs
    try {
      await _notificationsPlugin.cancel(id: 999999);
      await _notificationsPlugin.cancel(id: 999998);
    } catch (_) {}
  }

  /// Cancel all notifications across the application
  Future<void> cancelAllAlerts() async {
    await stopAlarmPreview();
    await _notificationsPlugin.cancelAll();
  }
}
