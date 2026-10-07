import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_task.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import 'confirmation_dialog.dart';

class AddTaskSheet extends StatefulWidget {
  final VoidCallback onTaskAdded;

  const AddTaskSheet({super.key, required this.onTaskAdded});

  static Future<void> show(BuildContext context, {required VoidCallback onTaskAdded}) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => AddTaskSheet(onTaskAdded: onTaskAdded),
    );
  }

  @override
  State<AddTaskSheet> createState() => _AddTaskSheetState();
}

class _AddTaskSheetState extends State<AddTaskSheet> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  TimeOfDay _selectedTime = TimeOfDay.fromDateTime(
    DateTime.now().add(const Duration(hours: 2)),
  );

  bool _isSaving = false;
  String? _timeErrorMessage;

  @override
  void dispose() {
    _titleController.dispose();
    super.dispose();
  }

  DateTime get _combinedDateTime {
    return DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );
  }

  bool get _isPastSchedule {
    return _combinedDateTime.isBefore(DateTime.now());
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate.isBefore(now) ? now : _selectedDate,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF10B981),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedDate = picked;
        _validateTime();
      });
    }
  }

  Future<void> _pickTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _selectedTime,
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: const Color(0xFF10B981),
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _selectedTime = picked;
        _validateTime();
      });
    }
  }

  void _validateTime() {
    if (_isPastSchedule) {
      _timeErrorMessage = 'Scheduled time cannot be in the past.';
    } else {
      _timeErrorMessage = null;
    }
  }

  Future<void> _saveTask() async {
    if (!_formKey.currentState!.validate()) return;

    final targetDateTime = _combinedDateTime;
    final now = DateTime.now();

    if (targetDateTime.isBefore(now)) {
      setState(() {
        _timeErrorMessage = 'Scheduled time cannot be in the past.';
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select a future date and time for the task.'),
          backgroundColor: Color(0xFFEF4444),
        ),
      );
      return;
    }

    final confirmed = await ConfirmationDialog.confirmCreateTask(
      context,
      taskTitle: _titleController.text.trim(),
      scheduledTimeFormatted: DateFormat('MMM d, y • h:mm a').format(targetDateTime),
    );
    if (!confirmed) return;

    setState(() {
      _isSaving = true;
      _timeErrorMessage = null;
    });

    try {
      final task = ScheduleTask(
        title: _titleController.text.trim(),
        scheduledTime: targetDateTime,
        status: TaskStatus.pending.value,
      );

      // 1. Insert into SQLite and retrieve generated ID
      final insertedId = await DBService.instance.insertTask(task);
      final persistedTask = task.copyWith(id: insertedId);

      // 2. Schedule the 4 exact pre-deadline notifications
      await NotificationService.instance.scheduleTaskAlerts(persistedTask);

      if (mounted) {
        widget.onTaskAdded();
        NotificationService.instance.notifySettingsChanged();
        Navigator.of(context).pop();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Task scheduled! Interval alarms registered.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFF10B981),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to schedule task: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  Widget _buildQuickTag(IconData icon, String label, String prefix) {
    return InkWell(
      onTap: () {
        if (!_titleController.text.startsWith(prefix)) {
          _titleController.text = '$prefix${_titleController.text}';
          _titleController.selection = TextSelection.fromPosition(
            TextPosition(offset: _titleController.text.length),
          );
        }
      },
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
        decoration: BoxDecoration(
          color: const Color(0xFF10B981).withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: const Color(0xFF10B981).withValues(alpha: 0.25)),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 12, color: const Color(0xFF10B981)),
            const SizedBox(width: 3),
            Text(
              label,
              style: const TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: Color(0xFF10B981),
              ),
            ),
          ],
        ),
      ),
    );
  }

  List<Widget> _buildIntervalPreviewList(DateTime scheduled, DateTime now, bool isDark) {
    final activeInterval = NotificationService.instance.alertIntervalMinutes;
    final allOffsets = NotificationService.instance.getAllOffsetsForTask();
    final List<Widget> items = [];

    final displayed = allOffsets.length <= 6
        ? allOffsets
        : allOffsets.take(4).toList();

    for (int i = 0; i < displayed.length; i++) {
      final offset = displayed[i];
      final alertTime = scheduled.subtract(Duration(minutes: offset));
      final isAlreadyPast = alertTime.isBefore(now);

      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            children: [
              Icon(
                isAlreadyPast ? Icons.cancel_outlined : Icons.alarm_on_rounded,
                size: 14,
                color: isAlreadyPast ? Colors.grey : const Color(0xFF10B981),
              ),
              const SizedBox(width: 6),
              Text(
                '${offset}m before:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isAlreadyPast
                      ? Colors.grey
                      : (isDark ? Colors.white70 : const Color(0xFF334155)),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                DateFormat('h:mm a').format(alertTime),
                style: TextStyle(
                  fontSize: 12,
                  color: isAlreadyPast
                      ? Colors.grey
                      : (isDark ? Colors.white : const Color(0xFF0F172A)),
                  decoration: isAlreadyPast
                      ? TextDecoration.lineThrough
                      : TextDecoration.none,
                ),
              ),
              const Spacer(),
              Text(
                isAlreadyPast ? 'Skipped (passed)' : 'Will alert',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w500,
                  color: isAlreadyPast
                      ? const Color(0xFFEF4444)
                      : const Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (allOffsets.length > 6) {
      items.add(
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 3.0),
          child: Row(
            children: [
              const Icon(Icons.flash_on_rounded, size: 14, color: Color(0xFF10B981)),
              const SizedBox(width: 6),
              Text(
                '+${allOffsets.length - displayed.length} more alarms (every ${activeInterval}m down to deadline)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF10B981),
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Due time alarm
    final dueIsPast = scheduled.isBefore(now);
    items.add(
      Padding(
        padding: const EdgeInsets.symmetric(vertical: 3.0),
        child: Row(
          children: [
            Icon(
              Icons.flag_rounded,
              size: 14,
              color: dueIsPast ? Colors.grey : const Color(0xFFEF4444),
            ),
            const SizedBox(width: 6),
            Text(
              'Due time (0m):',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dueIsPast
                    ? Colors.grey
                    : (isDark ? Colors.white70 : const Color(0xFF1E293B)),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              DateFormat('h:mm a').format(scheduled),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: dueIsPast
                    ? Colors.grey
                    : (isDark ? Colors.white : const Color(0xFF0F172A)),
                decoration: dueIsPast ? TextDecoration.lineThrough : TextDecoration.none,
              ),
            ),
            const Spacer(),
            const Text(
              'Final Deadline Alarm',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w600,
                color: Color(0xFFEF4444),
              ),
            ),
          ],
        ),
      ),
    );

    return items;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final scheduled = _combinedDateTime;
    final now = DateTime.now();
    final hasContent = _titleController.text.trim().isNotEmpty;

    return PopScope(
      canPop: !hasContent,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final discard = await ConfirmationDialog.confirmDiscard(context);
        if (discard && context.mounted) {
          Navigator.of(context).pop();
        }
      },
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Container(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          decoration: BoxDecoration(
            color: isDark ? const Color(0xFF0F172A) : Colors.white,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 20,
                offset: Offset(0, -4),
              ),
            ],
          ),
          child: SingleChildScrollView(
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top handle
                  Center(
                    child: Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: isDark ? Colors.white24 : Colors.black12,
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  // Header
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFF10B981).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          Icons.add_task_rounded,
                          color: Color(0xFF10B981),
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Schedule New Task',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.bold,
                                color: isDark ? Colors.white : const Color(0xFF0F172A),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Exact alerts at 60m, 45m, 30m, and 15m before',
                              style: TextStyle(
                                fontSize: 12,
                                color: isDark ? Colors.white60 : const Color(0xFF64748B),
                              ),
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: Icon(
                          Icons.close_rounded,
                          color: isDark ? Colors.white60 : const Color(0xFF64748B),
                        ),
                        tooltip: 'Close',
                        onPressed: () async {
                          if (hasContent) {
                            final discard = await ConfirmationDialog.confirmDiscard(context);
                            if (discard && context.mounted) {
                              Navigator.of(context).pop();
                            }
                          } else {
                            Navigator.of(context).pop();
                          }
                        },
                      ),
                    ],
                  ),
                const SizedBox(height: 20),

                // Task Title Field
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Task Title',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: isDark ? Colors.white70 : const Color(0xFF475569),
                      ),
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _buildQuickTag(Icons.groups_rounded, 'Meeting', 'Meeting: '),
                        const SizedBox(width: 4),
                        _buildQuickTag(Icons.call_rounded, 'Call', 'Call: '),
                        const SizedBox(width: 4),
                        _buildQuickTag(Icons.sync_rounded, 'Sync', 'Sync: '),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _titleController,
                  autofocus: true,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: InputDecoration(
                    hintText: 'e.g. Project Review Presentation',
                    filled: true,
                    fillColor: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF8FAFC),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: BorderSide(
                        color: isDark ? Colors.white12 : const Color(0xFFE2E8F0),
                      ),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                      borderSide: const BorderSide(
                        color: Color(0xFF10B981),
                        width: 1.8,
                      ),
                    ),
                    prefixIcon: const Icon(
                      Icons.title_rounded,
                      color: Color(0xFF10B981),
                    ),
                  ),
                  validator: (value) {
                    if (value == null || value.trim().isEmpty) {
                      return 'Please enter a task title.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 18),

                // Date and Time Row
                Text(
                  'Scheduled Due Date & Time',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : const Color(0xFF475569),
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    // Date selector
                    Expanded(
                      child: InkWell(
                        onTap: _pickDate,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.calendar_today_rounded,
                                size: 18,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  DateFormat('MMM d, yyyy').format(_selectedDate),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Time selector
                    Expanded(
                      child: InkWell(
                        onTap: _pickTime,
                        borderRadius: BorderRadius.circular(14),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 14,
                            vertical: 14,
                          ),
                          decoration: BoxDecoration(
                            color: isDark
                                ? const Color(0xFF1E293B)
                                : const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: isDark
                                  ? Colors.white12
                                  : const Color(0xFFE2E8F0),
                            ),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.access_time_rounded,
                                size: 18,
                                color: Color(0xFF10B981),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _selectedTime.format(context),
                                  style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: isDark
                                        ? Colors.white
                                        : const Color(0xFF0F172A),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                // Error Message if time is past
                if (_timeErrorMessage != null) ...[
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      const Icon(Icons.error_outline_rounded,
                          size: 15, color: Color(0xFFEF4444)),
                      const SizedBox(width: 6),
                      Text(
                        _timeErrorMessage!,
                        style: const TextStyle(
                          color: Color(0xFFEF4444),
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ],
                const SizedBox(height: 18),

                // Scheduled Notification Timeline Preview
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: isDark
                        ? const Color(0xFF1E293B)
                        : const Color(0xFFF1F5F9),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          const Icon(
                            Icons.notifications_active_rounded,
                            size: 16,
                            color: Color(0xFF6366F1),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Pre-Deadline Alert Schedule (${NotificationService.instance.alertIntervalMinutes}m interval)',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: isDark
                                  ? Colors.white
                                  : const Color(0xFF1E293B),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      ..._buildIntervalPreviewList(scheduled, now, isDark),
                    ],
                  ),
                ),
                const SizedBox(height: 22),

                // Save Task Button
                ElevatedButton(
                  onPressed: _isSaving ? null : _saveTask,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF10B981),
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                  child: _isSaving
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(Icons.alarm_add_rounded, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Save & Schedule Alerts',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
