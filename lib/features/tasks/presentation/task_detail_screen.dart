import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_status.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../../../shared/widgets/task_priority_chip.dart';
import '../../../shared/widgets/task_status_badge.dart';
import '../../../shared/widgets/client_avatar.dart';
import '../../auth/data/auth_providers.dart';
import '../data/comments_providers.dart';
import '../data/tasks_providers.dart';
import 'widgets/attachments_section.dart';
import 'widgets/task_action_bar.dart';

/// Task detail screen — full info for a single task.
class TaskDetailScreen extends ConsumerWidget {
  final int taskId;

  const TaskDetailScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));

    final authState = ref.watch(authStateProvider);
    final userId =
        (authState is AuthAuthenticated) ? authState.user.id : null;

    final title = taskAsync.maybeWhen(
      data: (task) => task.client?.name ?? task.title,
      orElse: () => 'Task Detail',
    );

    return Scaffold(
      appBar: AppBar(
        title: Text(title, overflow: TextOverflow.ellipsis),
      ),
      body: taskAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.brandPrimary,
            ),
          ),
        ),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
        data: (task) => _TaskDetailContent(task: task),
      ),
      bottomNavigationBar: taskAsync.when(
        loading: () => null,
        error: (_, _) => null,
        data: (task) =>
            TaskActionBar(task: task, currentUserId: userId),
      ),
      floatingActionButton: taskAsync.maybeWhen(
        data: (task) => _DetailFabStack(task: task, currentUserId: userId),
        orElse: () => null,
      ),
    );
  }
}

/// Three small stacked FABs at the bottom-right of the task detail
/// screen. Top-to-bottom: Assignees, Comments, Attach. The Attach FAB
/// is only shown when the current user is the leader AND the task is
/// in a state where uploads are accepted. The Comments FAB shows a
/// red unread-count badge when there are new messages from others.
///
/// While this widget is mounted, it polls the comments endpoint so
/// the badge can update without the user having to open the chat.
/// Platforms with FCM (iOS / Android) poll slowly because push covers
/// freshness; platforms without FCM (macOS / web) poll faster.
class _DetailFabStack extends ConsumerStatefulWidget {
  final Task task;
  final int? currentUserId;

  const _DetailFabStack({required this.task, required this.currentUserId});

  @override
  ConsumerState<_DetailFabStack> createState() => _DetailFabStackState();
}

class _DetailFabStackState extends ConsumerState<_DetailFabStack> {
  Timer? _pollTimer;

  static Duration get _pollInterval {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return const Duration(seconds: 5);
    }
    return const Duration(seconds: 30);
  }

  @override
  void initState() {
    super.initState();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      ref.invalidate(taskCommentsProvider(widget.task.id));
    });
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }

  bool get _canAttach {
    final id = widget.currentUserId;
    if (id == null) return false;
    if (!widget.task.isLeaderUser(id)) return false;
    return widget.task.status == TaskStatus.inProgress ||
        widget.task.status == TaskStatus.changesRequested;
  }

  @override
  Widget build(BuildContext context) {
    final taskId = widget.task.id;
    final unread = ref.watch(unreadCommentsCountProvider(taskId));

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        FloatingActionButton.small(
          heroTag: 'fab-assignees-$taskId',
          tooltip: 'Assignees',
          backgroundColor: Colors.white,
          foregroundColor: AppTheme.brandPrimaryDark,
          elevation: 2,
          onPressed: () => context.push(
            AppRoute.taskAssigneesPath(taskId),
          ),
          child: const Icon(Icons.people_alt_outlined),
        ),
        const SizedBox(height: 12),
        _BadgedFab(
          heroTag: 'fab-comments-$taskId',
          tooltip: 'Comments',
          icon: Icons.chat_bubble_outline_rounded,
          badgeCount: unread,
          onPressed: () => context.push(
            AppRoute.taskCommentsPath(taskId),
          ),
        ),
        if (_canAttach) ...[
          const SizedBox(height: 12),
          FloatingActionButton.small(
            heroTag: 'fab-attach-$taskId',
            tooltip: 'Attach files',
            backgroundColor: Colors.white,
            foregroundColor: AppTheme.brandPrimaryDark,
            elevation: 2,
            onPressed: () => context.push(
              AppRoute.taskAttachPath(taskId),
            ),
            child: const Icon(Icons.add),
          ),
        ],
      ],
    );
  }
}

class _BadgedFab extends StatelessWidget {
  final String heroTag;
  final String tooltip;
  final IconData icon;
  final int badgeCount;
  final VoidCallback onPressed;

  const _BadgedFab({
    required this.heroTag,
    required this.tooltip,
    required this.icon,
    required this.badgeCount,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton.small(
      heroTag: heroTag,
      tooltip: tooltip,
      backgroundColor: Colors.white,
      foregroundColor: AppTheme.brandPrimaryDark,
      elevation: 2,
      onPressed: onPressed,
      child: Icon(icon),
    );

    if (badgeCount <= 0) return fab;

    final label = badgeCount > 99 ? '99+' : '$badgeCount';

    return Stack(
      clipBehavior: Clip.none,
      children: [
        fab,
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
            padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
            decoration: BoxDecoration(
              color: AppTheme.error,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: Colors.white, width: 2),
            ),
            alignment: Alignment.center,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 10,
                fontWeight: FontWeight.w700,
                height: 1.1,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// --- Error view ---

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.cloud_off, size: 56, color: AppTheme.error),
        const SizedBox(height: 16),
        Text(
          'Could not load task',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.slate500,
              ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: onRetry,
          child: const Text('Retry'),
        ),
      ],
    );
  }
}

// --- Main content ---

class _TaskDetailContent extends StatelessWidget {
  final Task task;

  const _TaskDetailContent({required this.task});

  @override
  Widget build(BuildContext context) {
    final hasDescription =
        (task.description?.trim().isNotEmpty ?? false);

    return ListView(
      // Bottom padding makes room for the stacked FABs above the
      // action bar so the last card isn't hidden behind them.
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 120),
      children: [
        _HeaderCard(task: task),
        if (hasDescription) ...[
          const SizedBox(height: 12),
          _DescriptionCard(task: task),
        ],
        const SizedBox(height: 12),
        _ClientCard(task: task),
        const SizedBox(height: 12),
        AttachmentsSection(task: task),
      ],
    );
  }
}

// --- Sections ---

class _HeaderCard extends StatelessWidget {
  final Task task;

  const _HeaderCard({required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              task.title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                TaskStatusBadge(status: task.status),
                TaskPriorityChip(priority: task.priority),
                if (task.deadlineDate != null)
                  _DeadlineLabel(
                    dateStr: task.deadlineDate!,
                    timeStr: task.deadlineTime,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _DescriptionCard extends StatelessWidget {
  final Task task;

  const _DescriptionCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final description = task.description?.trim();
    final hasDescription = description != null && description.isNotEmpty;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Description'),
            const SizedBox(height: 8),
            Text(
              hasDescription ? description : 'No description provided.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: hasDescription
                        ? AppTheme.slate900
                        : AppTheme.slate500,
                    fontStyle:
                        hasDescription ? FontStyle.normal : FontStyle.italic,
                    height: 1.5,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCard extends StatelessWidget {
  final Task task;

  const _ClientCard({required this.task});

  @override
  Widget build(BuildContext context) {
    final clientName = task.client?.name ?? '—';
    final branchName = task.clientBranch?.name;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            ClientAvatar(
              name: clientName,
              logoUrl: task.client?.logo,
              radius: 22,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    clientName,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                  ),
                  if (branchName != null && branchName.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      branchName,
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.slate500,
                              ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DeadlineLabel extends StatelessWidget {
  final String dateStr;
  final String? timeStr;

  const _DeadlineLabel({required this.dateStr, required this.timeStr});

  @override
  Widget build(BuildContext context) {
    final color = _color();
    final formatted = _format();

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.3), width: 1),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.schedule, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            formatted,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Color _color() {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return AppTheme.slate500;
    final daysAway = date.difference(DateTime.now()).inDays;
    if (daysAway < 0) return AppTheme.error;
    if (daysAway <= 1) return AppTheme.warning;
    return AppTheme.slate500;
  }

  String _format() {
    final date = DateTime.tryParse(dateStr);
    if (date == null) return dateStr;
    final f = DateFormat('MMM d, yyyy');
    if (timeStr == null || timeStr!.isEmpty) return f.format(date);
    final t = timeStr!.length >= 5 ? timeStr!.substring(0, 5) : timeStr!;
    return '${f.format(date)} $t';
  }
}

