import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/agency_department.dart';

/// Repository for admin department reference data — full CRUD.
///
/// Endpoints:
///   GET    /api/admin/departments           → paginated list (location loaded)
///   POST   /api/admin/departments           → create
///   GET    /api/admin/departments/{id}      → detail
///   PUT    /api/admin/departments/{id}      → update (allows moving location)
///   DELETE /api/admin/departments/{id}      → hard delete
///                                             (409 has_dependent_users
///                                              if any users are in this dept)
///
/// Compound uniqueness on (name, location_id) — backend returns 422
/// with errors.name on conflict.
class AdminDepartmentsRepository {
  final ApiClient _api;

  AdminDepartmentsRepository(this._api);

  Future<List<AgencyDepartment>> listDepartments() async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/departments');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final rawList =
        (body['data'] ?? body['departments'] ?? const <dynamic>[]) as List;
    return rawList
        .map((d) => AgencyDepartment.fromJson(d as Map<String, dynamic>))
        .toList();
  }

  Future<AgencyDepartment> getDepartment(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/departments/$id');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyDepartment.fromJson(json);
  }

  Future<AgencyDepartment> createDepartment(AgencyDepartment dept) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/departments',
      data: dept.toJsonForCreate(),
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyDepartment.fromJson(json);
  }

  Future<AgencyDepartment> updateDepartment(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/departments/$id',
      data: changes,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyDepartment.fromJson(json);
  }

  Future<void> deleteDepartment(int id) async {
    await _api.delete<Map<String, dynamic>>('/admin/departments/$id');
  }

  Future<AgencyDepartment> archiveDepartment(int id) async {
    return updateDepartment(id, {'is_active': false});
  }

  Future<AgencyDepartment> reactivateDepartment(int id) async {
    return updateDepartment(id, {'is_active': true});
  }
}
