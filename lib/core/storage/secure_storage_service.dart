import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Wraps flutter_secure_storage to provide a typed API for storing
/// auth-sensitive values (tokens, user IDs).
///
/// Backed by iOS Keychain on iOS/macOS and EncryptedSharedPreferences on Android.
/// Values are encrypted at rest by the OS — much safer than SharedPreferences.
class SecureStorageService {
  static const _keyAuthToken = 'auth_token';
  static const _keyUserId = 'user_id';
  static const _keyMustChangePassword = 'must_change_password';

  final FlutterSecureStorage _storage;

  SecureStorageService([FlutterSecureStorage? storage])
      : _storage = storage ?? const FlutterSecureStorage();

  // --- Auth token ---
  Future<void> saveAuthToken(String token) =>
      _storage.write(key: _keyAuthToken, value: token);

  Future<String?> readAuthToken() => _storage.read(key: _keyAuthToken);

  Future<void> deleteAuthToken() => _storage.delete(key: _keyAuthToken);

  // --- User ID ---
  Future<void> saveUserId(int id) =>
      _storage.write(key: _keyUserId, value: id.toString());

  Future<int?> readUserId() async {
    final value = await _storage.read(key: _keyUserId);
    return value == null ? null : int.tryParse(value);
  }

  // --- must_change_password flag ---
  Future<void> saveMustChangePassword(bool flag) =>
      _storage.write(key: _keyMustChangePassword, value: flag.toString());

  Future<bool> readMustChangePassword() async {
    final value = await _storage.read(key: _keyMustChangePassword);
    return value == 'true';
  }

  /// Wipes all auth-related values (used on logout or token rotation).
  Future<void> clearAll() async {
    await Future.wait([
      _storage.delete(key: _keyAuthToken),
      _storage.delete(key: _keyUserId),
      _storage.delete(key: _keyMustChangePassword),
    ]);
  }
}
