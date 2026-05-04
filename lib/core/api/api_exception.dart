/// Domain-level exception for API errors.
/// Wraps Dio's raw exceptions into something the UI can display directly.
class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final String? code;
  final Map<String, List<String>>? validationErrors;

  const ApiException({
    required this.message,
    this.statusCode,
    this.code,
    this.validationErrors,
  });

  /// User unauthorized (401) — token expired or never logged in.
  bool get isUnauthorized => statusCode == 401;

  /// Forbidden (403) — token valid but action not allowed.
  bool get isForbidden => statusCode == 403;

  /// Validation error (422) — has field-level errors.
  bool get isValidationError => statusCode == 422;

  /// No internet / DNS / connection refused.
  bool get isNetworkError => statusCode == null;

  /// Server crashed (5xx).
  bool get isServerError => statusCode != null && statusCode! >= 500;

  @override
  String toString() => 'ApiException($statusCode): $message';
}
