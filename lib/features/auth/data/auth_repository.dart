import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../core/storage/secure_storage_service.dart';
import '../../../shared/models/user.dart';
import 'login_response.dart';

/// Bridge between auth-related API endpoints and persistent token storage.
///
/// All methods throw [ApiException] on failure (UI layer catches and displays).
/// Token persistence is handled here — UI never touches storage directly.
class AuthRepository {
  final ApiClient _api;
  final SecureStorageService _storage;

  AuthRepository(this._api, this._storage);

  /// POST /api/auth/login
  ///
  /// On success: persists token + user_id + must_change_password flag.
  /// Returns the parsed [LoginResponse].
  Future<LoginResponse> login({
    required String email,
    required String password,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/auth/login',
      data: {
        'email': email,
        'password': password,
      },
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    final loginResponse = LoginResponse.fromJson(data);

    // Persist auth state for next app launch
    await _storage.saveAuthToken(loginResponse.token);
    await _storage.saveUserId(loginResponse.user.id);
    await _storage.saveMustChangePassword(
      loginResponse.user.mustChangePassword,
    );

    return loginResponse;
  }

  /// GET /api/auth/me
  ///
  /// Fetches the current authenticated user. Used on app boot to verify
  /// the persisted token still works.
  Future<User> me() async {
    final response = await _api.get<Map<String, dynamic>>('/auth/me');

    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    // Backend returns { "user": {...} } for /auth/me.
    // Fall back to {"data": {...}} or raw {...} for resilience.
    final userJson = (data['user'] ?? data['data'] ?? data) as Map<String, dynamic>;
    return User.fromJson(userJson);
  }

  /// PUT /api/auth/me
  ///
  /// Self-service profile update — backend only accepts `name` and `phone`.
  /// All other fields are rejected with 422 by the backend's defense layer.
  /// Pass `null` for a field to leave it untouched (skip-null pattern).
  /// Returns the refreshed [User] from the backend (with eager-loaded
  /// location / department / job_title relations).
  Future<User> updateMe({String? name, String? phone}) async {
    final payload = <String, dynamic>{};
    if (name != null) payload['name'] = name;
    if (phone != null) payload['phone'] = phone;

    final response = await _api.put<Map<String, dynamic>>(
      '/auth/me',
      data: payload,
    );

    final data = response.data;
    if (data == null) {
      throw const ApiException(message: 'Empty response from server.');
    }

    // Same {user: {...}} envelope as GET /auth/me.
    final userJson =
        (data['user'] ?? data['data'] ?? data) as Map<String, dynamic>;
    return User.fromJson(userJson);
  }

  /// POST /api/auth/change-password
  ///
  /// Used both for forced first-login change AND voluntary later change.
  /// On success: clears the must_change_password flag.
  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/change-password',
      data: {
        'current_password': currentPassword,
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );

    // Backend clears must_change_password server-side; mirror it locally
    await _storage.saveMustChangePassword(false);
  }

  /// POST /api/auth/reset-password
  ///
  /// Self-service voluntary reset — does NOT require the current
  /// password. The authenticated session is the auth boundary.
  /// Distinct from [changePassword], which still requires the current
  /// password and powers the forced first-login flow.
  Future<void> resetPassword({
    required String newPassword,
    required String newPasswordConfirmation,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/auth/reset-password',
      data: {
        'new_password': newPassword,
        'new_password_confirmation': newPasswordConfirmation,
      },
    );
    await _storage.saveMustChangePassword(false);
  }

  /// POST /api/auth/logout
  ///
  /// Always clears local storage, even if the API call fails (e.g. expired
  /// token). The user is logged out either way from the device's perspective.
  Future<void> logout() async {
    try {
      await _api.post<Map<String, dynamic>>('/auth/logout');
    } on ApiException {
      // Swallow — we still want to clear local state below
    }
    await _storage.clearAll();
  }

  /// Returns true if a persisted token exists (cheap synchronous-ish check).
  /// Does NOT validate the token with the server — call [me] for that.
  Future<bool> hasStoredToken() async {
    final token = await _storage.readAuthToken();
    return token != null && token.isNotEmpty;
  }

  /// Returns the locally-persisted must_change_password flag.
  Future<bool> mustChangePassword() => _storage.readMustChangePassword();
}
