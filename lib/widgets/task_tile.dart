import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_task.dart';
import '../services/notification_service.dart';

class TaskTile extends StatefulWidget {
  final ScheduleTask task;
  final VoidCallback onComplete;
  final VoidCallback onCancel;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  static const Color emeraldGreen = Color(0xFF10B981);

  const TaskTile({
    super.key,
    required this.task,
    required this.onComplete,
    required this.onCancel,
    this.onEdit,
    this.onDelete,
  });

  @override
  State<TaskTile> createState() => _TaskTileState();
}

class _TaskTileState extends State<TaskTile> {
  Color _getStatusColor() {
    switch (widget.task.status.toLowerCase()) {
      case 'completed':
        return TaskTile.emeraldGreen; // Emerald green
      case 'cancelled':
        return const Color(0xFFEF4444); // Crimson red
      case 'pending':
      default:
        return const Color(0xFFF59E0B); // Amber orange
    }
  }

  IconData _getStatusIcon() {
    switch (widget.task.status.toLowerCase()) {
      case 'completed':
        return Icons.check_circle_rounded;
      case 'cancelled':
        return Icons.cancel_rounded;
      case 'pending':
      default:
        return Icons.schedule_rounded;
    }
  }

  String _formatDurationRemaining(Duration difference) {
    if (difference.isNegative) return 'due now';
    if (difference.inHours > 0) {
      final hours = difference.inHours;
      final minutes = difference.inMinutes % 60;
      return 'in ${hours}h ${minutes}m';
    } else if (difference.inMinutes > 0) {
      return 'in ${difference.inMinutes}m';
    } else {
      return 'in < 1 min';
    }
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final statusColor = _getStatusColor();
    final now = DateTime.now();
    final isPast = task.scheduledTime.isBefore(now);
    final isPending = task.isPending;

    final activeInterval = NotificationService.instance.alertIntervalMinutes;
    final allOffsets = NotificationService.instance.getAllOffsetsForTask();

    // Calculate the next upcoming pre-deadline alert
    DateTime? nextAlertTime;
    int? nextOffsetMinutes;

    if (isPending) {
      for (final offset in allOffsets) {
        final alertTime = task.scheduledTime.subtract(Duration(minutes: offset));
        if (alertTime.isAfter(now)) {
          nextAlertTime = alertTime;
          nextOffsetMinutes = offset;
          break;
        }
      }
      if (nextAlertTime == null && task.scheduledTime.isAfter(now)) {
        nextAlertTime = task.scheduledTime;
        nextOffsetMinutes = 0;
      }
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 3),
          ),
        ],
        border: Border.all(
          color: isPending
              ? statusColor.withValues(alpha: 0.35)
              : const Color(0xFFE5E7EB),
          width: 1.2,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(15.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Top Row: Status Badge & Action Buttons
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Status Badge
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: statusColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: statusColor.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getStatusIcon(),
                        size: 13,
                        color: statusColor,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        task.status.toUpperCase(),
                        style: TextStyle(
                          color: statusColor,
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.5,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),

                // Action buttons for tasks
                if (widget.onEdit != null) ...[
                  // Edit Task Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onEdit,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: TaskTile.emeraldGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.edit_note_rounded,
                          color: TaskTile.emeraldGreen,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                ],

                // Action buttons for pending tasks
                if (isPending) ...[
                  // Mark as Completed Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onComplete,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: TaskTile.emeraldGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.check_circle_outline_rounded,
                          color: TaskTile.emeraldGreen,
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  // Mark as Cancelled Button
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onCancel,
                      child: Container(
                        padding: const EdgeInsets.all(6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFEF4444).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          Icons.highlight_off_rounded,
                          color: Color(0xFFEF4444),
                          size: 19,
                        ),
                      ),
                    ),
                  ),
                ],

                // Delete option for completed/cancelled tasks
                if (!isPending && widget.onDelete != null) ...[
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                    color: Colors.grey,
                    visualDensity: VisualDensity.compact,
                    onPressed: widget.onDelete,
                  ),
                ],
              ],
            ),
            const SizedBox(height: 10),

            // Task Title
            Text(
              task.title,
              style: TextStyle(
                fontSize: 16.5,
                fontWeight: FontWeight.w600,
                decoration: task.isCompleted
                    ? TextDecoration.lineThrough
                    : TextDecoration.none,
                color: task.isCompleted
                    ? const Color(0xFF94A3B8)
                    : const Color(0xFF171717),
              ),
            ),
            const SizedBox(height: 6),

            // Scheduled Date & Time
            Row(
              children: [
                const Icon(
                  Icons.event_note_rounded,
                  size: 15,
                  color: Color(0xFF64748B),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    DateFormat('EEE, MMM d, yyyy • h:mm a').format(task.scheduledTime),
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w500,
                      color: Color(0xFF475569),
                    ),
                  ),
                ),
                if (isPast && isPending) ...[
                  const SizedBox(width: 6),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.red.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OVERDUE',
                      style: TextStyle(
                        fontSize: 9.5,
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ],
            ),

            // Next Alert Display Section (Wrapped safely to prevent overflow)
            if (isPending) ...[
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 8),
                decoration: BoxDecoration(
                  color: nextAlertTime != null
                      ? TaskTile.emeraldGreen.withValues(alpha: 0.08)
                      : (isPast
                          ? Colors.red.withValues(alpha: 0.08)
                          : TaskTile.emeraldGreen.withValues(alpha: 0.08)),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: nextAlertTime != null
                        ? TaskTile.emeraldGreen.withValues(alpha: 0.3)
                        : Colors.transparent,
                  ),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 2.0),
                      child: Icon(
                        nextAlertTime != null
                            ? Icons.notifications_active_rounded
                            : (isPast ? Icons.alarm_off_rounded : Icons.alarm_rounded),
                        size: 17,
                        color: nextAlertTime != null
                            ? TaskTile.emeraldGreen
                            : (isPast ? Colors.redAccent : TaskTile.emeraldGreen),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (nextAlertTime != null) ...[
                            // Wrap prevents any overflow on small screens
                            Wrap(
                              crossAxisAlignment: WrapCrossAlignment.center,
                              spacing: 6,
                              runSpacing: 4,
                              children: [
                                const Text(
                                  'Next Alert:',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                    color: TaskTile.emeraldGreen,
                                  ),
                                ),
                                Text(
                                  DateFormat('h:mm a').format(nextAlertTime),
                                  style: const TextStyle(
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w800,
                                    color: Color(0xFF171717),
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: TaskTile.emeraldGreen.withValues(alpha: 0.15),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      if (nextOffsetMinutes == 0) ...[
                                        const Icon(Icons.flag_rounded, size: 10, color: TaskTile.emeraldGreen),
                                        const SizedBox(width: 2),
                                      ],
                                      Text(
                                        nextOffsetMinutes == 0
                                            ? 'Deadline alert'
                                            : '-${nextOffsetMinutes}m alert',
                                        style: const TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: TaskTile.emeraldGreen,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 6, vertical: 1),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF171717).withValues(alpha: 0.08),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    'every ${activeInterval}m',
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF374151),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Continuous alarm ${now.isBefore(nextAlertTime) ? _formatDurationRemaining(nextAlertTime.difference(now)) : "momentarily"}',
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF64748B),
                              ),
                            ),
                          ] else if (!isPast) ...[
                            Text(
                              'Pre-deadline alerts finished • Final deadline at ${DateFormat.jm().format(task.scheduledTime)}',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: TaskTile.emeraldGreen,
                              ),
                            ),
                          ] else ...[
                            const Text(
                              'All scheduled alerts have passed.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w500,
                                color: Colors.redAccent,
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
