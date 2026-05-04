import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/agency_user.dart';

/// Repository for admin user management — full CRUD.
///
/// Endpoints:
///   GET    /api/admin/users                                  → list (filters)
///   POST   /api/admin/users                                  → create
///   GET    /api/admin/users/{id}                             → detail
///   PUT    /api/admin/users/{id}                             → update
///   DELETE /api/admin/users/{id}                             → deactivate
///                                                              (NOT hard delete)
///   POST   /api/admin/users/{id}/reset-password              → admin-set password
///
/// Self-protection: PUT/DELETE on the calling admin's own row returns
/// 403 with code='self_deactivate_blocked' or 'self_role_change_blocked'.
/// `ApiException` propagates with `e.code` for the UI to switch on.
class AdminUsersRepository {
  final ApiClient _api;

  AdminUsersRepository(this._api);

  /// GET /api/admin/users with optional filters.
  ///
  /// `includeInactive` defaults true — admin's own list view sees
  /// everyone by default. The assignee picker uses
  /// listActiveEmployees() which restricts further.
  Future<List<AgencyUser>> listUsers({
    String? role,
    int? locationId,
    int? departmentId,
    int? jobTitleId,
    bool? isActive,
    String? search,
    bool includeInactive = true,
  }) async {
    final query = <String, dynamic>{};
    if (role != null) query['role'] = role;
    if (locationId != null) query['location_id'] = locationId;
    if (departmentId != null) query['department_id'] = departmentId;
    if (jobTitleId != null) query['job_title_id'] = jobTitleId;
    if (isActive != null) query['is_active'] = isActive ? '1' : '0';
    if (search != null && search.isNotEmpty) query['search'] = search;
    if (includeInactive) query['include_inactive'] = '1';

    final response = await _api.get<Map<String, dynamic>>(
      '/admin/users',
      query: query.isEmpty ? null : query,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final rawList = (body['data'] ?? body['users'] ?? const <dynamic>[]) as List;
    return rawList
        .map((u) => AgencyUser.fromJson(u as Map<String, dynamic>))
        .toList();
  }

  /// Slim helper for the assignee picker. Equivalent to
  /// listUsers(role: 'employee', isActive: true) with a defensive
  /// client-side filter.
  Future<List<AgencyUser>> listActiveEmployees() async {
    final users = await listUsers(
      role: 'employee',
      isActive: true,
      includeInactive: false,
    );
    return users.where((u) => u.isActive && u.role == 'employee').toList();
  }

  /// GET /api/admin/users/{id}
  Future<AgencyUser> getUser(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/users/$id');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyUser.fromJson(json);
  }

  /// POST /api/admin/users
  ///
  /// Throws ApiException(422) on validation errors (email taken,
  /// dept-not-in-location, etc.). Backend defaults
  /// must_change_password=true automatically.
  Future<AgencyUser> createUser(AgencyUser user, String password) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/users',
      data: user.toJsonForCreate(password: password),
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyUser.fromJson(json);
  }

  /// PUT /api/admin/users/{id}
  ///
  /// Throws ApiException(403, code='self_deactivate_blocked') if the
  /// admin tries to deactivate themselves, or
  /// (403, code='self_role_change_blocked') if they try to change
  /// their own role. UI catches and shows the message.
  Future<AgencyUser> updateUser(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/users/$id',
      data: changes,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyUser.fromJson(json);
  }

  /// DELETE /api/admin/users/{id} — soft deactivate.
  ///
  /// Sets is_active=false and revokes all of that user's auth tokens.
  /// Possible errors:
  ///   - 403 code='self_deactivate_blocked' (deactivating yourself)
  ///   - 409 code='already_deactivated'
  Future<void> deactivateUser(int id) async {
    await _api.delete<Map<String, dynamic>>('/admin/users/$id');
  }

  /// PUT /api/admin/users/{id} with {is_active: true}.
  Future<AgencyUser> reactivateUser(int id) async {
    return updateUser(id, {'is_active': true});
  }

  /// POST /api/admin/users/{id}/reset-password
  ///
  /// Sets the user's password to `newPassword` and forces them to
  /// change it on next login. All their existing auth tokens are
  /// revoked server-side.
  Future<void> resetPassword(int id, String newPassword) async {
    await _api.post<Map<String, dynamic>>(
      '/admin/users/$id/reset-password',
      data: {'new_password': newPassword},
    );
  }
}
