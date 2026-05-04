import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import '../../features/devices/data/devices_repository.dart';

/// Wraps firebase_messaging for our use case.
///
/// Responsibilities:
///   1. Request notification permissions (iOS — Android handles automatically)
///   2. Get the current FCM token
///   3. Register the token with our backend via DevicesRepository
///   4. Listen for token refresh and re-register
///
/// Does NOT yet handle incoming messages — that comes in the next stage.
class FcmService {
  final DevicesRepository _devicesRepo;

  /// Optional injected instance for testing. When null, we lazily resolve
  /// FirebaseMessaging.instance on first use — important on macOS/desktop
  /// where Firebase.initializeApp is skipped and instance access throws.
  final FirebaseMessaging? _injectedMessaging;

  /// Subscription to token refresh events. Held so we can cancel on logout.
  Stream<String>? _refreshStream;

  FcmService(this._devicesRepo, [FirebaseMessaging? messaging])
      : _injectedMessaging = messaging;

  /// Lazy accessor — only touches FirebaseMessaging.instance when actually
  /// needed (i.e., after the platform check in registerWithBackend).
  FirebaseMessaging get _messaging =>
      _injectedMessaging ?? FirebaseMessaging.instance;

  /// Request permission, fetch token, and register with backend.
  ///
  /// Safe to call multiple times — backend upserts on (user_id, token).
  /// Failures are caught and logged so they never bubble up to break
  /// the auth flow.
  ///
  /// No-op on macOS/desktop/web — Firebase isn't initialized there.
  Future<void> registerWithBackend() async {
    if (!Platform.isIOS && !Platform.isAndroid) {
      if (kDebugMode) {
        debugPrint('FCM: Skipping registration on unsupported platform.');
      }
      return;
    }

    try {
      // Step 1: Permissions (iOS prompt; Android <= 12 auto-grants;
      // Android 13+ also prompts but firebase_messaging handles it).
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );

      if (settings.authorizationStatus == AuthorizationStatus.denied) {
        if (kDebugMode) {
          debugPrint('FCM: User denied notification permission.');
        }
        return;
      }

      // Step 2: Get the token. May return null on iOS if APNs token
      // isn't ready yet — we handle that case quietly.
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        if (kDebugMode) {
          debugPrint('FCM: getToken() returned null. APNs may not be ready.');
        }
        return;
      }

      if (kDebugMode) {
        debugPrint('FCM: Got token, first 20 chars: ${token.substring(0, 20)}...');
      }

      // Step 3: Register with backend.
      await _devicesRepo.registerToken(
        fcmToken: token,
        deviceType: Platform.isIOS ? 'ios' : 'android',
        deviceName: _deviceLabel(),
      );

      if (kDebugMode) {
        debugPrint('FCM: Token registered with backend.');
      }

      // Step 4: Listen for refreshes so we re-register if the token rotates.
      _refreshStream = _messaging.onTokenRefresh;
      _refreshStream!.listen((newToken) async {
        if (kDebugMode) {
          debugPrint('FCM: Token refreshed, re-registering.');
        }
        try {
          await _devicesRepo.registerToken(
            fcmToken: newToken,
            deviceType: Platform.isIOS ? 'ios' : 'android',
            deviceName: _deviceLabel(),
          );
        } catch (e) {
          if (kDebugMode) {
            debugPrint('FCM: Token refresh re-registration failed: $e');
          }
        }
      });
    } catch (e) {
      // Swallow — FCM should never break login.
      if (kDebugMode) {
        debugPrint('FCM: registerWithBackend failed: $e');
      }
    }
  }

  /// Best-effort human-readable device label.
  /// We could integrate device_info_plus later for richer info; for now
  /// just OS name is sufficient.
  String _deviceLabel() {
    if (Platform.isIOS) return 'iOS device';
    if (Platform.isAndroid) return 'Android device';
    return 'Unknown';
  }
}
