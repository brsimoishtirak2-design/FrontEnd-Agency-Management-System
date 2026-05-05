import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/app_notification.dart';

/// Repository for the in-app notifications inbox.
///
/// Endpoints (all under /api/notifications, auth:sanctum + password.changed):
///   GET    /                       — paginated list, most recent first
///   GET    /unread-count           — bell badge count
///   POST   /mark-all-read          — bulk mark all as read
///   POST   /{id}/read              — mark one as read
///   DELETE /{id}                   — delete one
class NotificationsRepository {
  final ApiClient _api;

  NotificationsRepository(this._api);

  /// GET /api/notifications
  Future<List<AppNotification>> list({bool unreadOnly = false}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/notifications',
      query: unreadOnly ? {'unread_only': true} : null,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final raw = (body['data'] ?? const <dynamic>[]) as List;
    return raw
        .map((j) => AppNotification.fromJson(j as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// GET /api/notifications/unread-count
  Future<int> unreadCount() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/notifications/unread-count',
    );
    final body = response.data;
    if (body == null) return 0;
    return (body['unread_count'] as int?) ?? 0;
  }

  /// POST /api/notifications/{id}/read
  Future<void> markRead(int id) async {
    await _api.post<Map<String, dynamic>>('/notifications/$id/read');
  }

  /// POST /api/notifications/mark-all-read
  Future<int> markAllRead() async {
    final response = await _api.post<Map<String, dynamic>>(
      '/notifications/mark-all-read',
    );
    return (response.data?['updated_count'] as int?) ?? 0;
  }

  /// DELETE /api/notifications/{id}
  Future<void> delete(int id) async {
    await _api.delete<Map<String, dynamic>>('/notifications/$id');
  }
}
