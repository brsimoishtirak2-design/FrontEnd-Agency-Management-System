import 'task_assignment.dart';
import 'task_client.dart';
import 'task_priority.dart';
import 'task_status.dart';

/// Task model. Used both for list items and detail responses.
///
/// Some fields are populated only on the detail endpoint (e.g., creatorName,
/// cancellerName). Code that reads those fields should treat them as nullable.
class Task {
  // --- Core fields (always present) ---
  final int id;
  final String title;
  final String? description;
  final int clientId;
  final int? clientBranchId;
  final TaskPriority priority;
  final String? deadlineDate; // ISO date string (e.g., "2026-05-15")
  final String? deadlineTime; // "HH:MM:SS" or null
  final TaskStatus status;
  final bool isRecurring;
  final String? recurrencePattern;
  final int? parentRecurringTaskId;
  final int createdBy;
  final String? cancelledAt;
  final int? cancelledBy;
  final String? cancellationReason;
  final String? completedAt;
  final String createdAt;
  final String updatedAt;
  final int statusHistoryCount;

  // --- Eager-loaded relations ---
  final TaskClient? client;
  final TaskClient? clientBranch; // shape similar to client when present
  final List<TaskAssignment> assignments;

  // --- Detail-only fields (null on list responses) ---
  final String? creatorName;
  final String? cancellerName;

  const Task({
    required this.id,
    required this.title,
    this.description,
    required this.clientId,
    this.clientBranchId,
    required this.priority,
    this.deadlineDate,
    this.deadlineTime,
    required this.status,
    required this.isRecurring,
    this.recurrencePattern,
    this.parentRecurringTaskId,
    required this.createdBy,
    this.cancelledAt,
    this.cancelledBy,
    this.cancellationReason,
    this.completedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.statusHistoryCount,
    this.client,
    this.clientBranch,
    required this.assignments,
    this.creatorName,
    this.cancellerName,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    // Assignments come under different keys depending on endpoint:
    //   list  → 'active_assignments'
    //   detail → 'assignments'
    final rawAssignments = (json['active_assignments'] ??
            json['assignments'] ??
            const <dynamic>[]) as List<dynamic>;

    final creator = json['creator'] as Map<String, dynamic>?;
    final canceller = json['canceller'] as Map<String, dynamic>?;
    final clientJson = json['client'] as Map<String, dynamic>?;
    final clientBranchJson = json['client_branch'] as Map<String, dynamic>?;

    return Task(
      id: json['id'] as int,
      title: json['title'] as String,
      description: json['description'] as String?,
      clientId: json['client_id'] as int,
      clientBranchId: json['client_branch_id'] as int?,
      priority: TaskPriority.fromWire(json['priority'] as String),
      deadlineDate: json['deadline_date'] as String?,
      deadlineTime: json['deadline_time'] as String?,
      status: TaskStatus.fromWire(json['status'] as String),
      isRecurring: json['is_recurring'] as bool? ?? false,
      recurrencePattern: json['recurrence_pattern'] as String?,
      parentRecurringTaskId: json['parent_recurring_task_id'] as int?,
      createdBy: json['created_by'] as int,
      cancelledAt: json['cancelled_at'] as String?,
      cancelledBy: json['cancelled_by'] as int?,
      cancellationReason: json['cancellation_reason'] as String?,
      completedAt: json['completed_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      statusHistoryCount: json['status_history_count'] as int? ?? 0,
      client: clientJson == null ? null : TaskClient.fromJson(clientJson),
      clientBranch: clientBranchJson == null
          ? null
          : TaskClient.fromJson(clientBranchJson),
      assignments: rawAssignments
          .map((a) => TaskAssignment.fromJson(a as Map<String, dynamic>))
          .toList(),
      creatorName: creator?['name'] as String?,
      cancellerName: canceller?['name'] as String?,
    );
  }

  // --- Convenience getters ---

  /// The leader of this task, if any (the assignee allowed to submit).
  TaskAssignment? get leader {
    for (final a in assignments) {
      if (a.isLeader) return a;
    }
    return null;
  }

  /// True if the given user is the current leader.
  bool isLeaderUser(int userId) {
    final l = leader;
    return l != null && l.userId == userId;
  }

  /// True if the given user is currently assigned (any role).
  bool isAssignedUser(int userId) {
    return assignments.any((a) => a.userId == userId && a.isActive);
  }

  /// Display-friendly client name (falls back to "—" when client missing).
  String get clientDisplayName => client?.name ?? '—';
}
