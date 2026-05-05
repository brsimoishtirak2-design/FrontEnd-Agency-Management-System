import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/app_notification.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../data/notifications_providers.dart';

/// In-app notifications inbox. Shows every push the server has
/// recorded for the current user — read and unread — with the most
/// recent at the top. Tap a row to open the related task / chat;
/// swipe to delete; "Mark all read" in the AppBar.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final listAsync = ref.watch(notificationsListProvider);
    final unreadCount =
        ref.watch(unreadNotificationsCountProvider).maybeWhen(
              data: (c) => c,
              orElse: () => 0,
            );

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        actions: [
          if (unreadCount > 0)
            TextButton(
              onPressed: () async {
                try {
                  await ref
                      .read(notificationsRepositoryProvider)
                      .markAllRead();
                  ref.invalidate(notificationsListProvider);
                  ref.invalidate(unreadNotificationsCountProvider);
                } on ApiException catch (e) {
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(e.message),
                      backgroundColor: AppTheme.error,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              },
              child: const Text('Mark all read'),
            ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.brandPrimary,
        onRefresh: () async {
          ref.invalidate(notificationsListProvider);
          ref.invalidate(unreadNotificationsCountProvider);
          await ref.read(notificationsListProvider.future);
        },
        child: listAsync.when(
          loading: () => const Center(
            child: SizedBox(
              width: 24,
              height: 24,
              child: CircularProgressIndicator(
                strokeWidth: 2.5,
                color: AppTheme.brandPrimary,
              ),
            ),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState(
                title: 'Could not load notifications',
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(notificationsListProvider),
              ),
            ],
          ),
          data: (items) {
            if (items.isEmpty) {
              return LayoutBuilder(
                builder: (context, constraints) => SingleChildScrollView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      minHeight: constraints.maxHeight,
                    ),
                    child: const Center(
                      child: AppEmptyState(
                        icon: Icons.notifications_off_outlined,
                        title: 'You\'re all caught up',
                        subtitle: 'New notifications will appear here.',
                      ),
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 4),
              itemCount: items.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.slate100,
              ),
              itemBuilder: (context, index) {
                final n = items[index];
                return Dismissible(
                  key: ValueKey('notification-${n.id}'),
                  direction: DismissDirection.endToStart,
                  background: Container(
                    color: AppTheme.error,
                    alignment: Alignment.centerRight,
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.white,
                    ),
                  ),
                  onDismissed: (_) async {
                    try {
                      await ref
                          .read(notificationsRepositoryProvider)
                          .delete(n.id);
                      ref.invalidate(notificationsListProvider);
                      ref.invalidate(unreadNotificationsCountProvider);
                    } on ApiException catch (e) {
                      if (!context.mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(e.message),
                          backgroundColor: AppTheme.error,
                          behavior: SnackBarBehavior.floating,
                        ),
                      );
                    }
                  },
                  child: _NotificationRow(notification: n),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _NotificationRow extends ConsumerWidget {
  final AppNotification notification;

  const _NotificationRow({required this.notification});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final n = notification;
    final iconStyle = _styleFor(n.type);

    return InkWell(
      onTap: () async {
        // Optimistic mark-read on tap, then route.
        if (!n.isRead) {
          try {
            await ref
                .read(notificationsRepositoryProvider)
                .markRead(n.id);
            ref.invalidate(notificationsListProvider);
            ref.invalidate(unreadNotificationsCountProvider);
          } on ApiException {
            // Routing should still happen even if mark-read fails.
          }
        }
        if (!context.mounted) return;
        if (n.taskId != null) {
          if (n.opensComments) {
            context.push(AppRoute.taskCommentsPath(n.taskId!));
          } else {
            context.push(AppRoute.taskDetailPath(n.taskId!));
          }
        }
      },
      child: Container(
        // Subtle highlight for unread rows.
        color:
            n.isRead ? null : AppTheme.brandPrimary.withValues(alpha: 0.04),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 38,
              height: 38,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: iconStyle.color.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(iconStyle.icon, size: 18, color: iconStyle.color),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          n.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                fontWeight: n.isRead
                                    ? FontWeight.w500
                                    : FontWeight.w700,
                                color: AppTheme.slate900,
                              ),
                        ),
                      ),
                      if (!n.isRead) ...[
                        const SizedBox(width: 6),
                        Container(
                          width: 8,
                          height: 8,
                          decoration: const BoxDecoration(
                            color: AppTheme.brandPrimary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppTheme.slate700,
                          height: 1.35,
                        ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatRelativeTimestamp(n.createdAt),
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate500,
                        ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Map notification.type → (icon, color) for the leading badge.
  /// Keep in sync with backend Notification::TYPES.
  ({IconData icon, Color color}) _styleFor(String type) {
    switch (type) {
      case 'task_assigned':
        return (icon: Icons.assignment_ind_outlined, color: AppTheme.info);
      case 'task_reassigned_in':
      case 'task_reassigned_out':
      case 'leader_changed':
        return (icon: Icons.swap_horiz_rounded, color: AppTheme.info);
      case 'task_started':
        return (icon: Icons.play_arrow_rounded, color: AppTheme.success);
      case 'task_submitted':
        return (icon: Icons.send_rounded, color: AppTheme.brandPrimaryDark);
      case 'changes_requested':
        return (icon: Icons.edit_note_rounded, color: AppTheme.warning);
      case 'task_approved':
        return (icon: Icons.check_circle_outline_rounded, color: AppTheme.success);
      case 'task_cancelled':
        return (icon: Icons.cancel_outlined, color: AppTheme.error);
      case 'task_overdue':
        return (icon: Icons.warning_amber_rounded, color: AppTheme.error);
      case 'task_updated':
        return (icon: Icons.edit_rounded, color: AppTheme.warning);
      case 'brief_attached':
        return (icon: Icons.description_outlined, color: AppTheme.info);
      case 'submission_attached':
        return (icon: Icons.cloud_upload_outlined, color: AppTheme.info);
      case 'attachment_deleted':
        return (icon: Icons.delete_outline, color: AppTheme.slate500);
      case 'comment_posted':
        return (icon: Icons.chat_bubble_outline_rounded, color: AppTheme.brandPrimaryDark);
      case 'deadline_reminder':
        return (icon: Icons.schedule_rounded, color: AppTheme.warning);
      default:
        return (icon: Icons.notifications_none_rounded, color: AppTheme.slate500);
    }
  }
}
