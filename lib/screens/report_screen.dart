import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../models/schedule_task.dart';
import '../services/db_service.dart';

enum ReportFilter {
  all('All Time', Icons.all_inclusive_rounded),
  day('Day (Today)', Icons.today_rounded),
  week('This Week', Icons.view_week_rounded),
  month('This Month', Icons.calendar_month_rounded),
  year('This Year', Icons.event_note_rounded),
  custom('Custom Range', Icons.date_range_rounded);

  final String label;
  final IconData icon;
  const ReportFilter(this.label, this.icon);
}

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  static const Color emeraldGreen = Color(0xFF10B981);
  static const Color darkBarColor = Color(0xFF171717);

  List<ScheduleTask> _allTasks = [];
  bool _isLoading = true;

  ReportFilter _selectedFilter = ReportFilter.all;
  DateTimeRange? _customRange;

  @override
  void initState() {
    super.initState();
    _loadReportData();
  }

  Future<void> _loadReportData() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final all = await DBService.instance.getAllTasks();
      if (mounted) {
        setState(() {
          _allTasks = all;
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

  Future<void> _pickCustomRange() async {
    final now = DateTime.now();
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 5),
      initialDateRange: _customRange ??
          DateTimeRange(
            start: now.subtract(const Duration(days: 7)),
            end: now.add(const Duration(days: 7)),
          ),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: emeraldGreen,
                  onPrimary: Colors.white,
                  surface: Colors.white,
                ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      setState(() {
        _customRange = picked;
        _selectedFilter = ReportFilter.custom;
      });
    }
  }

  List<ScheduleTask> get _filteredTasks {
    final now = DateTime.now();

    switch (_selectedFilter) {
      case ReportFilter.day:
        final start = DateTime(now.year, now.month, now.day);
        final end = DateTime(now.year, now.month, now.day, 23, 59, 59, 999);
        return _allTasks.where((t) =>
            !t.scheduledTime.isBefore(start) && !t.scheduledTime.isAfter(end)).toList();

      case ReportFilter.week:
        // Current week (Monday through Sunday)
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final start = DateTime(startOfWeek.year, startOfWeek.month, startOfWeek.day);
        final end = DateTime(start.year, start.month, start.day + 7).subtract(const Duration(milliseconds: 1));
        return _allTasks.where((t) =>
            !t.scheduledTime.isBefore(start) && !t.scheduledTime.isAfter(end)).toList();

      case ReportFilter.month:
        final start = DateTime(now.year, now.month, 1);
        final daysInMonth = DateUtils.getDaysInMonth(now.year, now.month);
        final end = DateTime(now.year, now.month, daysInMonth, 23, 59, 59, 999);
        return _allTasks.where((t) =>
            !t.scheduledTime.isBefore(start) && !t.scheduledTime.isAfter(end)).toList();

      case ReportFilter.year:
        final start = DateTime(now.year, 1, 1);
        final end = DateTime(now.year, 12, 31, 23, 59, 59, 999);
        return _allTasks.where((t) =>
            !t.scheduledTime.isBefore(start) && !t.scheduledTime.isAfter(end)).toList();

      case ReportFilter.custom:
        if (_customRange == null) return _allTasks;
        final start = DateTime(
          _customRange!.start.year,
          _customRange!.start.month,
          _customRange!.start.day,
        );
        final end = DateTime(
          _customRange!.end.year,
          _customRange!.end.month,
          _customRange!.end.day,
          23, 59, 59, 999,
        );
        return _allTasks.where((t) =>
            !t.scheduledTime.isBefore(start) && !t.scheduledTime.isAfter(end)).toList();

      case ReportFilter.all:
        return _allTasks;
    }
  }

  String get _activeRangeLabel {
    final now = DateTime.now();
    switch (_selectedFilter) {
      case ReportFilter.day:
        return DateFormat('EEE, MMM d, yyyy').format(now);
      case ReportFilter.week:
        final startOfWeek = now.subtract(Duration(days: now.weekday - 1));
        final endOfWeek = startOfWeek.add(const Duration(days: 6));
        return '${DateFormat('MMM d').format(startOfWeek)} – ${DateFormat('MMM d, yyyy').format(endOfWeek)}';
      case ReportFilter.month:
        return DateFormat('MMMM yyyy').format(now);
      case ReportFilter.year:
        return '${now.year}';
      case ReportFilter.custom:
        if (_customRange != null) {
          return '${DateFormat('MMM d, yyyy').format(_customRange!.start)} – ${DateFormat('MMM d, yyyy').format(_customRange!.end)}';
        }
        return 'Custom Date Range';
      case ReportFilter.all:
        return 'All Time Record';
    }
  }

  int get _totalCount => _filteredTasks.length;
  int get _completedCount => _filteredTasks.where((t) => t.isCompleted).length;
  int get _pendingCount => _filteredTasks.where((t) => t.isPending).length;
  int get _cancelledCount => _filteredTasks.where((t) => t.isCancelled).length;

  double get _completionRate {
    if (_totalCount == 0) return 0.0;
    return (_completedCount / _totalCount) * 100;
  }

  int get _dueTodayCount {
    final now = DateTime.now();
    return _filteredTasks.where((t) {
      if (!t.isPending) return false;
      return t.scheduledTime.year == now.year &&
          t.scheduledTime.month == now.month &&
          t.scheduledTime.day == now.day;
    }).length;
  }

  int get _dueTomorrowCount {
    final tomorrow = DateTime.now().add(const Duration(days: 1));
    return _filteredTasks.where((t) {
      if (!t.isPending) return false;
      return t.scheduledTime.year == tomorrow.year &&
          t.scheduledTime.month == tomorrow.month &&
          t.scheduledTime.day == tomorrow.day;
    }).length;
  }

  int get _overdueCount {
    final now = DateTime.now();
    return _filteredTasks.where((t) {
      return t.isPending && t.scheduledTime.isBefore(now);
    }).length;
  }

  int get _activeAlertsCount {
    final now = DateTime.now();
    int count = 0;
    for (final task in _filteredTasks.where((t) => t.isPending)) {
      for (final offset in [60, 45, 30, 15]) {
        final alertTime = task.scheduledTime.subtract(Duration(minutes: offset));
        if (alertTime.isAfter(now)) {
          count++;
        }
      }
    }
    return count;
  }

  Widget _buildBreakdownRow({
    required String title,
    required int count,
    required int total,
    required Color color,
    required IconData icon,
  }) {
    final percentage = total > 0 ? (count / total) : 0.0;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: color),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: Color(0xFF171717),
                ),
              ),
              const Spacer(),
              Text(
                '$count (${(percentage * 100).toStringAsFixed(0)}%)',
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.bold,
                  color: color,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: percentage,
              minHeight: 7,
              backgroundColor: const Color(0xFFF1F5F9),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSummaryBox({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    String? subtitle,
  }) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(13),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: const Color(0xFFE5E7EB)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.03),
              blurRadius: 8,
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
                  padding: const EdgeInsets.all(6),
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(icon, size: 16, color: color),
                ),
                Text(
                  value,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              title,
              style: const TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: Color(0xFF475569),
              ),
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 2),
              Text(
                subtitle,
                style: const TextStyle(
                  fontSize: 10.5,
                  color: Color(0xFF94A3B8),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChip(ReportFilter filter) {
    final isSelected = _selectedFilter == filter;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: FilterChip(
        selected: isSelected,
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              filter.icon,
              size: 14,
              color: isSelected ? Colors.white : emeraldGreen,
            ),
            const SizedBox(width: 5),
            Text(filter.label),
          ],
        ),
        labelStyle: TextStyle(
          fontSize: 12,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
          color: isSelected ? Colors.white : const Color(0xFF171717),
        ),
        backgroundColor: Colors.white,
        selectedColor: emeraldGreen,
        checkmarkColor: Colors.white,
        showCheckmark: false,
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(
            color: isSelected ? emeraldGreen : const Color(0xFFE5E7EB),
          ),
        ),
        onSelected: (_) {
          if (filter == ReportFilter.custom) {
            _pickCustomRange();
          } else {
            setState(() {
              _selectedFilter = filter;
            });
          }
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final rate = _completionRate;

    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
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
              'Progress & Reports',
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
            tooltip: 'Pick Custom Date Range',
            icon: const Icon(Icons.date_range_rounded, color: emeraldGreen),
            onPressed: _pickCustomRange,
          ),
          IconButton(
            tooltip: 'Refresh Report',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadReportData,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: emeraldGreen),
            )
          : RefreshIndicator(
              onRefresh: _loadReportData,
              color: emeraldGreen,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Filter Chips Bar (Day, Week, Month, Year, Custom Range, All)
                    SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _buildFilterChip(ReportFilter.all),
                          _buildFilterChip(ReportFilter.day),
                          _buildFilterChip(ReportFilter.week),
                          _buildFilterChip(ReportFilter.month),
                          _buildFilterChip(ReportFilter.year),
                          _buildFilterChip(ReportFilter.custom),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Active Range Indicator
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                      decoration: BoxDecoration(
                        color: emeraldGreen.withValues(alpha: 0.08),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: emeraldGreen.withValues(alpha: 0.25)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.filter_alt_rounded, size: 14, color: emeraldGreen),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Filter: $_activeRangeLabel',
                              style: const TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.bold,
                                color: Color(0xFF171717),
                              ),
                            ),
                          ),
                          Text(
                            '$_totalCount Task${_totalCount == 1 ? "" : "s"}',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: emeraldGreen,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Main Progress Hero Card
                    Container(
                      padding: const EdgeInsets.all(18),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [Color(0xFF171717), Color(0xFF262626)],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(22),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.15),
                            blurRadius: 14,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Row(
                        children: [
                          // Radial Progress Circle
                          SizedBox(
                            width: 82,
                            height: 82,
                            child: Stack(
                              alignment: Alignment.center,
                              children: [
                                CircularProgressIndicator(
                                  value: _totalCount > 0 ? (rate / 100) : 0,
                                  strokeWidth: 8,
                                  backgroundColor: Colors.white24,
                                  valueColor: const AlwaysStoppedAnimation<Color>(
                                    emeraldGreen,
                                  ),
                                ),
                                Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      '${rate.toStringAsFixed(0)}%',
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const Text(
                                      'DONE',
                                      style: TextStyle(
                                        color: emeraldGreen,
                                        fontSize: 9,
                                        fontWeight: FontWeight.w800,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),

                          // Text Summary
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Task Completion Rate',
                                  style: TextStyle(
                                    color: Colors.white,
                                    fontSize: 16,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '$_completedCount of $_totalCount tasks finished in selected period.',
                                  style: const TextStyle(
                                    color: Colors.white70,
                                    fontSize: 12,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: emeraldGreen.withValues(alpha: 0.18),
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: emeraldGreen.withValues(alpha: 0.4)),
                                  ),
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Icon(
                                        _overdueCount == 0
                                            ? Icons.check_circle_outline_rounded
                                            : Icons.warning_amber_rounded,
                                        size: 13,
                                        color: emeraldGreen,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _overdueCount == 0
                                            ? "On Track"
                                            : '$_overdueCount Overdue Task${_overdueCount > 1 ? "s" : ""}',
                                        style: const TextStyle(
                                          color: emeraldGreen,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Status Breakdown Card
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.03),
                            blurRadius: 8,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Status Distribution',
                            style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                              color: Color(0xFF171717),
                            ),
                          ),
                          const SizedBox(height: 12),
                          _buildBreakdownRow(
                            title: 'Pending Tasks',
                            count: _pendingCount,
                            total: _totalCount,
                            color: const Color(0xFFF59E0B),
                            icon: Icons.pending_actions_rounded,
                          ),
                          _buildBreakdownRow(
                            title: 'Completed Tasks',
                            count: _completedCount,
                            total: _totalCount,
                            color: emeraldGreen,
                            icon: Icons.check_circle_rounded,
                          ),
                          _buildBreakdownRow(
                            title: 'Cancelled Tasks',
                            count: _cancelledCount,
                            total: _totalCount,
                            color: const Color(0xFFEF4444),
                            icon: Icons.cancel_rounded,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 14),

                    // Deadlines & Alert Activity Grid
                    Row(
                      children: [
                        _buildSummaryBox(
                          title: 'Due Today',
                          value: _dueTodayCount.toString(),
                          icon: Icons.today_rounded,
                          color: emeraldGreen,
                          subtitle: 'Urgent focus',
                        ),
                        const SizedBox(width: 10),
                        _buildSummaryBox(
                          title: 'Due Tomorrow',
                          value: _dueTomorrowCount.toString(),
                          icon: Icons.event_rounded,
                          color: const Color(0xFF0EA5E9),
                          subtitle: 'Upcoming',
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        _buildSummaryBox(
                          title: 'Active Alarms',
                          value: _activeAlertsCount.toString(),
                          icon: Icons.notifications_active_rounded,
                          color: const Color(0xFF8B5CF6),
                          subtitle: 'Pre-deadline alerts',
                        ),
                        const SizedBox(width: 10),
                        _buildSummaryBox(
                          title: 'Overdue',
                          value: _overdueCount.toString(),
                          icon: Icons.warning_amber_rounded,
                          color: _overdueCount > 0
                              ? const Color(0xFFEF4444)
                              : emeraldGreen,
                          subtitle: _overdueCount > 0 ? 'Requires attention' : 'All clear',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
    );
  }
}
