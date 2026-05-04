import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/agency_location.dart';

/// Repository for admin location reference data — full CRUD.
///
/// Endpoints:
///   GET    /api/admin/locations           → paginated list
///   POST   /api/admin/locations           → create
///   GET    /api/admin/locations/{id}      → detail (with departments)
///   PUT    /api/admin/locations/{id}      → update
///   DELETE /api/admin/locations/{id}      → hard delete (409 if linked)
///
/// 409 codes returned by the backend:
///   - has_dependent_users
///   - has_dependent_departments
/// Both arrive on `ApiException` as `e.statusCode == 409` and `e.code`
/// set to one of the above.
class AdminLocationsRepository {
  final ApiClient _api;

  AdminLocationsRepository(this._api);

  /// GET /api/admin/locations
  Future<List<AgencyLocation>> listLocations() async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/locations');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final rawList = (body['data'] ?? body['locations'] ?? const <dynamic>[])
        as List;
    return rawList
        .map((l) => AgencyLocation.fromJson(l as Map<String, dynamic>))
        .toList();
  }

  /// GET /api/admin/locations/{id}
  Future<AgencyLocation> getLocation(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/locations/$id');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyLocation.fromJson(json);
  }

  /// POST /api/admin/locations
  Future<AgencyLocation> createLocation(AgencyLocation location) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/locations',
      data: location.toJsonForCreate(),
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyLocation.fromJson(json);
  }

  /// PUT /api/admin/locations/{id}
  Future<AgencyLocation> updateLocation(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/locations/$id',
      data: changes,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyLocation.fromJson(json);
  }

  /// DELETE /api/admin/locations/{id}
  ///
  /// Throws ApiException(409, code='has_dependent_users' OR
  /// 'has_dependent_departments') if the location is in use. UI
  /// catches this and offers to archive instead.
  Future<void> deleteLocation(int id) async {
    await _api.delete<Map<String, dynamic>>('/admin/locations/$id');
  }

  /// PUT /api/admin/locations/{id} with {is_active: false}.
  Future<AgencyLocation> archiveLocation(int id) async {
    return updateLocation(id, {'is_active': false});
  }

  /// PUT /api/admin/locations/{id} with {is_active: true}.
  Future<AgencyLocation> reactivateLocation(int id) async {
    return updateLocation(id, {'is_active': true});
  }
}
