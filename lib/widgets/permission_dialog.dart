import 'package:flutter/material.dart';
import '../services/notification_service.dart';

class PermissionDialog extends StatefulWidget {
  final VoidCallback onPermissionsUpdated;

  const PermissionDialog({super.key, required this.onPermissionsUpdated});

  static Future<void> show(BuildContext context, {required VoidCallback onPermissionsUpdated}) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => PermissionDialog(onPermissionsUpdated: onPermissionsUpdated),
    );
  }

  @override
  State<PermissionDialog> createState() => _PermissionDialogState();
}

class _PermissionDialogState extends State<PermissionDialog> {
  static const Color emeraldGreen = Color(0xFF10B981);
  bool _isRequesting = false;

  bool _notifsGranted = false;
  bool _exactGranted = false;
  bool _batteryIgnored = false;

  @override
  void initState() {
    super.initState();
    _checkStatus();
  }

  Future<void> _checkStatus() async {
    final notifs = await NotificationService.instance.checkNotificationPermission();
    final exact = await NotificationService.instance.checkExactAlarmPermission();
    final battery = await NotificationService.instance.isBatteryOptimizationIgnored();
    if (mounted) {
      setState(() {
        _notifsGranted = notifs;
        _exactGranted = exact;
        _batteryIgnored = battery;
      });
    }
  }

  Future<void> _grantAllPermissions() async {
    setState(() {
      _isRequesting = true;
    });

    try {
      // 1. Request notifications permission (POST_NOTIFICATIONS)
      if (!_notifsGranted) {
        await NotificationService.instance.requestNotificationsPermission();
      }

      // 2. Request exact alarms permission (SCHEDULE_EXACT_ALARM)
      if (!_exactGranted) {
        await NotificationService.instance.requestExactAlarmsPermission();
      }

      // 3. 1-Tap Request ignore battery optimization (ACTION_REQUEST_IGNORE_BATTERY_OPTIMIZATIONS)
      if (!_batteryIgnored) {
        await NotificationService.instance.requestIgnoreBatteryOptimization();
      }

      await Future.delayed(const Duration(milliseconds: 400));
      await _checkStatus();

      widget.onPermissionsUpdated();

      if (mounted) {
        if (_notifsGranted && _exactGranted) {
          Navigator.of(context).pop();
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('All permissions granted! Alarms are fully active.'),
                  ),
                ],
              ),
              backgroundColor: emeraldGreen,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Row(
                children: [
                  Icon(Icons.warning_amber_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text('Some permissions are still pending. Tap allow so alarms can ring.'),
                  ),
                ],
              ),
              backgroundColor: const Color(0xFFEF4444),
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
        }
      }
    } finally {
      if (mounted) {
        setState(() {
          _isRequesting = false;
        });
      }
    }
  }

  Widget _buildPermissionItem({
    required IconData icon,
    required String title,
    required String desc,
    required bool isGranted,
    VoidCallback? onTapAction,
    String? actionLabel,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isGranted
                  ? emeraldGreen.withValues(alpha: 0.12)
                  : const Color(0xFFEF4444).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              icon,
              size: 20,
              color: isGranted ? emeraldGreen : const Color(0xFFEF4444),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        title,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.bold,
                          color: Color(0xFF171717),
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(
                        color: isGranted
                            ? emeraldGreen.withValues(alpha: 0.12)
                            : const Color(0xFFEF4444).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            isGranted ? Icons.check_rounded : Icons.priority_high_rounded,
                            size: 11,
                            color: isGranted ? emeraldGreen : const Color(0xFFEF4444),
                          ),
                          const SizedBox(width: 2),
                          Text(
                            isGranted ? 'ALLOWED' : 'REQUIRED',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                              color: isGranted ? emeraldGreen : const Color(0xFFEF4444),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  desc,
                  style: const TextStyle(
                    fontSize: 11.5,
                    color: Color(0xFF64748B),
                    height: 1.3,
                  ),
                ),
                if (!isGranted && onTapAction != null && actionLabel != null) ...[
                  const SizedBox(height: 4),
                  InkWell(
                    onTap: onTapAction,
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 2),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            actionLabel,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: emeraldGreen,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(Icons.arrow_forward_rounded, size: 12, color: emeraldGreen),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final allGranted = _notifsGranted && _exactGranted && _batteryIgnored;

    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.08),
                  blurRadius: 6,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Image.asset('asset/icon.png', fit: BoxFit.cover),
            ),
          ),
          const SizedBox(width: 12),
          const Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Task Scheduler',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF64748B),
                  ),
                ),
                Text(
                  'Permissions Required',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFF171717),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'To ensure continuous alarms ring reliably with sound and vibration before task deadlines, please allow the following permissions:',
              style: TextStyle(fontSize: 12.5, color: Color(0xFF475569), height: 1.4),
            ),
            const SizedBox(height: 12),
            _buildPermissionItem(
              icon: Icons.notifications_active_rounded,
              title: 'Notification Alerts',
              desc: 'Required to show heads-up alarm alerts and continuous notification screens.',
              isGranted: _notifsGranted,
            ),
            const Divider(height: 8, color: Color(0xFFF1F5F9)),
            _buildPermissionItem(
              icon: Icons.alarm_rounded,
              title: 'Exact Alarms',
              desc: 'Required to ring alerts at the exact second, even when phone is locked or idle.',
              isGranted: _exactGranted,
            ),
            const Divider(height: 8, color: Color(0xFFF1F5F9)),
            _buildPermissionItem(
              icon: Icons.battery_charging_full_rounded,
              title: '1-Tap Background (No Restrictions)',
              desc: 'Allows alarms to ring when app is closed. Tapping grants Unrestricted battery mode.',
              isGranted: _batteryIgnored,
              onTapAction: () async {
                await NotificationService.instance.requestIgnoreBatteryOptimization();
                await Future.delayed(const Duration(milliseconds: 500));
                await _checkStatus();
              },
              actionLabel: '1-Tap Allow Background',
            ),
            const SizedBox(height: 10),
            // OEM / ZTE Auto-Start Quick Link
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF8FAFC),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: const Color(0xFFE2E8F0)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.info_outline_rounded, size: 14, color: emeraldGreen),
                      SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'For ZTE, Xiaomi, and Samsung phones:',
                          style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Color(0xFF334155)),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Enable "Auto-start" in phone settings so ZTE SuperKiller does not kill alarms when swiped away.',
                    style: TextStyle(fontSize: 10.5, color: Color(0xFF64748B)),
                  ),
                  const SizedBox(height: 6),
                  InkWell(
                    onTap: () => NotificationService.instance.openAutoStartSettings(),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: emeraldGreen.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(color: emeraldGreen.withValues(alpha: 0.3)),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.open_in_new_rounded, size: 12, color: emeraldGreen),
                          SizedBox(width: 4),
                          Text(
                            'Open Auto-Start Settings',
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.bold,
                              color: emeraldGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Later', style: TextStyle(color: Color(0xFF64748B))),
        ),
        ElevatedButton(
          style: ElevatedButton.styleFrom(
            backgroundColor: emeraldGreen,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          onPressed: _isRequesting ? null : _grantAllPermissions,
          child: _isRequesting
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                )
              : Text(allGranted ? 'Done' : 'Allow All Permissions'),
        ),
      ],
    );
  }
}
