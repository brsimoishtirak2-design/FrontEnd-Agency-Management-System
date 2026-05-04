import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_theme.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_assignment.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/utils/initials.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../data/tasks_providers.dart';

/// Read-only assignees list for a single task. Pushed from the task
/// detail screen via the people-icon FAB.
///
/// Shows each active assignee with their initials, name, leader pill,
/// who assigned them, and when. Inactive assignments (replaced /
/// removed) are listed below in a muted "Past assignments" section.
class TaskAssigneesScreen extends ConsumerWidget {
  final int taskId;

  const TaskAssigneesScreen({super.key, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final taskAsync = ref.watch(taskDetailProvider(taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Assignees')),
      body: taskAsync.when(
        loading: () => const Center(
          child: SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppTheme.brandPrimary,
            ),
          ),
        ),
        error: (error, _) => _Error(
          message: error.toString(),
          onRetry: () => ref.invalidate(taskDetailProvider(taskId)),
        ),
        data: (task) => _Body(task: task),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load assignees',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final Task task;
  const _Body({required this.task});

  @override
  Widget build(BuildContext context) {
    final active = task.assignments.where((a) => a.isActive).toList();
    final past = task.assignments.where((a) => !a.isActive).toList();

    if (active.isEmpty && past.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(24),
        child: Center(
          child: Text(
            'No assignees yet.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.slate500,
                  fontStyle: FontStyle.italic,
                ),
          ),
        ),
      );
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (task.title.isNotEmpty) ...[
          Text(
            task.title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
                  color: AppTheme.slate500,
                ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],
        if (active.isNotEmpty)
          _Section(
            title: 'Active · ${active.length}',
            children: [
              for (final a in active) _AssigneeTile(assignment: a),
            ],
          ),
        if (past.isNotEmpty) ...[
          const SizedBox(height: 16),
          _Section(
            title: 'Past assignments · ${past.length}',
            children: [
              for (final a in past)
                _AssigneeTile(assignment: a, muted: true),
            ],
          ),
        ],
      ],
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final List<Widget> children;
  const _Section({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.6,
                  ),
            ),
            const SizedBox(height: 8),
            for (var i = 0; i < children.length; i++) ...[
              children[i],
              if (i < children.length - 1)
                const Divider(height: 1, color: AppTheme.slate100),
            ],
          ],
        ),
      ),
    );
  }
}

class _AssigneeTile extends StatelessWidget {
  final TaskAssignment assignment;
  final bool muted;
  const _AssigneeTile({required this.assignment, this.muted = false});

  @override
  Widget build(BuildContext context) {
    final name =
        assignment.userName.isEmpty ? 'Unknown' : assignment.userName;
    final assignedBy = assignment.assignedByName;
    final assignedAt = formatDayDate(assignment.assignedAt);

    final metaParts = <String>[
      if (assignedBy != null && assignedBy.isNotEmpty) 'Assigned by $assignedBy',
      ?assignedAt,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          CircleAvatar(
            radius: 20,
            backgroundColor: muted
                ? AppTheme.slate100
                : AppTheme.brandPrimary.withValues(alpha: 0.12),
            child: Text(
              nameInitials(name),
              style: TextStyle(
                color: muted
                    ? AppTheme.slate500
                    : AppTheme.brandPrimaryDark,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: muted ? AppTheme.slate500 : AppTheme.slate900,
                      ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                if (metaParts.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    metaParts.join('  ·  '),
                    style:
                        Theme.of(context).textTheme.labelSmall?.copyWith(
                              color: AppTheme.slate500,
                            ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          if (assignment.isLeader && assignment.isActive) ...[
            const SizedBox(width: 8),
            AppStatusPill.brand('Leader'),
          ],
        ],
      ),
    );
  }

}
