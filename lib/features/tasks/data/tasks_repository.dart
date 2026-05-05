import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/task.dart';

/// Repository for the EMPLOYEE-side task endpoints (/api/tasks/*).
///
/// All methods throw [ApiException] on failure — UI layer catches and displays.
/// Admin-side task management endpoints (/api/admin/tasks/*) will live in a
/// separate AdminTasksRepository when we build admin features.
class TasksRepository {
  final ApiClient _api;

  TasksRepository(this._api);

  /// GET /api/tasks
  ///
  /// Returns the current employee's assigned tasks. Backend response is a
  /// Laravel paginated wrapper — we extract the `data` array.
  ///
  /// For now we ignore pagination metadata (current_page, total, etc.) since
  /// employees typically have <20 tasks. Will add pagination support later.
  Future<List<Task>> listMyTasks() async {
    final response = await _api.get<Map<String, dynamic>>('/tasks');

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    // Laravel paginator: { current_page, data: [...], total, ... }
    // Fall back gracefully if the shape ever changes to a bare array.
    final rawList = (body['data'] ?? body['tasks'] ?? const <dynamic>[]) as List;

    return rawList
        .map((t) => Task.fromJson(t as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/tasks/{id}
  ///
  /// Returns a single task with full detail (creator, full assignments, etc.).
  /// Backend response is { "data": {...} }.
  Future<Task> getTask(int id) async {
    final response = await _api.get<Map<String, dynamic>>('/tasks/$id');

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    // Detail endpoint wraps in { "data": {...} } — fall back to raw shape.
    final taskJson = (body['data'] ?? body) as Map<String, dynamic>;
    return Task.fromJson(taskJson);
  }

  /// POST /api/tasks/{id}/mark-viewed
  ///
  /// Records that the user has just opened the task detail screen so
  /// the "unseen" badges on the list clear next refresh. Fire-and-
  /// forget — failures are swallowed and surfaced via debug log only.
  Future<void> markViewed(int id) async {
    await _api.post<Map<String, dynamic>>('/tasks/$id/mark-viewed');
  }

  /// POST /api/tasks/{id}/start
  ///
  /// Transitions task from "assigned" → "in_progress". Leader-only.
  /// Returns the updated task.
  Future<Task> startTask(int id) async {
    final response = await _api.post<Map<String, dynamic>>('/tasks/$id/start');
    return _parseTaskFromActionResponse(response.data);
  }

  /// POST /api/tasks/{id}/submit
  ///
  /// Transitions task from "in_progress" → "submitted". Leader-only.
  /// Optional submission note. Returns the updated task.
  Future<Task> submitTask(int id, {String? note}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/tasks/$id/submit',
      data: {
        if (note != null && note.isNotEmpty) 'note': note,
      },
    );
    return _parseTaskFromActionResponse(response.data);
  }

  /// POST /api/tasks/{id}/re-progress
  ///
  /// Used after admin requests changes — moves "changes_requested" back to
  /// "in_progress". Leader-only. Returns the updated task.
  Future<Task> reProgressTask(int id) async {
    final response =
        await _api.post<Map<String, dynamic>>('/tasks/$id/re-progress');
    return _parseTaskFromActionResponse(response.data);
  }

  /// Helper: action endpoints (start/submit/re-progress) return the updated
  /// task wrapped in {"task": {...}} OR {"data": {...}} OR raw {...}.
  /// We accept all three shapes.
  Task _parseTaskFromActionResponse(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException(
        message: 'Empty response from server after action.',
      );
    }

    final taskJson = (body['task'] ?? body['data'] ?? body)
        as Map<String, dynamic>;
    return Task.fromJson(taskJson);
  }
}
