import 'dart:io' show Platform;

import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/messaging/fcm_handlers.dart';
import 'core/messaging/fcm_service.dart';
import 'core/router/app_router.dart';
import 'core/theme/app_theme.dart';
import 'features/auth/data/auth_providers.dart';
import 'features/devices/data/devices_providers.dart';
import 'firebase_options.dart';

/// Provider for FcmService. Defined here in main.dart for tight coupling
/// with the auth-state listener — could be moved to a separate file later.
final fcmServiceProvider = Provider<FcmService>((ref) {
  final devicesRepo = ref.watch(devicesRepositoryProvider);
  return FcmService(devicesRepo);
});

/// True if Firebase is configured for the current platform.
/// We only configured Android + iOS via flutterfire — macOS/web/desktop skip.
bool get _firebaseSupported =>
    !kIsWeb && (Platform.isIOS || Platform.isAndroid);

Future<void> main() async {
  // Required when calling async APIs before runApp.
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase only on iOS + Android. macOS/web/desktop launches skip it
  // (firebase_options.dart throws UnsupportedError for those platforms).
  if (_firebaseSupported) {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  }

  runApp(const ProviderScope(child: AgencyManagementApp()));
}

class AgencyManagementApp extends ConsumerStatefulWidget {
  const AgencyManagementApp({super.key});

  @override
  ConsumerState<AgencyManagementApp> createState() =>
      _AgencyManagementAppState();
}

class _AgencyManagementAppState extends ConsumerState<AgencyManagementApp> {
  bool _fcmRegistered = false;

  @override
  void initState() {
    super.initState();
    // Bootstrap auth state on app launch — checks for saved token, calls /me.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authStateProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final router = ref.watch(routerProvider);

    // Side-effect listener: when auth becomes Authenticated, register FCM.
    // Guarded by _fcmRegistered so we only do it once per app session.
    ref.listen<AuthState>(authStateProvider, (previous, next) {
      if (next is AuthAuthenticated && !_fcmRegistered) {
        _fcmRegistered = true;
        // Fire-and-forget — never blocks the UI.
        ref.read(fcmServiceProvider).registerWithBackend();
      }
      if (next is AuthUnauthenticated) {
        _fcmRegistered = false;
      }
    });

    return FcmHandlers(
      child: MaterialApp.router(
        title: 'Agency Management',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.light,
        routerConfig: router,
      ),
    );
  }
}
