import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/agency_job_title.dart';

/// Repository for admin job-title reference data — full CRUD.
///
/// Endpoints:
///   GET    /api/admin/job-titles           → paginated list
///   POST   /api/admin/job-titles           → create
///   GET    /api/admin/job-titles/{id}      → detail
///   PUT    /api/admin/job-titles/{id}      → update
///   DELETE /api/admin/job-titles/{id}      → hard delete
///                                            (409 has_dependent_users
///                                             if any users have this title)
class AdminJobTitlesRepository {
  final ApiClient _api;

  AdminJobTitlesRepository(this._api);

  Future<List<AgencyJobTitle>> listJobTitles() async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/job-titles');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final rawList =
        (body['data'] ?? body['job_titles'] ?? const <dynamic>[]) as List;
    return rawList
        .map((j) => AgencyJobTitle.fromJson(j as Map<String, dynamic>))
        .toList();
  }

  Future<AgencyJobTitle> getJobTitle(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/job-titles/$id');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyJobTitle.fromJson(json);
  }

  Future<AgencyJobTitle> createJobTitle(AgencyJobTitle jobTitle) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/job-titles',
      data: jobTitle.toJsonForCreate(),
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyJobTitle.fromJson(json);
  }

  Future<AgencyJobTitle> updateJobTitle(
    int id,
    Map<String, dynamic> changes,
  ) async {
    final response = await _api.put<Map<String, dynamic>>(
      '/admin/job-titles/$id',
      data: changes,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final json = (body['data'] ?? body) as Map<String, dynamic>;
    return AgencyJobTitle.fromJson(json);
  }

  Future<void> deleteJobTitle(int id) async {
    await _api.delete<Map<String, dynamic>>('/admin/job-titles/$id');
  }

  Future<AgencyJobTitle> archiveJobTitle(int id) async {
    return updateJobTitle(id, {'is_active': false});
  }

  Future<AgencyJobTitle> reactivateJobTitle(int id) async {
    return updateJobTitle(id, {'is_active': true});
  }
}
