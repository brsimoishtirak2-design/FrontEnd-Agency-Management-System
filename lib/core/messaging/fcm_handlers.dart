import 'dart:io' show Platform;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/data/auth_providers.dart';
import '../../features/tasks/data/comments_providers.dart';
import '../router/app_router.dart';
import '../theme/app_theme.dart';

/// Mounts FCM message handlers at the root of the widget tree.
///
/// Three streams are wired up:
///   1. onMessage         — push arrives while app is in foreground
///   2. onMessageOpenedApp — user taps push while app is backgrounded
///   3. getInitialMessage  — user tapped push that cold-launched the app
///
/// All three resolve to the same routing logic: parse data['task_id'] →
/// navigate to /tasks/{id}. We only navigate when the user is authenticated;
/// if a push arrives or fires before auth is ready, we ignore it (the auth
/// flow's redirect logic will handle it cleanly).
///
/// This widget renders its child as-is — it's pure side-effects.
class FcmHandlers extends ConsumerStatefulWidget {
  final Widget child;

  const FcmHandlers({super.key, required this.child});

  @override
  ConsumerState<FcmHandlers> createState() => _FcmHandlersState();
}

class _FcmHandlersState extends ConsumerState<FcmHandlers> {
  @override
  void initState() {
    super.initState();

    // FCM handlers are only valid on platforms where Firebase.initializeApp
    // ran in main() — currently iOS and Android. Tests, web, macOS, and
    // desktop builds either skip Firebase init or don't support it, so we
    // bail early there. The widget still renders its child on every platform.
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return;
    }

    // 1. Foreground messages: app is open & visible.
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // 2. Tap-to-open while app was backgrounded (already running).
    FirebaseMessaging.onMessageOpenedApp.listen(_handleTappedMessage);

    // 3. Tap that cold-launched the app from terminated state.
    // Run after first frame so router/auth are ready.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkInitialMessage();
    });
  }

  Future<void> _checkInitialMessage() async {
    final initial = await FirebaseMessaging.instance.getInitialMessage();
    if (initial == null) return;
    if (kDebugMode) {
      debugPrint('FCM: app cold-launched from notification tap.');
    }
    // Wait briefly for auth bootstrap to complete before navigating.
    await Future<void>.delayed(const Duration(milliseconds: 600));
    _handleTappedMessage(initial);
  }

  void _handleForegroundMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
        'FCM foreground: ${message.notification?.title} | ${message.data}',
      );
    }

    final title = message.notification?.title ?? 'New notification';
    final taskId = _parseTaskId(message);
    final type = message.data['type']?.toString();

    // For comment notifications: invalidate the comments provider for
    // that task so any open comments screen pulls the new message
    // immediately without a manual refresh.
    if (taskId != null && type == 'comment_posted') {
      ref.invalidate(taskCommentsProvider(taskId));
    }

    // Don't show a redundant snackbar when the user is already viewing
    // the chat for the same task — the list itself updates. The
    // comments screen registers its taskId in [activeCommentsTaskProvider]
    // while it's mounted.
    if (taskId != null &&
        type == 'comment_posted' &&
        ref.read(activeCommentsTaskProvider) == taskId) {
      return;
    }

    final messenger = _scaffoldMessenger;
    if (messenger == null) return;

    messenger.clearSnackBars();
    messenger.showSnackBar(
      SnackBar(
        content: Text(title, maxLines: 2, overflow: TextOverflow.ellipsis),
        backgroundColor: AppTheme.brandPrimaryDark,
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 5),
        action: taskId == null
            ? null
            : SnackBarAction(
                label: 'View',
                textColor: Colors.white,
                onPressed: () => _routeForMessage(message, taskId),
              ),
      ),
    );
  }

  void _handleTappedMessage(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint('FCM tap: ${message.notification?.title} | ${message.data}');
    }

    final taskId = _parseTaskId(message);
    if (taskId == null) return;
    _routeForMessage(message, taskId);
  }

  /// Pick the right destination based on the notification's `type` field.
  /// `comment_posted` opens the chat; everything else falls back to the
  /// task detail screen.
  void _routeForMessage(RemoteMessage message, int taskId) {
    final type = message.data['type']?.toString();
    if (type == 'comment_posted') {
      _navigateTo(AppRoute.taskCommentsPath(taskId));
    } else {
      _navigateTo(AppRoute.taskDetailPath(taskId));
    }
  }

  /// Parse task_id from the data payload. Backend sends ALL data values
  /// as strings (FCM requirement), so we use int.tryParse.
  int? _parseTaskId(RemoteMessage message) {
    final raw = message.data['task_id'];
    if (raw == null) return null;
    if (raw is int) return raw;
    if (raw is String) return int.tryParse(raw);
    return null;
  }

  void _navigateTo(String path) {
    // Only navigate if the user is authenticated. Otherwise the router
    // would bounce them back to login anyway, and we'd risk a flicker.
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) {
      if (kDebugMode) {
        debugPrint('FCM: skipping navigate — user not authenticated.');
      }
      return;
    }

    final router = ref.read(routerProvider);
    if (kDebugMode) {
      debugPrint('FCM: navigating to $path');
    }
    router.push(path);
  }

  /// Reach the global ScaffoldMessenger via the app's NavigatorState.
  /// Returns null if no scaffold context is available yet (very early
  /// in app start) — caller bails gracefully.
  ScaffoldMessengerState? get _scaffoldMessenger {
    final ctx = _rootContext;
    if (ctx == null) return null;
    return ScaffoldMessenger.maybeOf(ctx);
  }

  BuildContext? get _rootContext {
    // The router exposes the most recent BuildContext via its routerDelegate.
    final router = ref.read(routerProvider);
    return router.routerDelegate.navigatorKey.currentContext;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
