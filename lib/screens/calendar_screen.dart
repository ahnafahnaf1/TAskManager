import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_task.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/task_tile.dart';

enum CalendarFilter {
  all('All Pending', Icons.list_alt_rounded),
  meetings('Meetings Only', Icons.groups_rounded);

  final String label;
  final IconData icon;
  const CalendarFilter(this.label, this.icon);
}

class CalendarScreen extends StatefulWidget {
  final VoidCallback onTasksChanged;

  const CalendarScreen({super.key, required this.onTasksChanged});

  /// Determines if a task is a meeting based on title keywords
  static bool isMeetingTask(ScheduleTask task) {
    final title = task.title.toLowerCase();
    const keywords = [
      'meet',        // meeting, meet, meets
      'call',        // call, calls, zoom call, client call
      'sync',        // sync, 1:1 sync, weekly sync
      'interview',   // interview, candidate interview
      'discuss',     // discussion, discuss
      'review',      // code review, project review
      'standup',     // daily standup
      'appointment', // doctor appointment
      'session',     // coaching session, training session
      'huddle',      // team huddle
      'conference',  // conference
      'webinar',     // webinar
      '1:1',         // 1:1
      'one on one',  // one on one
    ];
    return keywords.any((k) => title.contains(k));
  }

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month, 1);
  DateTime _selectedDate = DateTime(DateTime.now().year, DateTime.now().month, DateTime.now().day);
  List<ScheduleTask> _pendingTasks = [];
  bool _isLoading = true;
  CalendarFilter _currentFilter = CalendarFilter.all;
  bool _hasMissingPermissions = false;

  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color darkBarColor = Color(0xFF171717);

  @override
  void initState() {
    super.initState();
    _loadTasks();
    NotificationService.instance.settingsVersionNotifier.addListener(_onSettingsOrTasksChanged);
    _checkPermissions();
  }

  void _onSettingsOrTasksChanged() {
    if (mounted) {
      _loadTasks();
    }
  }

  @override
  void dispose() {
    NotificationService.instance.settingsVersionNotifier.removeListener(_onSettingsOrTasksChanged);
    super.dispose();
  }

  Future<void> _checkPermissions() async {
    final notifs = await NotificationService.instance.checkNotificationPermission();
    final exact = await NotificationService.instance.checkExactAlarmPermission();
    if (mounted) {
      setState(() {
        _hasMissingPermissions = !notifs || !exact;
      });
    }
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    await _checkPermissions();

    try {
      final all = await DBService.instance.getAllTasks();
      if (mounted) {
        setState(() {
          _pendingTasks = all.where((t) => t.isPending).toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  static bool isMeetingTask(ScheduleTask task) => CalendarScreen.isMeetingTask(task);

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  List<ScheduleTask> _tasksForDate(DateTime date) {
    final dayTasks = _pendingTasks.where((task) => _isSameDay(task.scheduledTime, date)).toList();
    if (_currentFilter == CalendarFilter.meetings) {
      return dayTasks.where(isMeetingTask).toList();
    }
    return dayTasks;
  }

  int _meetingCountForMonth() {
    return _pendingTasks.where((task) {
      return task.scheduledTime.year == _focusedMonth.year &&
          task.scheduledTime.month == _focusedMonth.month &&
          isMeetingTask(task);
    }).length;
  }

  int _allCountForMonth() {
    return _pendingTasks.where((task) {
      return task.scheduledTime.year == _focusedMonth.year &&
          task.scheduledTime.month == _focusedMonth.month;
    }).length;
  }

  void _changeMonth(int delta) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + delta, 1);
    });
  }

  void _changeYear(int delta) {
    setState(() {
      final newYear = _focusedMonth.year + delta;
      _focusedMonth = DateTime(newYear, _focusedMonth.month, 1);
      final maxDays = DateUtils.getDaysInMonth(newYear, _selectedDate.month);
      _selectedDate = DateTime(
        newYear,
        _selectedDate.month,
        _selectedDate.day > maxDays ? maxDays : _selectedDate.day,
      );
    });
  }

  Future<void> _pickYear() async {
    final currentYear = _focusedMonth.year;
    final now = DateTime.now();
    // Allow picking from (now.year - 5) to (now.year + 15)
    final years = List.generate(21, (i) => now.year - 5 + i);

    final pickedYear = await showDialog<int>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Row(
            children: [
              Icon(Icons.calendar_today_rounded, color: emeraldGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Select Year',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFF171717),
                ),
              ),
            ],
          ),
          content: SizedBox(
            width: 300,
            height: 290,
            child: GridView.builder(
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                childAspectRatio: 1.8,
                crossAxisSpacing: 8,
                mainAxisSpacing: 8,
              ),
              itemCount: years.length,
              itemBuilder: (ctx, i) {
                final year = years[i];
                final isSelected = year == currentYear;
                final isThisYear = year == now.year;

                return InkWell(
                  onTap: () => Navigator.of(ctx).pop(year),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: isSelected
                          ? emeraldGreen
                          : (isThisYear
                              ? emeraldGreen.withValues(alpha: 0.12)
                              : const Color(0xFFF8FAFC)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected
                            ? emeraldGreen
                            : (isThisYear ? emeraldGreen : const Color(0xFFE2E8F0)),
                        width: isSelected || isThisYear ? 1.6 : 1.0,
                      ),
                    ),
                    child: Text(
                      year.toString(),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: isSelected || isThisYear ? FontWeight.bold : FontWeight.w600,
                        color: isSelected
                            ? Colors.white
                            : (isThisYear ? emeraldGreen : const Color(0xFF171717)),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Cancel', style: TextStyle(color: Color(0xFF64748B))),
            ),
          ],
        );
      },
    );

    if (pickedYear != null && pickedYear != _focusedMonth.year) {
      setState(() {
        _focusedMonth = DateTime(pickedYear, _focusedMonth.month, 1);
        final maxDays = DateUtils.getDaysInMonth(pickedYear, _selectedDate.month);
        _selectedDate = DateTime(
          pickedYear,
          _selectedDate.month,
          _selectedDate.day > maxDays ? maxDays : _selectedDate.day,
        );
      });
    }
  }

  Future<void> _markCompleted(ScheduleTask task) async {
    if (task.id == null) return;

    final confirmed = await ConfirmationDialog.confirmComplete(
      context,
      taskTitle: task.title,
    );
    if (!confirmed) return;

    await DBService.instance.updateTaskStatus(task.id!, TaskStatus.completed.value);
    await NotificationService.instance.cancelTaskAlerts(task.id!);
    widget.onTasksChanged();
    await _loadTasks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Marked "${task.title}" as Completed.'),
          backgroundColor: emeraldGreen,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _markCancelled(ScheduleTask task) async {
    if (task.id == null) return;

    final confirmed = await ConfirmationDialog.confirmCancel(
      context,
      taskTitle: task.title,
    );
    if (!confirmed) return;

    await DBService.instance.updateTaskStatus(task.id!, TaskStatus.cancelled.value);
    await NotificationService.instance.cancelTaskAlerts(task.id!);
    widget.onTasksChanged();
    await _loadTasks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Cancelled "${task.title}". Alerts stopped.'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  Future<void> _editTask(ScheduleTask task) async {
    await EditTaskSheet.show(
      context,
      task: task,
      onTaskUpdated: () async {
        widget.onTasksChanged();
        await _loadTasks();
      },
    );
  }

  Future<void> _deleteTask(ScheduleTask task) async {
    if (task.id == null) return;

    final confirmed = await ConfirmationDialog.confirmDelete(
      context,
      taskTitle: task.title,
    );
    if (!confirmed) return;

    await NotificationService.instance.cancelTaskAlerts(task.id!);
    await DBService.instance.deleteTask(task.id!);
    widget.onTasksChanged();
    await _loadTasks();

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deleted "${task.title}".'),
          backgroundColor: const Color(0xFFEF4444),
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final selectedDayTasks = _tasksForDate(_selectedDate);

    // Days in current focused month
    final daysInMonth = DateUtils.getDaysInMonth(_focusedMonth.year, _focusedMonth.month);
    final firstWeekday = DateTime(_focusedMonth.year, _focusedMonth.month, 1).weekday % 7; // Sunday = 0

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: darkBarColor,
        elevation: 0,
        title: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
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
              const SizedBox(width: 8),
              const Text(
                'Pending Calendar',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                  color: Colors.white,
                ),
              ),
            ],
          ),
        ),
        actions: [
          // Year Selection Quick Chip
          InkWell(
            onTap: _pickYear,
            borderRadius: BorderRadius.circular(8),
            child: Container(
              margin: const EdgeInsets.symmetric(vertical: 10, horizontal: 2),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: emeraldGreen.withValues(alpha: 0.18),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: emeraldGreen.withValues(alpha: 0.4)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${_focusedMonth.year}',
                    style: const TextStyle(
                      color: emeraldGreen,
                      fontSize: 12.5,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 2),
                  const Icon(Icons.arrow_drop_down_rounded, color: emeraldGreen, size: 18),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: 'Go to Today',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.today_rounded, color: emeraldGreen),
            onPressed: () {
              setState(() {
                final now = DateTime.now();
                _selectedDate = DateTime(now.year, now.month, now.day);
                _focusedMonth = DateTime(now.year, now.month, 1);
              });
            },
          ),
          IconButton(
            tooltip: 'Refresh',
            visualDensity: VisualDensity.compact,
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadTasks,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: emeraldGreen),
            )
          : Column(
              children: [
                if (_hasMissingPermissions)
                  InkWell(
                    onTap: () {
                      PermissionDialog.show(context, onPermissionsUpdated: () {
                        _checkPermissions();
                        _loadTasks();
                      });
                    },
                    child: Container(
                      margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF2F2),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFFCA5A5)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.warning_amber_rounded, size: 18, color: Color(0xFFEF4444)),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              'Permissions missing! Alarms will not ring. Tap to allow.',
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                                color: Color(0xFFB91C1C),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                            decoration: BoxDecoration(
                              color: const Color(0xFFEF4444),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: const Text(
                              'ALLOW',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                // Month & Year Navigation Bar with fast year buttons & clickable picker
                Container(
                  margin: const EdgeInsets.fromLTRB(16, 10, 16, 6),
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.03),
                        blurRadius: 6,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      // Jump 1 Year Back
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.keyboard_double_arrow_left_rounded, size: 20),
                        tooltip: 'Previous Year (${_focusedMonth.year - 1})',
                        color: const Color(0xFF64748B),
                        onPressed: () => _changeYear(-1),
                      ),
                      // Jump 1 Month Back
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.chevron_left_rounded, size: 22),
                        tooltip: 'Previous Month',
                        color: const Color(0xFF171717),
                        onPressed: () => _changeMonth(-1),
                      ),
                      // Clickable Month & Year Header to open Year Picker
                      Flexible(
                        child: InkWell(
                          onTap: _pickYear,
                          borderRadius: BorderRadius.circular(8),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    DateFormat('MMMM yyyy').format(_focusedMonth),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: Color(0xFF171717),
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.arrow_drop_down_rounded,
                                    size: 20,
                                    color: emeraldGreen,
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                      // Jump 1 Month Forward
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.chevron_right_rounded, size: 22),
                        tooltip: 'Next Month',
                        color: const Color(0xFF171717),
                        onPressed: () => _changeMonth(1),
                      ),
                      // Jump 1 Year Forward
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                        icon: const Icon(Icons.keyboard_double_arrow_right_rounded, size: 20),
                        tooltip: 'Next Year (${_focusedMonth.year + 1})',
                        color: const Color(0xFF64748B),
                        onPressed: () => _changeYear(1),
                      ),
                    ],
                  ),
                ),

                // Meeting Filter Pill Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      // All Pending Filter
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _currentFilter = CalendarFilter.all;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                            decoration: BoxDecoration(
                              color: _currentFilter == CalendarFilter.all
                                  ? emeraldGreen
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _currentFilter == CalendarFilter.all
                                    ? emeraldGreen
                                    : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                              boxShadow: _currentFilter == CalendarFilter.all
                                  ? [
                                      BoxShadow(
                                        color: emeraldGreen.withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.list_alt_rounded,
                                  size: 15,
                                  color: _currentFilter == CalendarFilter.all
                                      ? Colors.white
                                      : const Color(0xFF64748B),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'All Pending (${_allCountForMonth()})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _currentFilter == CalendarFilter.all
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: _currentFilter == CalendarFilter.all
                                            ? Colors.white
                                            : const Color(0xFF475569),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Meetings Filter
                      Expanded(
                        child: InkWell(
                          onTap: () {
                            setState(() {
                              _currentFilter = CalendarFilter.meetings;
                            });
                          },
                          borderRadius: BorderRadius.circular(12),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 160),
                            padding: const EdgeInsets.symmetric(vertical: 7, horizontal: 4),
                            decoration: BoxDecoration(
                              color: _currentFilter == CalendarFilter.meetings
                                  ? const Color(0xFF8B5CF6)
                                  : Colors.white,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: _currentFilter == CalendarFilter.meetings
                                    ? const Color(0xFF8B5CF6)
                                    : const Color(0xFFE5E7EB),
                                width: 1.2,
                              ),
                              boxShadow: _currentFilter == CalendarFilter.meetings
                                  ? [
                                      BoxShadow(
                                        color: const Color(0xFF8B5CF6).withValues(alpha: 0.25),
                                        blurRadius: 6,
                                        offset: const Offset(0, 2),
                                      ),
                                    ]
                                  : null,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.groups_rounded,
                                  size: 15,
                                  color: _currentFilter == CalendarFilter.meetings
                                      ? Colors.white
                                      : const Color(0xFF8B5CF6),
                                ),
                                const SizedBox(width: 4),
                                Flexible(
                                  child: FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      'Meetings (${_meetingCountForMonth()})',
                                      style: TextStyle(
                                        fontSize: 12,
                                        fontWeight: _currentFilter == CalendarFilter.meetings
                                            ? FontWeight.bold
                                            : FontWeight.w600,
                                        color: _currentFilter == CalendarFilter.meetings
                                            ? Colors.white
                                            : const Color(0xFF171717),
                                      ),
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
                ),
                const SizedBox(height: 4),

                // Calendar Grid Card
                Container(
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  padding: const EdgeInsets.fromLTRB(10, 8, 10, 10),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(color: const Color(0xFFE5E7EB)),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.04),
                        blurRadius: 8,
                        offset: const Offset(0, 3),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // Weekday headers
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                            .map((day) => Expanded(
                                  child: Center(
                                    child: Text(
                                      day,
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.bold,
                                        color: Color(0xFF6B7280),
                                      ),
                                    ),
                                  ),
                                ))
                            .toList(),
                      ),
                      const SizedBox(height: 6),

                      // Days Matrix
                      GridView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 7,
                          childAspectRatio: 1.15,
                        ),
                        itemCount: firstWeekday + daysInMonth,
                        itemBuilder: (context, index) {
                          if (index < firstWeekday) {
                            return const SizedBox.shrink();
                          }

                          final dayNum = index - firstWeekday + 1;
                          final date = DateTime(
                            _focusedMonth.year,
                            _focusedMonth.month,
                            dayNum,
                          );

                          final isSelected = _isSameDay(date, _selectedDate);
                          final isToday = _isSameDay(date, DateTime.now());
                          final dayTasks = _tasksForDate(date);
                          final hasTasks = dayTasks.isNotEmpty;

                          final accentColor = _currentFilter == CalendarFilter.meetings
                              ? const Color(0xFF8B5CF6)
                              : emeraldGreen;

                          return GestureDetector(
                            onTap: () {
                              setState(() {
                                _selectedDate = date;
                              });
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 180),
                              margin: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? accentColor
                                    : (isToday
                                        ? accentColor.withValues(alpha: 0.12)
                                        : Colors.transparent),
                                borderRadius: BorderRadius.circular(12),
                                border: isToday && !isSelected
                                    ? Border.all(color: accentColor, width: 1.5)
                                    : null,
                              ),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Text(
                                    dayNum.toString(),
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: isSelected || isToday
                                          ? FontWeight.bold
                                          : FontWeight.w500,
                                      color: isSelected
                                          ? Colors.white
                                          : (isToday
                                              ? accentColor
                                              : const Color(0xFF171717)),
                                    ),
                                  ),
                                  if (hasTasks) ...[
                                    const SizedBox(height: 2),
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                          horizontal: 4, vertical: 1),
                                      decoration: BoxDecoration(
                                        color: isSelected
                                            ? Colors.white
                                            : (_currentFilter == CalendarFilter.meetings
                                                ? const Color(0xFF8B5CF6)
                                                : const Color(0xFFF59E0B)),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        dayTasks.length.toString(),
                                        style: TextStyle(
                                          fontSize: 9,
                                          fontWeight: FontWeight.w800,
                                          color: isSelected
                                              ? (_currentFilter == CalendarFilter.meetings
                                                  ? const Color(0xFF8B5CF6)
                                                  : emeraldGreen)
                                              : Colors.white,
                                        ),
                                      ),
                                    ),
                                  ] else
                                    const SizedBox(height: 11),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),

                // Selected Date Summary Bar
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Icon(
                        _currentFilter == CalendarFilter.meetings
                            ? Icons.groups_rounded
                            : Icons.access_time_filled_rounded,
                        size: 16,
                        color: _currentFilter == CalendarFilter.meetings
                            ? const Color(0xFF8B5CF6)
                            : emeraldGreen,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          DateFormat('EEEE, MMM d, yyyy').format(_selectedDate),
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.bold,
                            color: Color(0xFF171717),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: BoxDecoration(
                          color: _currentFilter == CalendarFilter.meetings
                              ? const Color(0xFF8B5CF6).withValues(alpha: 0.12)
                              : emeraldGreen.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: _currentFilter == CalendarFilter.meetings
                                ? const Color(0xFF8B5CF6).withValues(alpha: 0.3)
                                : emeraldGreen.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          '${selectedDayTasks.length} ${_currentFilter == CalendarFilter.meetings ? "Meeting${selectedDayTasks.length == 1 ? "" : "s"}" : "Pending"}',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: _currentFilter == CalendarFilter.meetings
                                ? const Color(0xFF8B5CF6)
                                : emeraldGreen,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 4),

                // List of Pending Tasks for Selected Date
                Expanded(
                  child: selectedDayTasks.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: _currentFilter == CalendarFilter.meetings
                                      ? const Color(0xFF8B5CF6).withValues(alpha: 0.1)
                                      : emeraldGreen.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _currentFilter == CalendarFilter.meetings
                                      ? Icons.groups_outlined
                                      : Icons.event_available_rounded,
                                  size: 40,
                                  color: _currentFilter == CalendarFilter.meetings
                                      ? const Color(0xFF8B5CF6)
                                      : emeraldGreen,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _currentFilter == CalendarFilter.meetings
                                    ? 'No meetings scheduled for this day'
                                    : 'No pending tasks scheduled for this day',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: Color(0xFF475569),
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _currentFilter == CalendarFilter.meetings
                                    ? 'Looking for general tasks? Switch to "All Pending".'
                                    : 'Select another date with a pending badge above.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF94A3B8),
                                ),
                              ),
                              if (_currentFilter == CalendarFilter.meetings) ...[
                                const SizedBox(height: 12),
                                OutlinedButton.icon(
                                  icon: const Icon(Icons.list_alt_rounded, size: 16),
                                  label: const Text('Show All Pending Tasks'),
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: emeraldGreen,
                                    side: const BorderSide(color: emeraldGreen),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                  ),
                                  onPressed: () {
                                    setState(() {
                                      _currentFilter = CalendarFilter.all;
                                    });
                                  },
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 24, top: 4),
                          itemCount: selectedDayTasks.length,
                          itemBuilder: (context, index) {
                            final task = selectedDayTasks[index];
                            return TaskTile(
                              key: ValueKey(task.id),
                              task: task,
                              onComplete: () => _markCompleted(task),
                              onCancel: () => _markCancelled(task),
                              onEdit: () => _editTask(task),
                              onDelete: () => _deleteTask(task),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}
