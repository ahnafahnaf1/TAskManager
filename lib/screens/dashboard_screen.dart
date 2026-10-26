import 'package:flutter/material.dart';
import '../models/schedule_task.dart';
import '../services/db_service.dart';
import '../services/notification_service.dart';
import '../widgets/add_task_sheet.dart';
import '../widgets/voice_schedule_sheet.dart';
import '../widgets/confirmation_dialog.dart';
import '../widgets/edit_task_sheet.dart';
import '../widgets/permission_dialog.dart';
import '../widgets/task_tile.dart';
import 'calendar_screen.dart';
import 'report_screen.dart';
import 'settings_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  // Index 1 (Calendar View) opens first on application startup as requested
  int _currentNavigationIndex = 1;

  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color darkBarColor = Color(0xFF171717);

  List<ScheduleTask> _allTasks = [];
  bool _isLoading = true;
  String _selectedFilter = 'pending'; // Default to pending tasks
  String _searchQuery = '';
  final TextEditingController _searchController = TextEditingController();
  bool _hasMissingPermissions = false;

  @override
  void initState() {
    super.initState();
    _loadTasks();
    NotificationService.instance.settingsVersionNotifier.addListener(_onSettingsOrTasksChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkPermissionsOnStartup();
    });
  }

  void _onSettingsOrTasksChanged() {
    if (mounted) {
      _loadTasks();
    }
  }

  @override
  void dispose() {
    NotificationService.instance.settingsVersionNotifier.removeListener(_onSettingsOrTasksChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _checkPermissionsOnStartup() async {
    final notifs = await NotificationService.instance.checkNotificationPermission();
    final exact = await NotificationService.instance.checkExactAlarmPermission();
    final missing = !notifs || !exact;

    if (mounted) {
      setState(() {
        _hasMissingPermissions = missing;
      });

      // If user did not allow, show every time on app startup as requested
      if (missing) {
        PermissionDialog.show(context, onPermissionsUpdated: () async {
          final n = await NotificationService.instance.checkNotificationPermission();
          final e = await NotificationService.instance.checkExactAlarmPermission();
          if (mounted) {
            setState(() {
              _hasMissingPermissions = !n || !e;
            });
          }
        });
      }
    }
  }

  Future<void> _loadTasks() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final tasks = await DBService.instance.getAllTasks();
      if (mounted) {
        setState(() {
          _allTasks = tasks;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load tasks: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Transition state to 'completed' and cancel alerts
  Future<void> _markTaskCompleted(ScheduleTask task) async {
    if (task.id == null) return;

    final confirmed = await ConfirmationDialog.confirmComplete(
      context,
      taskTitle: task.title,
    );
    if (!confirmed) return;

    try {
      await DBService.instance.updateTaskStatus(task.id!, TaskStatus.completed.value);
      await NotificationService.instance.cancelTaskAlerts(task.id!);
      NotificationService.instance.notifySettingsChanged();
      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.check_circle_rounded, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Marked "${task.title}" as Completed. Alerts cancelled.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: emeraldGreen,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to update task: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  /// Transition state to 'cancelled' and cancel alerts
  Future<void> _markTaskCancelled(ScheduleTask task) async {
    if (task.id == null) return;

    final confirmed = await ConfirmationDialog.confirmCancel(
      context,
      taskTitle: task.title,
    );
    if (!confirmed) return;

    try {
      await DBService.instance.updateTaskStatus(task.id!, TaskStatus.cancelled.value);
      await NotificationService.instance.cancelTaskAlerts(task.id!);
      NotificationService.instance.notifySettingsChanged();
      await _loadTasks();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                const Icon(Icons.cancel_outlined, color: Colors.white, size: 20),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Cancelled "${task.title}". Alerts cancelled.',
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ],
            ),
            backgroundColor: const Color(0xFFEF4444),
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            duration: const Duration(seconds: 3),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to cancel task: $e'),
            backgroundColor: const Color(0xFFEF4444),
          ),
        );
      }
    }
  }

  Future<void> _editTask(ScheduleTask task) async {
    await EditTaskSheet.show(
      context,
      task: task,
      onTaskUpdated: _loadTasks,
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
    NotificationService.instance.notifySettingsChanged();
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

  List<ScheduleTask> get _filteredTasks {
    return _allTasks.where((task) {
      final matchesFilter = switch (_selectedFilter) {
        'pending' => task.isPending,
        'completed' => task.isCompleted,
        'cancelled' => task.isCancelled,
        _ => true,
      };

      if (!matchesFilter) return false;

      if (_searchQuery.trim().isNotEmpty) {
        return task.title.toLowerCase().contains(_searchQuery.toLowerCase());
      }

      return true;
    }).toList();
  }

  int get _pendingCount => _allTasks.where((t) => t.isPending).length;
  int get _completedCount => _allTasks.where((t) => t.isCompleted).length;
  int get _cancelledCount => _allTasks.where((t) => t.isCancelled).length;

  Widget _buildStatCard({
    required String label,
    required int count,
    required Color color,
    required IconData icon,
  }) {
    final isSelected = _selectedFilter == label.toLowerCase();

    return Expanded(
      child: InkWell(
        onTap: () {
          setState(() {
            _selectedFilter = label.toLowerCase();
          });
        },
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 10),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected ? color : const Color(0xFFE5E7EB),
              width: isSelected ? 1.8 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: isSelected ? 0.08 : 0.03),
                blurRadius: 6,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(5),
                    decoration: BoxDecoration(
                      color: color.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(icon, size: 15, color: color),
                  ),
                  Text(
                    count.toString(),
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: isSelected ? color : const Color(0xFF171717),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                  color: isSelected ? color : const Color(0xFF64748B),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFilterChip(String label, String value, int count, Color activeColor) {
    final isSelected = _selectedFilter == value;

    return FilterChip(
      selected: isSelected,
      label: Text('$label ($count)'),
      labelStyle: TextStyle(
        fontSize: 12,
        fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
        color: isSelected ? Colors.white : const Color(0xFF475569),
      ),
      backgroundColor: Colors.white,
      selectedColor: activeColor,
      checkmarkColor: Colors.white,
      showCheckmark: false,
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: isSelected ? activeColor : const Color(0xFFE5E7EB),
        ),
      ),
      onSelected: (_) {
        setState(() {
          _selectedFilter = value;
        });
      },
    );
  }

  Widget _buildTasksList(List<ScheduleTask> filtered) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (_hasMissingPermissions)
          InkWell(
            onTap: () {
              PermissionDialog.show(context, onPermissionsUpdated: _checkPermissionsOnStartup);
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
        // Summary Stats Row
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Row(
            children: [
              _buildStatCard(
                label: 'Pending',
                count: _pendingCount,
                color: const Color(0xFFF59E0B),
                icon: Icons.pending_actions_rounded,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Completed',
                count: _completedCount,
                color: emeraldGreen,
                icon: Icons.check_circle_outline_rounded,
              ),
              const SizedBox(width: 8),
              _buildStatCard(
                label: 'Cancelled',
                count: _cancelledCount,
                color: const Color(0xFFEF4444),
                icon: Icons.cancel_outlined,
              ),
            ],
          ),
        ),

        // Search Bar
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: TextField(
            controller: _searchController,
            onChanged: (val) {
              setState(() {
                _searchQuery = val;
              });
            },
            decoration: InputDecoration(
              hintText: 'Search tasks...',
              hintStyle: const TextStyle(fontSize: 13, color: Color(0xFF94A3B8)),
              prefixIcon: const Icon(Icons.search_rounded, size: 20, color: Color(0xFF64748B)),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear_rounded, size: 18),
                      onPressed: () {
                        _searchController.clear();
                        setState(() {
                          _searchQuery = '';
                        });
                      },
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: emeraldGreen, width: 1.5),
              ),
            ),
          ),
        ),

        // Filter Chips (Pending first)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _buildFilterChip('Pending', 'pending', _pendingCount, const Color(0xFFF59E0B)),
                const SizedBox(width: 8),
                _buildFilterChip('Completed', 'completed', _completedCount, emeraldGreen),
                const SizedBox(width: 8),
                _buildFilterChip('Cancelled', 'cancelled', _cancelledCount, const Color(0xFFEF4444)),
                const SizedBox(width: 8),
                _buildFilterChip('All', 'all', _allTasks.length, darkBarColor),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),

        // Task List
        Expanded(
          child: _isLoading
              ? const Center(
                  child: CircularProgressIndicator(color: emeraldGreen),
                )
              : filtered.isEmpty
                  ? ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        const SizedBox(height: 50),
                        Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                padding: const EdgeInsets.all(18),
                                decoration: BoxDecoration(
                                  color: emeraldGreen.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  Icons.event_available_rounded,
                                  size: 48,
                                  color: emeraldGreen,
                                ),
                              ),
                              const SizedBox(height: 14),
                              Text(
                                _searchQuery.isNotEmpty
                                    ? 'No tasks matching "$_searchQuery"'
                                    : 'No ${_selectedFilter != 'all' ? _selectedFilter : ''} tasks found',
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.bold,
                                  color: Color(0xFF171717),
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Tap "+ Add Task" to schedule a new alert.',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    )
                  : ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.only(bottom: 90, top: 4),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) {
                        final task = filtered[index];
                        return TaskTile(
                          key: ValueKey(task.id),
                          task: task,
                          onComplete: () => _markTaskCompleted(task),
                          onCancel: () => _markTaskCancelled(task),
                          onEdit: () => _editTask(task),
                          onDelete: () => _deleteTask(task),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _filteredTasks;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: _currentNavigationIndex == 0
          ? AppBar(
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
                    'Task Scheduler',
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
                  tooltip: 'Stop Active Ringing Alarms',
                  icon: const Icon(Icons.alarm_off_rounded, color: Color(0xFFEF4444)),
                  onPressed: () async {
                    final confirmed = await ConfirmationDialog.confirmStopAlarms(context);
                    if (!confirmed) return;

                    await NotificationService.instance.stopAllRingingAlarms();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('All active ringing alarms stopped.'),
                          backgroundColor: Color(0xFFEF4444),
                        ),
                      );
                    }
                  },
                ),
                IconButton(
                  tooltip: 'Refresh tasks',
                  icon: const Icon(Icons.refresh_rounded, color: Colors.white),
                  onPressed: _loadTasks,
                ),
              ],
            )
          : null,
      floatingActionButton: (_currentNavigationIndex == 0 || _currentNavigationIndex == 1)
          ? Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                FloatingActionButton(
                  heroTag: 'voice_scheduler_fab',
                  backgroundColor: const Color(0xFF1F2937),
                  foregroundColor: emeraldGreen,
                  elevation: 4,
                  tooltip: 'Voice Scheduler',
                  onPressed: () {
                    VoiceScheduleSheet.show(
                      context,
                      onTaskAdded: _loadTasks,
                    );
                  },
                  child: const Icon(Icons.mic_rounded, size: 26),
                ),
                const SizedBox(width: 12),
                FloatingActionButton.extended(
                  heroTag: 'add_task_fab',
                  backgroundColor: emeraldGreen,
                  foregroundColor: Colors.white,
                  elevation: 4,
                  icon: const Icon(Icons.add_rounded),
                  label: const Text(
                    'Add Task',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    AddTaskSheet.show(
                      context,
                      onTaskAdded: _loadTasks,
                    );
                  },
                ),
              ],
            )
          : null,
      bottomNavigationBar: NavigationBar(
        height: 54, // Sleek, minimized footer height
        selectedIndex: _currentNavigationIndex,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        onDestinationSelected: (index) {
          setState(() {
            _currentNavigationIndex = index;
          });
          _loadTasks();
        },
        backgroundColor: darkBarColor, // #171717 Footer Bar
        surfaceTintColor: Colors.transparent,
        indicatorColor: emeraldGreen.withValues(alpha: 0.22),
        elevation: 8,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.list_alt_rounded),
            selectedIcon: Icon(Icons.list_alt_rounded, color: emeraldGreen),
            label: 'Tasks',
          ),
          NavigationDestination(
            icon: Icon(Icons.calendar_month_outlined),
            selectedIcon: Icon(Icons.calendar_month_rounded, color: emeraldGreen),
            label: 'Calendar',
          ),
          NavigationDestination(
            icon: Icon(Icons.analytics_outlined),
            selectedIcon: Icon(Icons.analytics_rounded, color: emeraldGreen),
            label: 'Reports',
          ),
          NavigationDestination(
            icon: Icon(Icons.settings_outlined),
            selectedIcon: Icon(Icons.settings_rounded, color: emeraldGreen),
            label: 'Settings',
          ),
        ],
      ),
      body: switch (_currentNavigationIndex) {
        1 => CalendarScreen(onTasksChanged: _loadTasks),
        2 => const ReportScreen(),
        3 => const SettingsScreen(),
        _ => RefreshIndicator(
            onRefresh: _loadTasks,
            color: emeraldGreen,
            child: _buildTasksList(filtered),
          ),
      },
    );
  }
}
