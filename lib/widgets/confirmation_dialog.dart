import 'package:flutter/material.dart';

class ConfirmationDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final String cancelLabel;
  final Color confirmColor;
  final IconData icon;

  const ConfirmationDialog({
    super.key,
    required this.title,
    required this.message,
    this.confirmLabel = 'Confirm',
    this.cancelLabel = 'Cancel',
    this.confirmColor = const Color(0xFF10B981),
    this.icon = Icons.help_outline_rounded,
  });

  static Future<bool> show(
    BuildContext context, {
    required String title,
    required String message,
    String confirmLabel = 'Confirm',
    String cancelLabel = 'Cancel',
    Color confirmColor = const Color(0xFF10B981),
    IconData icon = Icons.help_outline_rounded,
  }) async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => ConfirmationDialog(
        title: title,
        message: message,
        confirmLabel: confirmLabel,
        cancelLabel: cancelLabel,
        confirmColor: confirmColor,
        icon: icon,
      ),
    );
    return result ?? false;
  }

  /// Confirm marking task as completed
  static Future<bool> confirmComplete(BuildContext context, {required String taskTitle}) {
    return show(
      context,
      title: 'Complete Task?',
      message: 'Are you sure you want to mark "$taskTitle" as completed? This will silence all upcoming pre-deadline alarms.',
      confirmLabel: 'Mark Completed',
      confirmColor: const Color(0xFF10B981),
      icon: Icons.check_circle_rounded,
    );
  }

  /// Confirm cancelling a task
  static Future<bool> confirmCancel(BuildContext context, {required String taskTitle}) {
    return show(
      context,
      title: 'Cancel Task?',
      message: 'Are you sure you want to cancel "$taskTitle"? All scheduled reminders and alerts will be cancelled.',
      confirmLabel: 'Yes, Cancel Task',
      confirmColor: const Color(0xFFF59E0B),
      icon: Icons.highlight_off_rounded,
    );
  }

  /// Confirm deleting a task permanently
  static Future<bool> confirmDelete(BuildContext context, {required String taskTitle}) {
    return show(
      context,
      title: 'Delete Task Permanently?',
      message: 'Are you sure you want to permanently delete "$taskTitle"? This action cannot be undone.',
      confirmLabel: 'Delete Permanently',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.delete_forever_rounded,
    );
  }

  /// Confirm stopping all ringing alarms
  static Future<bool> confirmStopAlarms(BuildContext context) {
    return show(
      context,
      title: 'Stop All Ringing Alarms?',
      message: 'Are you sure you want to silence and stop all active ringing alarms right now?',
      confirmLabel: 'Stop All Alarms',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.alarm_off_rounded,
    );
  }

  /// Confirm creating a new scheduled task
  static Future<bool> confirmCreateTask(
    BuildContext context, {
    required String taskTitle,
    required String scheduledTimeFormatted,
  }) {
    return show(
      context,
      title: 'Schedule New Task?',
      message: 'Schedule "$taskTitle" for $scheduledTimeFormatted?\nAll 4 pre-deadline alerts and the deadline alarm will be activated.',
      confirmLabel: 'Confirm & Schedule',
      confirmColor: const Color(0xFF10B981),
      icon: Icons.alarm_add_rounded,
    );
  }

  /// Confirm saving changes to a task
  static Future<bool> confirmSaveTask(BuildContext context, {required String taskTitle}) {
    return show(
      context,
      title: 'Save Task Changes?',
      message: 'Are you sure you want to update "$taskTitle"? All 4 pre-deadline alerts and deadline arrival alarms will be recalculated and scheduled.',
      confirmLabel: 'Update & Schedule',
      confirmColor: const Color(0xFF10B981),
      icon: Icons.save_rounded,
    );
  }

  /// Confirm discarding changes
  static Future<bool> confirmDiscard(BuildContext context) {
    return show(
      context,
      title: 'Discard Changes?',
      message: 'You have unsaved changes. Are you sure you want to discard them and close?',
      confirmLabel: 'Discard',
      cancelLabel: 'Keep Editing',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.restore_from_trash_rounded,
    );
  }

  /// Confirm stopping test alarm in settings
  static Future<bool> confirmStopTestAlarm(BuildContext context) {
    return show(
      context,
      title: 'Stop Alarm Test?',
      message: 'Are you sure you want to stop the active alarm test and cancel the countdown?',
      confirmLabel: 'Stop Test',
      confirmColor: const Color(0xFFEF4444),
      icon: Icons.stop_circle_outlined,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: confirmColor.withValues(alpha: 0.14),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: confirmColor, size: 22),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 17,
                fontWeight: FontWeight.bold,
                color: Color(0xFF171717),
              ),
            ),
          ),
        ],
      ),
      content: Text(
        message,
        style: const TextStyle(
          fontSize: 13.5,
          color: Color(0xFF475569),
          height: 1.4,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: Text(
            cancelLabel,
            style: const TextStyle(
              color: Color(0xFF64748B),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
        FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: confirmColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          onPressed: () => Navigator.of(context).pop(true),
          child: Text(
            confirmLabel,
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
        ),
      ],
    );
  }
}
