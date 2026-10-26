import 'package:flutter/foundation.dart';

enum TaskStatus {
  pending('pending'),
  completed('completed'),
  cancelled('cancelled');

  final String value;
  const TaskStatus(this.value);

  static TaskStatus fromString(String? val) {
    if (val == null) return TaskStatus.pending;
    return TaskStatus.values.firstWhere(
      (element) => element.value.toLowerCase() == val.trim().toLowerCase(),
      orElse: () => TaskStatus.pending,
    );
  }
}

@immutable
class ScheduleTask {
  final int? id;
  final String title;
  final DateTime scheduledTime;
  final String status; // 'pending', 'completed', 'cancelled'
  final String? voiceNotePath; // Optional path to user's recorded audio note (.m4a)

  const ScheduleTask({
    this.id,
    required this.title,
    required this.scheduledTime,
    this.status = 'pending',
    this.voiceNotePath,
  });

  bool get isPending => status == TaskStatus.pending.value;
  bool get isCompleted => status == TaskStatus.completed.value;
  bool get isCancelled => status == TaskStatus.cancelled.value;

  TaskStatus get taskStatus => TaskStatus.fromString(status);

  /// Convert to SQLite Map
  Map<String, dynamic> toMap() {
    final map = <String, dynamic>{
      'title': title,
      'scheduledTime': scheduledTime.toIso8601String(),
      'status': status,
      'voiceNotePath': voiceNotePath,
    };
    if (id != null) {
      map['id'] = id;
    }
    return map;
  }

  /// Create model instance from SQLite Map
  factory ScheduleTask.fromMap(Map<String, dynamic> map) {
    return ScheduleTask(
      id: map['id'] as int?,
      title: map['title'] as String? ?? '',
      scheduledTime: map['scheduledTime'] != null
          ? DateTime.parse(map['scheduledTime'] as String)
          : DateTime.now(),
      status: map['status'] as String? ?? TaskStatus.pending.value,
      voiceNotePath: map['voiceNotePath'] as String?,
    );
  }

  /// Copy with new attributes
  ScheduleTask copyWith({
    int? id,
    String? title,
    DateTime? scheduledTime,
    String? status,
    String? voiceNotePath,
  }) {
    return ScheduleTask(
      id: id ?? this.id,
      title: title ?? this.title,
      scheduledTime: scheduledTime ?? this.scheduledTime,
      status: status ?? this.status,
      voiceNotePath: voiceNotePath ?? this.voiceNotePath,
    );
  }

  @override
  String toString() {
    return 'ScheduleTask(id: $id, title: $title, scheduledTime: $scheduledTime, status: $status, voiceNotePath: $voiceNotePath)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ScheduleTask &&
        other.id == id &&
        other.title == title &&
        other.scheduledTime == scheduledTime &&
        other.status == status &&
        other.voiceNotePath == voiceNotePath;
  }

  @override
  int get hashCode {
    return Object.hash(id, title, scheduledTime, status, voiceNotePath);
  }
}
