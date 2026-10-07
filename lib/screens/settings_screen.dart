import 'dart:async';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../services/notification_service.dart';
import '../widgets/confirmation_dialog.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color darkBarColor = Color(0xFF171717);

  bool _notificationsAllowed = false;
  bool _exactAlarmsAllowed = false;
  bool _batteryIgnored = false;
  bool _isLoadingPermissions = true;

  // Ringtone Selector State
  String _selectedRingtoneId = 'alarm_digital';
  String? _previewingRingtoneId;

  // Interval & Timing State
  int _alertIntervalMinutes = 15;
  int _alertWindowMinutes = 60;

  // Test Station State
  int _selectedSeconds = 60; // Default: 1 minute
  bool _repeatEveryInterval = true;
  bool _isTestRunning = false;
  int _secondsRemaining = 0;
  Timer? _countdownTimer;
  Timer? _repeatTimer;
  DateTime? _nextAlertTime;

  @override
  void initState() {
    super.initState();
    _selectedRingtoneId = NotificationService.instance.activeSoundId;
    _alertIntervalMinutes = NotificationService.instance.alertIntervalMinutes;
    _alertWindowMinutes = NotificationService.instance.alertWindowMinutes;
    _checkPermissions();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _repeatTimer?.cancel();
    NotificationService.instance.stopAlarmPreview();
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    setState(() {
      _isLoadingPermissions = true;
    });

    final notifs = await NotificationService.instance.checkNotificationPermission();
    final exact = await NotificationService.instance.checkExactAlarmPermission();
    final battery = await NotificationService.instance.isBatteryOptimizationIgnored();

    if (mounted) {
      setState(() {
        _notificationsAllowed = notifs;
        _exactAlarmsAllowed = exact;
        _batteryIgnored = battery;
        _isLoadingPermissions = false;
        _alertIntervalMinutes = NotificationService.instance.alertIntervalMinutes;
        _alertWindowMinutes = NotificationService.instance.alertWindowMinutes;
        _selectedRingtoneId = NotificationService.instance.activeSoundId;
      });
    }
  }

  Future<void> _requestNotificationPermission() async {
    final granted = await NotificationService.instance.requestNotificationsPermission();
    await _checkPermissions();
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(granted
              ? 'Notification permission granted!'
              : 'Notification permission was not granted.'),
          backgroundColor: granted ? emeraldGreen : const Color(0xFFEF4444),
        ),
      );
    }
  }

  Future<void> _requestExactAlarmPermission() async {
    await NotificationService.instance.requestExactAlarmsPermission();
    await Future.delayed(const Duration(milliseconds: 500));
    await _checkPermissions();
  }

  Future<void> _togglePreview(AlarmRingtone ringtone) async {
    if (_previewingRingtoneId == ringtone.rawResourceName) {
      await NotificationService.instance.stopAlarmPreview();
      if (mounted) {
        setState(() {
          _previewingRingtoneId = null;
        });
      }
    } else {
      await NotificationService.instance.playAlarmPreview(ringtone.rawResourceName);
      if (mounted) {
        setState(() {
          _previewingRingtoneId = ringtone.rawResourceName;
        });
      }
    }
  }

  Future<void> _selectRingtone(AlarmRingtone ringtone) async {
    setState(() {
      _selectedRingtoneId = ringtone.id;
    });

    await NotificationService.instance.updateActiveRingtone(ringtone.rawResourceName);

    // Play preview automatically so user immediately hears authentic alarm sound
    await NotificationService.instance.playAlarmPreview(ringtone.rawResourceName);
    if (mounted) {
      setState(() {
        _previewingRingtoneId = ringtone.rawResourceName;
      });
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Alarm sound set to "${ringtone.name}"',
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
          backgroundColor: emeraldGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Future<void> _triggerImmediateTest() async {
    await NotificationService.instance.stopAlarmPreview();
    if (mounted) {
      setState(() {
        _previewingRingtoneId = null;
      });
    }

    final currentRingtone = NotificationService.instance.currentRingtone;
    await NotificationService.instance.triggerImmediateTestAlarm(
      title: 'Immediate Test Alarm',
      body: 'Continuous sound (${currentRingtone.name}) & vibration active. Tap "Stop Alarm" to dismiss.',
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Ringing test alarm with ${currentRingtone.name}! Check status bar.'),
          backgroundColor: emeraldGreen,
        ),
      );
    }
  }

  void _startScheduledAlarmTest() async {
    await NotificationService.instance.stopAlarmPreview();
    if (mounted) {
      setState(() {
        _previewingRingtoneId = null;
      });
    }

    _countdownTimer?.cancel();
    _repeatTimer?.cancel();

    final interval = _selectedSeconds;
    final now = DateTime.now();
    final target = now.add(Duration(seconds: interval));

    setState(() {
      _isTestRunning = true;
      _secondsRemaining = interval;
      _nextAlertTime = target;
    });

    await NotificationService.instance.scheduleTestAlarm(
      seconds: interval,
      testNotificationId: 999998,
      title: 'Alarm Test (${_formatSeconds(interval)})',
      body: 'Test alarm successfully triggered after ${_formatSeconds(interval)}. Continuous sound active!',
    );

    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      setState(() {
        if (_secondsRemaining > 1) {
          _secondsRemaining--;
        } else {
          _secondsRemaining = 0;
          timer.cancel();
        }
      });
    });

    if (_repeatEveryInterval) {
      _repeatTimer = Timer.periodic(Duration(seconds: interval), (timer) async {
        if (!_isTestRunning || !mounted) {
          timer.cancel();
          return;
        }

        final nextTarget = DateTime.now().add(Duration(seconds: interval));
        setState(() {
          _secondsRemaining = interval;
          _nextAlertTime = nextTarget;
        });

        await NotificationService.instance.scheduleTestAlarm(
          seconds: interval,
          testNotificationId: 999998,
          title: 'Repeating Alarm Test (${_formatSeconds(interval)})',
          body: 'Scheduled interval alarm fired. Next alert in ${_formatSeconds(interval)}.',
        );

        _countdownTimer?.cancel();
        _countdownTimer = Timer.periodic(const Duration(seconds: 1), (cdTimer) {
          if (!mounted) {
            cdTimer.cancel();
            return;
          }
          setState(() {
            if (_secondsRemaining > 1) {
              _secondsRemaining--;
            } else {
              _secondsRemaining = 0;
              cdTimer.cancel();
            }
          });
        });
      });
    }

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '⏰ Alarm test scheduled! Will fire in ${_formatSeconds(interval)} and repeat.',
          ),
          backgroundColor: emeraldGreen,
          duration: const Duration(seconds: 3),
        ),
      );
    }
  }

  Future<void> _stopAlarmTest() async {
    final confirmed = await ConfirmationDialog.confirmStopTestAlarm(context);
    if (!confirmed) return;

    _countdownTimer?.cancel();
    _repeatTimer?.cancel();

    await NotificationService.instance.cancelTestAlarm();
    await NotificationService.instance.stopAllRingingAlarms();

    setState(() {
      _isTestRunning = false;
      _secondsRemaining = 0;
      _nextAlertTime = null;
      _previewingRingtoneId = null;
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Alarm test cancelled and active test alarms stopped.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
    }
  }

  String _formatSeconds(int seconds) {
    if (seconds < 60) return '$seconds sec';
    final mins = seconds ~/ 60;
    return '$mins min';
  }

  String _formatCountdown(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }

  // --- REUSABLE MODAL POPUP WRAPPER ---
  Future<void> _showModalPopup({
    required BuildContext context,
    required String title,
    required IconData icon,
    required Widget Function(BuildContext modalContext, StateSetter modalSetState) builder,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (modalCtx, modalSetState) {
          return Container(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.88,
            ),
            decoration: const BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Top drag pill
                Container(
                  margin: const EdgeInsets.only(top: 12, bottom: 8),
                  width: 44,
                  height: 4,
                  decoration: BoxDecoration(
                    color: const Color(0xFFCBD5E1),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                // Modal Header
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: emeraldGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(icon, color: emeraldGreen, size: 22),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          title,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF171717),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, color: Color(0xFF64748B)),
                        tooltip: 'Close',
                        onPressed: () {
                          NotificationService.instance.stopAlarmPreview();
                          Navigator.of(ctx).pop();
                        },
                      ),
                    ],
                  ),
                ),
                const Divider(height: 1, color: Color(0xFFE2E8F0)),
                // Content
                Flexible(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
                    child: builder(modalCtx, modalSetState),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    ).then((_) {
      if (mounted) {
        setState(() {
          _selectedRingtoneId = NotificationService.instance.activeSoundId;
          _alertIntervalMinutes = NotificationService.instance.alertIntervalMinutes;
          _alertWindowMinutes = NotificationService.instance.alertWindowMinutes;
        });
      }
    });
  }

  // --- 1. MODAL: SYSTEM PERMISSIONS ---
  void _openPermissionsModal() {
    _showModalPopup(
      context: context,
      title: 'System Permissions',
      icon: Icons.security_rounded,
      builder: (mCtx, mSetState) {
        final allGranted = _notificationsAllowed && _exactAlarmsAllowed;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: allGranted
                    ? emeraldGreen.withValues(alpha: 0.08)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: allGranted
                      ? emeraldGreen.withValues(alpha: 0.3)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    allGranted ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: allGranted ? emeraldGreen : const Color(0xFFEF4444),
                    size: 24,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      allGranted
                          ? 'All required system permissions are active. Continuous alarms will ring reliably.'
                          : 'Action required: Grant both permissions below to allow exact background alarm alarms.',
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: allGranted ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                        height: 1.3,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            _buildPermissionItem(
              title: 'Notification Alerts',
              desc: 'Required to show pre-deadline notification cards and alarm banners on screen.',
              isGranted: _notificationsAllowed,
              onRequest: () async {
                await _requestNotificationPermission();
                mSetState(() {});
              },
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              title: 'Exact Alarms (Schedule)',
              desc: 'Required on Android 12, 13 & 14 to wake the device at the exact target second.',
              isGranted: _exactAlarmsAllowed,
              onRequest: () async {
                await _requestExactAlarmPermission();
                mSetState(() {});
              },
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              title: '1-Tap Background (Battery Optimization)',
              desc: 'Allows alarms to ring when app is closed. Tapping grants Unrestricted battery mode.',
              isGranted: _batteryIgnored,
              onRequest: () async {
                await NotificationService.instance.requestIgnoreBatteryOptimization();
                await Future.delayed(const Duration(milliseconds: 500));
                await _checkPermissions();
                mSetState(() {});
              },
            ),
            const SizedBox(height: 12),
            // Auto-start quick link
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.settings_power_rounded, size: 16, color: emeraldGreen),
                  const SizedBox(width: 8),
                  const Expanded(
                    child: Text(
                      'ZTE, Xiaomi & Samsung phones:',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                    ),
                  ),
                  InkWell(
                    onTap: () => NotificationService.instance.openAutoStartSettings(),
                    child: const Text(
                      'Auto-Start Settings',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: emeraldGreen),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.refresh_rounded, size: 20),
              label: const Text('Refresh Permissions Status', style: TextStyle(fontWeight: FontWeight.bold)),
              onPressed: () async {
                await _checkPermissions();
                mSetState(() {});
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildPermissionItem({
    required String title,
    required String desc,
    required bool isGranted,
    required VoidCallback onRequest,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isGranted ? emeraldGreen.withValues(alpha: 0.15) : const Color(0xFFFEE2E2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  isGranted ? 'ACTIVE' : 'PENDING',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: isGranted ? const Color(0xFF047857) : const Color(0xFFDC2626),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(desc, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
          if (!isGranted) ...[
            const SizedBox(height: 10),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF171717),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              ),
              onPressed: onRequest,
              child: const Text('Grant Permission', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
            ),
          ],
        ],
      ),
    );
  }

  // --- 2. MODAL: ALARM RINGTONE SELECTOR ---
  void _openRingtoneModal() {
    String selectedCategory = 'All';
    final categories = [
      'All',
      'Simple Notification',
      'Alert Sound',
      'Long Sound',
      'Melody',
      'Low Volume',
      'Alarm',
    ];

    _showModalPopup(
      context: context,
      title: 'Alarm Ringtone & Sound',
      icon: Icons.notifications_active_rounded,
      builder: (mCtx, mSetState) {
        final filteredRingtones = selectedCategory == 'All'
            ? NotificationService.availableRingtones
            : NotificationService.availableRingtones
                .where((r) => r.category == selectedCategory)
                .toList();

        final customUri = NotificationService.instance.customRingtoneUri;
        final customTitle = NotificationService.instance.customRingtoneTitle ?? 'Custom Phone Ringtone';
        final isCustomSelected = _selectedRingtoneId == 'custom' ||
            (customUri != null && _selectedRingtoneId == customUri);
        final isPlayingCustom = customUri != null && _previewingRingtoneId == customUri;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Select from 21 built-in ringtones or choose a custom sound directly from your phone. Alarms loop continuously through STREAM_ALARM until stopped.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 14),

            // --- Option to Select Custom Ringtone From Mobile Phone ---
            Container(
              margin: const EdgeInsets.only(bottom: 14),
              decoration: BoxDecoration(
                color: isCustomSelected ? emeraldGreen.withValues(alpha: 0.05) : const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isCustomSelected ? emeraldGreen : const Color(0xFFCBD5E1),
                  width: isCustomSelected ? 1.8 : 1.0,
                ),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(14),
                  onTap: () async {
                    if (customUri == null) {
                      final picked = await NotificationService.instance.pickCustomRingtone();
                      if (picked != null) {
                        await NotificationService.instance.updateCustomRingtone(
                          uri: picked['uri']!,
                          title: picked['title']!,
                        );
                        await NotificationService.instance.playAlarmPreview(picked['uri']!);
                        if (mounted) {
                          setState(() {
                            _selectedRingtoneId = 'custom';
                            _previewingRingtoneId = picked['uri'];
                          });
                        }
                        mSetState(() {});
                      }
                    } else {
                      await NotificationService.instance.updateCustomRingtone(
                        uri: customUri,
                        title: customTitle,
                      );
                      await NotificationService.instance.playAlarmPreview(customUri);
                      if (mounted) {
                        setState(() {
                          _selectedRingtoneId = 'custom';
                          _previewingRingtoneId = customUri;
                        });
                      }
                      mSetState(() {});
                    }
                  },
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: isCustomSelected
                                ? emeraldGreen.withValues(alpha: 0.15)
                                : const Color(0xFFE2E8F0),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Icon(
                            Icons.phonelink_ring_rounded,
                            color: isCustomSelected ? emeraldGreen : const Color(0xFF334155),
                            size: 22,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                customUri != null ? customTitle : 'Custom Sound from Phone',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.bold,
                                  color: isCustomSelected ? emeraldGreen : const Color(0xFF171717),
                                ),
                              ),
                              const SizedBox(height: 3),
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFE2E8F0),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'Device Audio',
                                      style: TextStyle(
                                        fontSize: 9.5,
                                        fontWeight: FontWeight.w600,
                                        color: Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                  if (isCustomSelected) ...[
                                    const SizedBox(width: 6),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: emeraldGreen,
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: const Text(
                                        'ACTIVE',
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                        ),
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 2),
                              Text(
                                customUri != null
                                    ? 'Selected from your device audio / ringtones'
                                    : 'Choose any audio file or ringtone from mobile',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (customUri != null) ...[
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: isPlayingCustom
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFF1F5F9),
                              foregroundColor: isPlayingCustom ? const Color(0xFFEF4444) : const Color(0xFF475569),
                            ),
                            icon: Icon(isPlayingCustom ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
                            tooltip: isPlayingCustom ? 'Stop preview' : 'Play preview',
                            onPressed: () async {
                              if (isPlayingCustom) {
                                await NotificationService.instance.stopAlarmPreview();
                                if (mounted) setState(() => _previewingRingtoneId = null);
                              } else {
                                await NotificationService.instance.playAlarmPreview(customUri);
                                if (mounted) setState(() => _previewingRingtoneId = customUri);
                              }
                              mSetState(() {});
                            },
                          ),
                          const SizedBox(width: 4),
                        ],
                        OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: const Color(0xFF171717),
                            side: const BorderSide(color: Color(0xFFCBD5E1)),
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                          ),
                          onPressed: () async {
                            final picked = await NotificationService.instance.pickCustomRingtone();
                            if (picked != null) {
                              await NotificationService.instance.updateCustomRingtone(
                                uri: picked['uri']!,
                                title: picked['title']!,
                              );
                              await NotificationService.instance.playAlarmPreview(picked['uri']!);
                              if (mounted) {
                                setState(() {
                                  _selectedRingtoneId = 'custom';
                                  _previewingRingtoneId = picked['uri'];
                                });
                              }
                              mSetState(() {});
                            }
                          },
                          child: Text(
                            customUri != null ? 'Change' : 'Choose',
                            style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // Category Filter Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: categories.map((cat) {
                  final isCatSel = selectedCategory == cat;
                  final count = cat == 'All'
                      ? NotificationService.availableRingtones.length
                      : NotificationService.availableRingtones
                          .where((r) => r.category == cat)
                          .length;

                  return Padding(
                    padding: const EdgeInsets.only(right: 6),
                    child: ChoiceChip(
                      label: Text('$cat ($count)'),
                      selected: isCatSel,
                      selectedColor: emeraldGreen,
                      backgroundColor: const Color(0xFFF1F5F9),
                      labelStyle: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: isCatSel ? Colors.white : const Color(0xFF334155),
                      ),
                      showCheckmark: false,
                      onSelected: (val) {
                        if (val) {
                          mSetState(() {
                            selectedCategory = cat;
                          });
                        }
                      },
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            ...filteredRingtones.map((ringtone) {
              final isSelected = ringtone.id == _selectedRingtoneId ||
                  ringtone.rawResourceName == _selectedRingtoneId;
              final isPlaying = _previewingRingtoneId == ringtone.rawResourceName;

              return Container(
                margin: const EdgeInsets.only(bottom: 10),
                decoration: BoxDecoration(
                  color: isSelected ? emeraldGreen.withValues(alpha: 0.05) : Colors.white,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: isSelected ? emeraldGreen : const Color(0xFFE2E8F0),
                    width: isSelected ? 1.8 : 1.0,
                  ),
                ),
                child: Material(
                  color: Colors.transparent,
                  child: InkWell(
                    borderRadius: BorderRadius.circular(14),
                    onTap: () async {
                      await _selectRingtone(ringtone);
                      mSetState(() {});
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: isSelected
                                  ? emeraldGreen.withValues(alpha: 0.15)
                                  : const Color(0xFFF1F5F9),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Icon(
                              ringtone.icon,
                              color: isSelected ? emeraldGreen : const Color(0xFF475569),
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                // Ringtone Title - full line width, never breaks layout!
                                Text(
                                  ringtone.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.bold,
                                    color: isSelected ? emeraldGreen : const Color(0xFF171717),
                                  ),
                                ),
                                const SizedBox(height: 3),
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFFF1F5F9),
                                        borderRadius: BorderRadius.circular(4),
                                      ),
                                      child: Text(
                                        ringtone.category,
                                        style: const TextStyle(
                                          fontSize: 9.5,
                                          fontWeight: FontWeight.w600,
                                          color: Color(0xFF64748B),
                                        ),
                                      ),
                                    ),
                                    if (isSelected) ...[
                                      const SizedBox(width: 6),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
                                        decoration: BoxDecoration(
                                          color: emeraldGreen,
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                        child: const Text(
                                          'ACTIVE',
                                          style: TextStyle(
                                            fontSize: 9,
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  ringtone.subtitle,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Preview Play/Stop Button
                          IconButton.filled(
                            style: IconButton.styleFrom(
                              backgroundColor: isPlaying
                                  ? const Color(0xFFFEE2E2)
                                  : const Color(0xFFF1F5F9),
                              foregroundColor: isPlaying ? const Color(0xFFEF4444) : const Color(0xFF475569),
                            ),
                            icon: Icon(isPlaying ? Icons.stop_rounded : Icons.play_arrow_rounded, size: 20),
                            tooltip: isPlaying ? 'Stop preview' : 'Play preview',
                            onPressed: () async {
                              await _togglePreview(ringtone);
                              mSetState(() {});
                            },
                          ),
                          const SizedBox(width: 4),
                          // Radio / Selection checkmark indicator
                          Icon(
                            isSelected ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                            color: isSelected ? emeraldGreen : const Color(0xFFCBD5E1),
                            size: 22,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            }),
          ],
        );
      },
    );
  }

  // --- 3. MODAL: PRE-DEADLINE ALERT INTERVALS & TIMING ---
  void _openAlertIntervalModal() {
    int tempInterval = _alertIntervalMinutes;
    int tempWindow = _alertWindowMinutes;
    final intervalOptions = [1, 2, 5, 10, 15, 20, 30];
    final windowOptions = [15, 30, 45, 60, 120];

    _showModalPopup(
      context: context,
      title: 'Pre-Deadline Alert Intervals',
      icon: Icons.timer_outlined,
      builder: (mCtx, mSetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline_rounded, color: emeraldGreen, size: 20),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Set how often the continuous alarm rings before your task deadline. It will alert at every configured interval until stopped.',
                      style: TextStyle(fontSize: 12, color: Color(0xFF475569), height: 1.3),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // 1. Alert Frequency Interval
            const Text(
              'Alert Frequency (Interval Minutes)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
            ),
            const SizedBox(height: 4),
            Text(
              'Alarms will ring every $tempInterval minute${tempInterval == 1 ? '' : 's'} leading up to the deadline.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: intervalOptions.map((mins) {
                final isSel = tempInterval == mins;
                return ChoiceChip(
                  label: Text(
                    mins == 15 ? '15 min (Default)' : '$mins min',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : const Color(0xFF171717),
                    ),
                  ),
                  selected: isSel,
                  selectedColor: emeraldGreen,
                  backgroundColor: const Color(0xFFF1F5F9),
                  showCheckmark: false,
                  onSelected: (val) {
                    if (val) {
                      mSetState(() {
                        tempInterval = mins;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 18),

            // 2. Alert Starting Window
            const Text(
              'Alert Starting Window (Lead Time)',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
            ),
            const SizedBox(height: 4),
            Text(
              'Interval alarms start ringing $tempWindow minute${tempWindow == 1 ? '' : 's'} prior to deadline.',
              style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: windowOptions.map((win) {
                final isSel = tempWindow == win;
                final label = win == 60
                    ? '1 hour (Default)'
                    : (win == 120 ? '2 hours' : '$win min');

                return ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : const Color(0xFF171717),
                    ),
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFF171717),
                  backgroundColor: const Color(0xFFF1F5F9),
                  showCheckmark: false,
                  onSelected: (val) {
                    if (val) {
                      mSetState(() {
                        tempWindow = win;
                      });
                    }
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 20),

            // 3. Live Simulation Timeline Card
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: emeraldGreen.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: emeraldGreen.withValues(alpha: 0.2)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.timeline_rounded, color: emeraldGreen, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        'Live Simulation (Task due in $tempWindow min)',
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF065F46),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'With an interval of $tempInterval min, your device will ring at:\n'
                    '${_buildSimulationTimeline(tempInterval, tempWindow)}',
                    style: const TextStyle(fontSize: 11.5, color: Color(0xFF047857), height: 1.4),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Save Button
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: () async {
                await NotificationService.instance.updateAlertTiming(
                  intervalMinutes: tempInterval,
                  windowMinutes: tempWindow,
                );

                if (mounted) {
                  setState(() {
                    _alertIntervalMinutes = tempInterval;
                    _alertWindowMinutes = tempWindow;
                  });

                  Navigator.of(context).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        'Alert timing saved: rings every $tempInterval min up to deadline.',
                      ),
                      backgroundColor: emeraldGreen,
                    ),
                  );
                }
              },
              child: const Text(
                'Save Interval Timing',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        );
      },
    );
  }

  String _buildSimulationTimeline(int interval, int window) {
    final List<String> steps = [];
    int offset = (window ~/ interval) * interval;
    while (offset > 0) {
      steps.add('• $offset min before deadline');
      offset -= interval;
    }
    steps.add('• 0 min (Final Deadline Alarm)');
    return steps.join('\n');
  }

  // --- 4. MODAL: ALARM TESTING STATION & DEBUGGER ---
  void _openAlarmDebuggerModal() {
    final testIntervals = [30, 60, 120, 300];

    _showModalPopup(
      context: context,
      title: 'Alarm Testing & Debug Station',
      icon: Icons.bug_report_rounded,
      builder: (mCtx, mSetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Validate that looping alarms ring through lock screens and low-power modes. Test immediately or schedule a repeating test.',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF64748B), height: 1.35),
            ),
            const SizedBox(height: 16),

            // Immediate Trigger Button
            ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: emeraldGreen,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 13),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.alarm_add_rounded, size: 20),
              label: const Text(
                'Ring Test Alarm Right Now',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
              ),
              onPressed: () async {
                await _triggerImmediateTest();
                mSetState(() {});
              },
            ),
            const SizedBox(height: 20),

            const Text(
              'Scheduled Interval Test',
              style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
            ),
            const SizedBox(height: 6),
            const Text(
              'Choose an interval and test background triggering while the screen is locked:',
              style: TextStyle(fontSize: 12, color: Color(0xFF64748B)),
            ),
            const SizedBox(height: 10),

            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: testIntervals.map((sec) {
                final isSel = _selectedSeconds == sec;
                final label = sec == 60 ? '1 min (Recommended)' : _formatSeconds(sec);

                return ChoiceChip(
                  label: Text(
                    label,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: isSel ? Colors.white : const Color(0xFF171717),
                    ),
                  ),
                  selected: isSel,
                  selectedColor: const Color(0xFF171717),
                  backgroundColor: const Color(0xFFF1F5F9),
                  showCheckmark: false,
                  onSelected: _isTestRunning
                      ? null
                      : (val) {
                          if (val) {
                            setState(() {
                              _selectedSeconds = sec;
                            });
                            mSetState(() {});
                          }
                        },
                );
              }).toList(),
            ),
            const SizedBox(height: 12),

            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              activeColor: emeraldGreen,
              title: const Text(
                'Repeat alarm every interval until stopped',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: const Text(
                'Simulates continuous alert cycle in background',
                style: TextStyle(fontSize: 11, color: Color(0xFF64748B)),
              ),
              value: _repeatEveryInterval,
              onChanged: _isTestRunning
                  ? null
                  : (v) {
                      setState(() {
                        _repeatEveryInterval = v ?? true;
                      });
                      mSetState(() {});
                    },
            ),
            const SizedBox(height: 16),

            if (!_isTestRunning) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF171717),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.timer_outlined, size: 20),
                label: Text(
                  'Start Alarm Test (${_formatSeconds(_selectedSeconds)})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () {
                  _startScheduledAlarmTest();
                  mSetState(() {});
                },
              ),
            ] else ...[
              // Test Active Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: emeraldGreen.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: emeraldGreen),
                ),
                child: Column(
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('Next Alarm Fires In:', style: TextStyle(fontWeight: FontWeight.bold)),
                        Text(
                          _formatCountdown(_secondsRemaining),
                          style: const TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                            color: emeraldGreen,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LinearProgressIndicator(
                      value: _selectedSeconds > 0
                          ? (1.0 - (_secondsRemaining / _selectedSeconds)).clamp(0.0, 1.0)
                          : 0,
                      backgroundColor: const Color(0xFFE2E8F0),
                      valueColor: const AlwaysStoppedAnimation(emeraldGreen),
                    ),
                    if (_nextAlertTime != null) ...[
                      const SizedBox(height: 8),
                      Text(
                        'Scheduled for: ${DateFormat.jms().format(_nextAlertTime!)}',
                        style: const TextStyle(fontSize: 11, color: Color(0xFF64748B)),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 12),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFEF4444),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.stop_rounded, size: 20),
                label: const Text(
                  'Stop Test Alarm & Reset',
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await _stopAlarmTest();
                  mSetState(() {});
                },
              ),
            ],
          ],
        );
      },
    );
  }

  // --- 5. MODAL: BATTERY OPTIMIZATION GUIDE ---
  void _openBatteryGuideModal() {
    _showModalPopup(
      context: context,
      title: 'Background & Battery Optimization',
      icon: Icons.battery_charging_full_rounded,
      builder: (mCtx, mSetState) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Status Banner
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: _batteryIgnored
                    ? emeraldGreen.withValues(alpha: 0.1)
                    : const Color(0xFFFEF2F2),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: _batteryIgnored
                      ? emeraldGreen.withValues(alpha: 0.3)
                      : const Color(0xFFFCA5A5),
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    _batteryIgnored ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                    color: _batteryIgnored ? emeraldGreen : const Color(0xFFEF4444),
                    size: 26,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _batteryIgnored
                              ? 'Battery Mode: Unrestricted (Active)'
                              : 'Battery Mode: Optimized / Restricted',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: _batteryIgnored ? const Color(0xFF065F46) : const Color(0xFF991B1B),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          _batteryIgnored
                              ? 'Alarms are allowed to wake device and ring continuously even when app is closed.'
                              : 'ZTE SuperKiller and OEM cleaners can terminate alarms when swiped from recents.',
                          style: TextStyle(
                            fontSize: 11.5,
                            color: _batteryIgnored ? const Color(0xFF047857) : const Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // 1-Tap Allow Button
            if (!_batteryIgnored) ...[
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 13),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.flash_on_rounded, size: 20),
                label: const Text(
                  '1-Tap Allow Background (Unrestricted)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.bold),
                ),
                onPressed: () async {
                  await NotificationService.instance.requestIgnoreBatteryOptimization();
                  await Future.delayed(const Duration(milliseconds: 500));
                  await _checkPermissions();
                  mSetState(() {});
                },
              ),
              const SizedBox(height: 10),
            ],

            // Auto-Start Launcher Button
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                foregroundColor: const Color(0xFF171717),
                side: const BorderSide(color: Color(0xFFCBD5E1), width: 1.2),
                padding: const EdgeInsets.symmetric(vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
              icon: const Icon(Icons.settings_power_rounded, size: 18, color: emeraldGreen),
              label: const Text(
                'Open Phone Auto-Start Settings',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              onPressed: () => NotificationService.instance.openAutoStartSettings(),
            ),
            const SizedBox(height: 18),

            const Text(
              'Manufacturer Setup Instructions:',
              style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
            ),
            const SizedBox(height: 10),

            _buildBrandGuide(
              brand: 'ZTE (SuperKiller & PowerSave)',
              steps: 'Open Settings > Apps > Task Scheduler > Battery > Select "Unrestricted" and enable "Auto-start" and "Display pop-up windows". In Recent Apps, tap lock on Task Scheduler card.',
            ),
            _buildBrandGuide(
              brand: 'Samsung (OneUI)',
              steps: 'Settings > Apps > Task Scheduler > Battery > Select "Unrestricted".',
            ),
            _buildBrandGuide(
              brand: 'Xiaomi / Redmi / POCO (MIUI / HyperOS)',
              steps: 'Long-press app icon > App Info > Battery Saver > Select "No restrictions" and enable "Autostart".',
            ),
            _buildBrandGuide(
              brand: 'Oppo / Realme / OnePlus (ColorOS / OxygenOS)',
              steps: 'Settings > Battery > More battery settings > App battery management > Allow background activity.',
            ),
            _buildBrandGuide(
              brand: 'Vivo / iQOO (Funtouch OS)',
              steps: 'Settings > Battery > Background power consumption management > Set Task Scheduler to "Allow high background power consumption".',
            ),
            _buildBrandGuide(
              brand: 'Google Pixel / Motorola / Stock Android',
              steps: 'Settings > Apps > Task Scheduler > App battery usage > Select "Unrestricted".',
            ),
          ],
        );
      },
    );
  }

  Widget _buildBrandGuide({required String brand, required String steps}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(brand, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF171717))),
          const SizedBox(height: 4),
          Text(steps, style: const TextStyle(fontSize: 12, color: Color(0xFF64748B), height: 1.3)),
        ],
      ),
    );
  }

  // --- 6. MODAL: ABOUT TASK SCHEDULER ---
  void _openAboutModal() {
    _showModalPopup(
      context: context,
      title: 'About Task Scheduler',
      icon: Icons.info_outline_rounded,
      builder: (mCtx, mSetState) {
        return Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 10, offset: const Offset(0, 3)),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: Image.asset('asset/icon.png', fit: BoxFit.cover),
              ),
            ),
            const SizedBox(height: 12),
            const Text(
              'Task Scheduler',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Color(0xFF171717)),
            ),
            const Text('Version 1.0.0', style: TextStyle(fontSize: 12, color: Color(0xFF64748B))),
            const SizedBox(height: 16),
            const Divider(),
            _buildAboutRow('Engine', 'Exact Android AlarmManager & Darwin UserNotifications'),
            _buildAboutRow('Database', 'Local SQLite Engine (sqflite)'),
            _buildAboutRow('Audio Architecture', 'Android STREAM_ALARM with FLAG_INSISTENT'),
            _buildAboutRow('Active Ringtone', NotificationService.instance.currentRingtone.name),
            _buildAboutRow('Alert Interval', 'Every $_alertIntervalMinutes min (window: $_alertWindowMinutes min)'),
          ],
        );
      },
    );
  }

  Widget _buildAboutRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Color(0xFF475569))),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontSize: 12, color: Color(0xFF171717)),
            ),
          ),
        ],
      ),
    );
  }

  // --- MAIN SETTINGS CARD WIDGET ---
  Widget _buildSettingTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required String badgeText,
    required Color badgeColor,
    required VoidCallback onTap,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFFE5E7EB)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.02),
            blurRadius: 6,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: emeraldGreen.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: emeraldGreen, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF171717),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                            decoration: BoxDecoration(
                              color: badgeColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              badgeText,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: badgeColor,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: const TextStyle(fontSize: 12, color: Color(0xFF64748B)),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded, color: Color(0xFF94A3B8), size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final permissionsOk = _notificationsAllowed && _exactAlarmsAllowed;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        automaticallyImplyLeading: false,
        backgroundColor: darkBarColor,
        elevation: 0,
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: Image.asset(
                'asset/icon.png',
                width: 24,
                height: 24,
                fit: BoxFit.cover,
              ),
            ),
            const SizedBox(width: 10),
            const Text(
              'Settings & Alarm Debugger',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 18,
                color: Colors.white,
              ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh Status',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _checkPermissions,
          ),
        ],
      ),
      body: _isLoadingPermissions
          ? const Center(child: CircularProgressIndicator(color: emeraldGreen))
          : SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // App Branding Banner
                  Container(
                    margin: const EdgeInsets.only(bottom: 20),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF8FAFC),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFFE2E8F0)),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.08),
                                blurRadius: 6,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.asset('asset/icon.png', fit: BoxFit.cover),
                          ),
                        ),
                        const SizedBox(width: 14),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Task Scheduler',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF171717),
                                ),
                              ),
                              SizedBox(height: 2),
                              Text(
                                'Version 1.0.0 • Continuous Looping Alarm Engine',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Section 1: Alert Preferences
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Alert & Sound Preferences',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                    ),
                  ),

                  // 1. Alert Intervals Card
                  _buildSettingTile(
                    icon: Icons.timer_outlined,
                    title: 'Pre-Deadline Alert Intervals',
                    subtitle: 'Alert every $_alertIntervalMinutes min (window: $_alertWindowMinutes min)',
                    badgeText: '$_alertIntervalMinutes min',
                    badgeColor: emeraldGreen,
                    onTap: _openAlertIntervalModal,
                  ),

                  // 2. Alarm Ringtone Card
                  _buildSettingTile(
                    icon: Icons.notifications_active_rounded,
                    title: 'Alarm Ringtone & Sound',
                    subtitle: '${NotificationService.instance.currentRingtone.name} • Looping Alarm',
                    badgeText: NotificationService.instance.activeSoundId == 'custom' ? 'CUSTOM' : 'ACTIVE',
                    badgeColor: const Color(0xFF3B82F6),
                    onTap: _openRingtoneModal,
                  ),

                  // 3. System Permissions Card
                  _buildSettingTile(
                    icon: Icons.security_rounded,
                    title: 'System Permissions',
                    subtitle: (permissionsOk && _batteryIgnored) ? 'All active (Notifications, Exact Alarm, Background)' : 'Action required (Pending permissions)',
                    badgeText: (permissionsOk && _batteryIgnored) ? 'ACTIVE' : 'ACTION REQUIRED',
                    badgeColor: (permissionsOk && _batteryIgnored) ? emeraldGreen : const Color(0xFFEF4444),
                    onTap: _openPermissionsModal,
                  ),

                  const SizedBox(height: 14),

                  // Section 2: Testing & Reliability
                  const Padding(
                    padding: EdgeInsets.only(left: 4, bottom: 8),
                    child: Text(
                      'Testing & Reliability',
                      style: TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Color(0xFF94A3B8)),
                    ),
                  ),

                  // 4. Alarm Testing Station Card
                  _buildSettingTile(
                    icon: Icons.pest_control_rounded,
                    title: 'Alarm Testing Station',
                    subtitle: _isTestRunning
                        ? 'Test running: ${_formatCountdown(_secondsRemaining)} left'
                        : 'Test immediate alarm or background interval',
                    badgeText: _isTestRunning ? 'RUNNING' : 'TEST NOW',
                    badgeColor: _isTestRunning ? const Color(0xFFF59E0B) : emeraldGreen,
                    onTap: _openAlarmDebuggerModal,
                  ),

                  // 5. Battery & Background Card
                  _buildSettingTile(
                    icon: Icons.battery_charging_full_rounded,
                    title: 'Background & Battery Optimization',
                    subtitle: _batteryIgnored
                        ? 'Unrestricted background active for ZTE & Android'
                        : '1-tap allow so alarms wake phone when closed',
                    badgeText: _batteryIgnored ? 'UNRESTRICTED' : '1-TAP ALLOW',
                    badgeColor: _batteryIgnored ? emeraldGreen : const Color(0xFFF59E0B),
                    onTap: _openBatteryGuideModal,
                  ),

                  // 6. About Card
                  _buildSettingTile(
                    icon: Icons.info_outline_rounded,
                    title: 'About Task Scheduler',
                    subtitle: 'Engine details, database & notifications',
                    badgeText: 'v1.0.0',
                    badgeColor: const Color(0xFF171717),
                    onTap: _openAboutModal,
                  ),
                ],
              ),
            ),
    );
  }
}
