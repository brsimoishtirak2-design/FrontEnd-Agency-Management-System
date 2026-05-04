import '../../../core/api/api_client.dart';

/// Repository for device-token registration with the backend.
///
/// Backend endpoint: POST /api/devices
/// Backend stores: user_id, fcm_token, device_type ('ios'|'android'),
/// device_name, last_used_at.
class DevicesRepository {
  final ApiClient _api;

  DevicesRepository(this._api);

  /// POST /api/devices
  ///
  /// Backend upserts on (user_id, fcm_token) — calling this multiple times
  /// with the same token is safe.
  ///
  /// We fire-and-forget; failures are logged by the caller but don't block
  /// the auth flow.
  Future<void> registerToken({
    required String fcmToken,
    required String deviceType, // 'ios' or 'android'
    required String deviceName,
  }) async {
    await _api.post<Map<String, dynamic>>(
      '/devices',
      data: {
        'fcm_token': fcmToken,
        'device_type': deviceType,
        'device_name': deviceName,
      },
    );
  }
}
