import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/comment.dart';

/// Repository for task comment endpoints.
///
/// All methods throw [ApiException] on failure.
class CommentsRepository {
  final ApiClient _api;

  CommentsRepository(this._api);

  /// GET /api/tasks/{taskId}/comments
  ///
  /// Returns the comments thread on a task. Backend returns Laravel
  /// paginator — we extract the `data` array.
  ///
  /// Note: backend paginates at 50 per page (vs 20 for tasks). Most threads
  /// will fit in one page. We'll add pagination later if needed.
  Future<List<Comment>> listForTask(int taskId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/tasks/$taskId/comments',
    );

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final rawList =
        (body['data'] ?? body['comments'] ?? const <dynamic>[]) as List;

    return rawList
        .map((c) => Comment.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/tasks/{taskId}/comments
  ///
  /// Posts a new comment. Returns the created comment.
  /// Response shape: { "data": {...} }
  Future<Comment> create({
    required int taskId,
    required String body,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/tasks/$taskId/comments',
      data: {'body': body},
    );

    return _parseSingle(response.data);
  }

  /// PUT /api/tasks/{taskId}/comments/{commentId}
  ///
  /// Edit a comment. Backend only allows authors to edit their own comments.
  /// Returns the updated comment.
  Future<Comment> update({
    required int taskId,
    required int commentId,
    required String body,
  }) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/tasks/$taskId/comments/$commentId',
      data: {'body': body},
    );

    return _parseSingle(response.data);
  }

  /// DELETE /api/tasks/{taskId}/comments/{commentId}
  ///
  /// Soft-deletes a comment. Backend only allows authors to delete their own
  /// comments. We don't parse the response body — we just refresh the list
  /// after success.
  Future<void> delete({
    required int taskId,
    required int commentId,
  }) async {
    await _api.delete<Map<String, dynamic>>(
      '/tasks/$taskId/comments/$commentId',
    );
  }

  /// Helper: parse a single comment that may be wrapped in {"data": {...}}
  /// or returned as the raw object.
  Comment _parseSingle(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final commentJson = (body['data'] ?? body) as Map<String, dynamic>;
    return Comment.fromJson(commentJson);
  }
}
