import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/app_notification.dart';
import 'notifications_repository.dart';

/// Repository singleton.
final notificationsRepositoryProvider = Provider<NotificationsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return NotificationsRepository(api);
});

/// Auto-fetched paginated list of notifications for the inbox screen.
/// Refresh: `ref.invalidate(notificationsListProvider)`.
final notificationsListProvider =
    FutureProvider<List<AppNotification>>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.list();
});

/// Bell-badge count. Lightweight separate fetch so it can update
/// independently from the inbox list. The FCM handler invalidates this
/// whenever a push arrives so the bell ticks up immediately.
final unreadNotificationsCountProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  return repo.unreadCount();
});
