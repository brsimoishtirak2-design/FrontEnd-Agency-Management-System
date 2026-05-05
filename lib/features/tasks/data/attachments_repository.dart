import 'package:dio/dio.dart';

import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/attachment.dart';

/// Repository for task attachment endpoints.
///
/// Endpoints used:
///   GET    /api/tasks/{taskId}/attachments
///   POST   /api/tasks/{taskId}/attachments         (employee submission)
///   POST   /api/admin/tasks/{taskId}/attachments   (admin brief — not used by mobile yet)
///   DELETE /api/tasks/{taskId}/attachments/{id}
///   GET    /api/attachments/{id}/download          (returns raw binary)
class AttachmentsRepository {
  final ApiClient _api;

  AttachmentsRepository(this._api);

  /// GET /api/tasks/{taskId}/attachments
  ///
  /// Backend returns Laravel paginator { data: [...], total, ... }.
  Future<List<Attachment>> listForTask(int taskId) async {
    final response = await _api.get<Map<String, dynamic>>(
      '/tasks/$taskId/attachments',
    );

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final rawList =
        (body['data'] ?? body['attachments'] ?? const <dynamic>[]) as List;

    return rawList
        .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/tasks/{taskId}/attachments
  ///
  /// Employee submission upload. Backend gates this to in_progress or
  /// changes_requested status — uploads on submitted/approved/cancelled
  /// will return 409.
  ///
  /// Accepts a list of [filePaths] from the device. Each path must be a
  /// real file the OS can read.
  ///
  /// Returns the list of created attachments (one per uploaded file).
  Future<List<Attachment>> uploadSubmission({
    required int taskId,
    required List<String> filePaths,
  }) async {
    if (filePaths.isEmpty) {
      throw const ApiException(message: 'No files selected.');
    }

    final formData = FormData.fromMap({
      'purpose': 'submission',
      'files[]': [
        for (final path in filePaths) await MultipartFile.fromFile(path),
      ],
    });

    final response = await _api.post<Map<String, dynamic>>(
      '/tasks/$taskId/attachments',
      data: formData,
    );

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final rawList = (body['data'] ?? const <dynamic>[]) as List;
    return rawList
        .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/admin/tasks/{taskId}/attachments
  ///
  /// Admin brief upload. Used at task creation time to attach reference
  /// files the assignees will see under the "Brief" group on the task
  /// detail screen. Backend stores them with purpose=brief.
  Future<List<Attachment>> uploadBrief({
    required int taskId,
    required List<String> filePaths,
  }) async {
    if (filePaths.isEmpty) {
      throw const ApiException(message: 'No files selected.');
    }

    final formData = FormData.fromMap({
      'files[]': [
        for (final path in filePaths) await MultipartFile.fromFile(path),
      ],
    });

    final response = await _api.post<Map<String, dynamic>>(
      '/admin/tasks/$taskId/attachments',
      data: formData,
    );

    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final rawList = (body['data'] ?? const <dynamic>[]) as List;
    return rawList
        .map((a) => Attachment.fromJson(a as Map<String, dynamic>))
        .toList();
  }

  /// DELETE /api/tasks/{taskId}/attachments/{id}
  ///
  /// Only the original uploader (or admin) can delete.
  Future<void> delete({required int taskId, required int attachmentId}) async {
    await _api.delete<Map<String, dynamic>>(
      '/tasks/$taskId/attachments/$attachmentId',
    );
  }

  /// GET /api/attachments/{id}/download
  ///
  /// Returns the raw binary bytes. The mobile UI saves these to a temp
  /// file using the original file name and opens with the system viewer.
  ///
  /// We bypass the typed _api.get wrapper here because that wrapper
  /// expects JSON — for binary downloads we need direct Dio access with
  /// responseType: ResponseType.bytes.
  Future<List<int>> downloadBytes(int attachmentId) async {
    try {
      final response = await _api.raw.get<List<int>>(
        '/attachments/$attachmentId/download',
        options: Options(responseType: ResponseType.bytes),
      );

      final bytes = response.data;
      if (bytes == null) {
        throw const ApiException(message: 'Empty response from server.');
      }
      return bytes;
    } on DioException catch (e) {
      // Manual error mapping since we bypassed the typed wrapper.
      if (e.response == null) {
        throw const ApiException(
          message: 'Could not reach the server. Please try again.',
        );
      }
      final status = e.response!.statusCode;
      String message = 'Download failed.';
      if (e.response!.data is Map<String, dynamic>) {
        final m = e.response!.data['message'];
        if (m is String) message = m;
      }
      throw ApiException(message: message, statusCode: status);
    }
  }
}
