import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/agency_client.dart';

/// Repository for admin clients + branches.
///
/// Client endpoints:
///   GET    /api/admin/clients           → paginated list (no branches)
///   POST   /api/admin/clients           → create
///   GET    /api/admin/clients/{id}      → detail with branches
///   PUT    /api/admin/clients/{id}      → update (incl. status)
///   DELETE /api/admin/clients/{id}      → archive (409 if already archived)
///
/// Branch endpoints:
///   GET    /api/admin/branches          → paginated list (?client_id filter)
///   POST   /api/admin/branches          → create
///   GET    /api/admin/branches/{id}     → detail
///   PUT    /api/admin/branches/{id}     → update (cannot move between clients)
///   DELETE /api/admin/branches/{id}     → hard delete (no archive)
class AdminClientsRepository {
  final ApiClient _api;

  AdminClientsRepository(this._api);

  // ========================================================================
  // Clients
  // ========================================================================

  /// GET /api/admin/clients?include_archived=1
  ///
  /// Returns ALL clients (active, inactive, archived). The backend
  /// hides archived ones by default — `?include_archived=1` overrides
  /// that. Filtering by status is the caller's job: admin Clients tab
  /// uses the archived rows for its "Show archived" toggle, while the
  /// create-task dropdown filters them out.
  Future<List<AgencyClient>> listClients() async {
    final response = await _api.get<Map<String, dynamic>>(
      '/admin/clients',
      query: {'include_archived': '1'},
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final rawList = (body['data'] ?? body['clients'] ?? const <dynamic>[]) as List;
    return rawList
        .map((c) => AgencyClient.fromJson(c as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/admin/clients/{id}
  ///
  /// Returns the client WITH branches eager-loaded. Use this once the user
  /// has selected a client in the form to populate the branch dropdown.
  Future<AgencyClient> getClientWithBranches(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/clients/$id');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final clientJson = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyClient.fromJson(clientJson);
  }

  /// POST /api/admin/clients
  Future<AgencyClient> createClient(AgencyClient client) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/clients',
      data: client.toJsonForCreate(),
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final clientJson = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyClient.fromJson(clientJson);
  }

  /// PUT /api/admin/clients/{id}
  Future<AgencyClient> updateClient(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/clients/$id',
      data: changes,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final clientJson = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyClient.fromJson(clientJson);
  }

  /// DELETE /api/admin/clients/{id} — archive (status='archived').
  ///
  /// Throws ApiException(409) with code 'already_archived' if already done.
  /// UI handles message display.
  Future<void> archiveClient(int id) async {
    await _api.delete<Map<String, dynamic>>('/admin/clients/$id');
  }

  /// PUT /api/admin/clients/{id} with {status: 'active'}.
  ///
  /// No dedicated reactivate endpoint; the regular update handles it.
  Future<AgencyClient> reactivateClient(int id) async {
    return updateClient(id, {'status': 'active'});
  }

  // ========================================================================
  // Branches
  // ========================================================================

  /// GET /api/admin/branches[?client_id=...]
  Future<List<AgencyClientBranch>> listBranches({int? clientId}) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/admin/branches',
      query: clientId == null ? null : {'client_id': clientId},
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final rawList =
        (body['data'] ?? body['branches'] ?? const <dynamic>[]) as List;
    return rawList
        .map((b) => AgencyClientBranch.fromJson(b as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/admin/branches/{id}
  Future<AgencyClientBranch> getBranch(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/branches/$id');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final branchJson = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyClientBranch.fromJson(branchJson);
  }

  /// POST /api/admin/branches
  ///
  /// Throws ApiException(422) if the parent client is archived.
  Future<AgencyClientBranch> createBranch(AgencyClientBranch branch) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/branches',
      data: branch.toJsonForCreate(),
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final branchJson = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyClientBranch.fromJson(branchJson);
  }

  /// PUT /api/admin/branches/{id}
  Future<AgencyClientBranch> updateBranch(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/branches/$id',
      data: changes,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final branchJson = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyClientBranch.fromJson(branchJson);
  }

  /// DELETE /api/admin/branches/{id} — hard delete.
  Future<void> deleteBranch(int id) async {
    await _api.delete<Map<String, dynamic>>('/admin/branches/$id');
  }
}
