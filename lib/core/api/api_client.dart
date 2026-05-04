import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import '../config/env.dart';
import '../storage/secure_storage_service.dart';
import 'api_exception.dart';

/// Centralized HTTP client for the backend API.
///
/// Features:
/// - Automatic auth token injection on every request
/// - Maps Dio errors to ApiException (so UI doesn't deal with Dio directly)
/// - Logs requests/responses in debug mode
class ApiClient {
  final Dio _dio;
  final SecureStorageService _storage;

  ApiClient(this._storage) : _dio = Dio() {
    _dio.options
      ..baseUrl = Env.apiRoot
      ..connectTimeout = Env.apiTimeout
      ..receiveTimeout = Env.apiTimeout
      ..sendTimeout = Env.apiTimeout
      ..headers.addAll({
        'Accept': 'application/json',
        'Content-Type': 'application/json',
      });

    _dio.interceptors.add(_authInterceptor());

    if (kDebugMode && Env.debugLogging) {
      _dio.interceptors.add(LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
      ));
    }
  }

  /// Returns the underlying Dio instance for advanced use cases.
  /// Most code should use the wrapped methods below.
  Dio get raw => _dio;

  // --- Wrapped HTTP methods that throw ApiException on failure ---

  Future<Response<T>> get<T>(String path, {Map<String, dynamic>? query}) async {
    try {
      return await _dio.get<T>(path, queryParameters: query);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> post<T>(String path, {dynamic data, Map<String, dynamic>? query}) async {
    try {
      return await _dio.post<T>(path, data: data, queryParameters: query);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> put<T>(String path, {dynamic data}) async {
    try {
      return await _dio.put<T>(path, data: data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  Future<Response<T>> delete<T>(String path, {dynamic data}) async {
    try {
      return await _dio.delete<T>(path, data: data);
    } on DioException catch (e) {
      throw _mapError(e);
    }
  }

  // --- Interceptors ---

  /// Adds the bearer token to every request (if available).
  Interceptor _authInterceptor() {
    return InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await _storage.readAuthToken();
        if (token != null && token.isNotEmpty) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    );
  }

  // --- Error mapping ---

  /// Converts a DioException into a domain-level ApiException.
  ApiException _mapError(DioException e) {
    // No response = network error (no internet, DNS fail, server down, timeout)
    if (e.response == null) {
      return ApiException(
        message: _networkMessage(e),
        statusCode: null,
      );
    }

    final status = e.response!.statusCode;
    final body = e.response!.data;

    // Parse Laravel-style error response: { "message": "...", "errors": {...} }
    String message = 'Something went wrong.';
    Map<String, List<String>>? validationErrors;
    String? code;

    if (body is Map<String, dynamic>) {
      if (body['message'] is String) {
        message = body['message'] as String;
      }
      if (body['code'] is String) {
        code = body['code'] as String;
      }
      if (body['errors'] is Map<String, dynamic>) {
        validationErrors = (body['errors'] as Map<String, dynamic>).map(
          (key, value) => MapEntry(
            key,
            (value as List).map((e) => e.toString()).toList(),
          ),
        );
      }
    }

    return ApiException(
      message: message,
      statusCode: status,
      code: code,
      validationErrors: validationErrors,
    );
  }

  String _networkMessage(DioException e) {
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        return 'Connection timed out. Please try again.';
      case DioExceptionType.connectionError:
        return 'No internet connection. Check your network and try again.';
      case DioExceptionType.cancel:
        return 'Request was cancelled.';
      case DioExceptionType.badCertificate:
        return 'Server certificate error.';
      case DioExceptionType.badResponse:
      case DioExceptionType.unknown:
        return 'Could not reach the server. Please try again.';
    }
  }
}
