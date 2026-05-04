import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_status.dart';

/// Repository for ADMIN-only task endpoints (/api/admin/tasks/*).
///
/// Admin can:
///   - List ALL tasks across the agency (with optional status filter)
///   - Read any task in detail
///   - Approve / cancel / request-changes (state transitions)
///
/// (Create / update / assignment management come in later prompts.)
class AdminTasksRepository {
  final ApiClient _api;

  AdminTasksRepository(this._api);

  /// GET /api/admin/tasks
  ///
  /// Returns ALL tasks across the agency. Backend supports ?status=...
  /// and ?search=... query params (search is LIKE against title OR
  /// description). Response is Laravel paginator { data:[...], ... }.
  ///
  /// For now we just fetch page 1 (per_page=20). The agency has <20 tasks,
  /// so this is sufficient. Add pagination once we need it.
  Future<List<Task>> listAllTasks({
    TaskStatus? statusFilter,
    String? search,
  }) async {
    final query = <String, dynamic>{};
    if (statusFilter != null) query['status'] = statusFilter.wireValue;
    final trimmedSearch = search?.trim() ?? '';
    if (trimmedSearch.isNotEmpty) query['search'] = trimmedSearch;

    final response = await _api.get<Map<String, dynamic>>(
      '/admin/tasks',
      query: query.isEmpty ? null : query,
    );

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final rawList = (body['data'] ?? body['tasks'] ?? const <dynamic>[]) as List;

    return rawList
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/admin/tasks
  ///
  /// Creates a new task with assignees. Backend creates the task,
  /// assignment rows, and initial history entry atomically (one DB
  /// transaction).
  ///
  /// Returns the newly created Task with everything eager-loaded.
  ///
  /// Throws ApiException(422) with field-level errors on validation failure.
  Future<Task> createTask({
    required String title,
    String? description,
    required int clientId,
    int? clientBranchId,
    required String priority, // 'low'|'medium'|'high'|'urgent'
    String? deadlineDate, // 'YYYY-MM-DD'
    String? deadlineTime, // 'HH:mm'
    required List<TaskAssigneeInput> assignees,
  }) async {
    final body = <String, dynamic>{
      'title': title,
      if (description != null && description.isNotEmpty)
        'description': description,
      'client_id': clientId,
      'client_branch_id': ?clientBranchId,
      'priority': priority,
      if (deadlineDate != null && deadlineDate.isNotEmpty)
        'deadline_date': deadlineDate,
      if (deadlineTime != null && deadlineTime.isNotEmpty)
        'deadline_time': deadlineTime,
      'assignees': assignees
          .map((a) => {
                'user_id': a.userId,
                if (a.isLeader) 'is_leader': true,
              })
          .toList(),
    };

    final response = await _api.post<Map<String, dynamic>>(
      '/admin/tasks',
      data: body,
    );
    final responseBody = response.data;
    if (responseBody == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final taskJson =
        (responseBody['data'] ?? responseBody) as Map<String, dynamic>;
    return Task.fromJson(taskJson);
  }

  /// GET /api/admin/tasks/{id}
  ///
  /// Admin can read any task, not just ones they created. Returns single
  /// task wrapped in {"data": {...}}.
  Future<Task> getTask(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/tasks/$id');

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final taskJson = (body['data'] ?? body) as Map<String, dynamic>;
    return Task.fromJson(taskJson);
  }

  /// POST /api/admin/tasks/{id}/approve
  ///
  /// Approves a submitted task. Returns the updated task.
  Future<Task> approveTask(int id) async {
    final response =
        await _api.post<Map<String, dynamic>>('/admin/tasks/$id/approve');
    return _parseTaskFromActionResponse(response.data);
  }

  /// POST /api/admin/tasks/{id}/cancel
  ///
  /// Cancels a task. Backend requires reason >=10 chars.
  Future<Task> cancelTask(int id, {required String reason}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/tasks/$id/cancel',
      data: {'reason': reason},
    );
    return _parseTaskFromActionResponse(response.data);
  }

  /// POST /api/admin/tasks/{id}/request-changes
  ///
  /// Asks the leader to redo work. Backend requires note >=10 chars.
  Future<Task> requestChanges(int id, {required String note}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/tasks/$id/request-changes',
      data: {'note': note},
    );
    return _parseTaskFromActionResponse(response.data);
  }

  /// Helper: action endpoints return updated task wrapped in
  /// {"task": {...}} OR {"data": {...}} OR raw {...}.
  Task _parseTaskFromActionResponse(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException(
        message: 'Empty response from server after action.',
      );
    }
    final taskJson =
        (body['task'] ?? body['data'] ?? body) as Map<String, dynamic>;
    return Task.fromJson(taskJson);
  }
}

/// Input for one assignee when creating a task.
class TaskAssigneeInput {
  final int userId;
  final bool isLeader;

  const TaskAssigneeInput({required this.userId, this.isLeader = false});
}

