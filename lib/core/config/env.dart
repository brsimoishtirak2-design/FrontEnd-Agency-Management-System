/// Application environment configuration.
/// Single source of truth for environment-specific values.
class Env {
  Env._();

  /// Backend API base URL.
  static const String apiBaseUrl = 'https://employee-agency-system.brsimo.com';

  /// API version prefix (currently empty — backend doesn't version yet).
  static const String apiPath = '/api';

  /// Full API root URL.
  static String get apiRoot => '$apiBaseUrl$apiPath';

  /// HTTP timeout for API requests.
  static const Duration apiTimeout = Duration(seconds: 30);

  /// Whether to log all HTTP requests/responses (set false in production builds).
  static const bool debugLogging = true;
}
