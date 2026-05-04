import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_assignment.dart';
import '../../../shared/models/task_priority.dart';
import '../../../shared/models/task_status.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_enter.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_list_panel.dart';
import '../../../shared/widgets/app_list_row.dart';
import '../../../shared/widgets/filter_chips_row.dart';
import '../../../shared/widgets/task_priority_chip.dart';
import '../../../shared/widgets/task_status_badge.dart';
import '../data/admin_tasks_providers.dart';

/// Admin Tasks tab — shows ALL tasks across the agency.
class AdminTasksScreen extends ConsumerWidget {
  const AdminTasksScreen({super.key});

  static final List<Task> _skeletonRows = List.generate(
    5,
    (i) => Task(
      id: i,
      title: 'Loading task title here',
      clientId: 0,
      priority: TaskPriority.medium,
      status: TaskStatus.assigned,
      isRecurring: false,
      createdBy: 0,
      createdAt: '',
      updatedAt: '',
      statusHistoryCount: 0,
      assignments: const <TaskAssignment>[],
    ),
  );

  static (Color bg, Color fg) _statusColors(TaskStatus s) {
    switch (s) {
      case TaskStatus.assigned:
        return (AppTheme.slate100, AppTheme.slate700);
      case TaskStatus.inProgress:
        return (AppTheme.info.withValues(alpha: 0.15), AppTheme.info);
      case TaskStatus.submitted:
        return (
          AppTheme.brandPrimary.withValues(alpha: 0.15),
          AppTheme.brandPrimaryDark
        );
      case TaskStatus.changesRequested:
        return (AppTheme.warning.withValues(alpha: 0.15), AppTheme.warning);
      case TaskStatus.approved:
        return (AppTheme.success.withValues(alpha: 0.15), AppTheme.success);
      case TaskStatus.overdue:
        return (AppTheme.error.withValues(alpha: 0.15), AppTheme.error);
      case TaskStatus.cancelled:
        return (AppTheme.slate100, AppTheme.slate500);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(adminAllTasksProvider);
    final filters = ref.watch(adminTasksFiltersProvider);
    final countsAsync = ref.watch(adminTaskStatusCountsProvider);
    final counts = countsAsync.maybeWhen(
      data: (m) => m,
      orElse: () => const <TaskStatus, int>{},
    );

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppTheme.brandPrimary,
        onRefresh: () async {
          ref.invalidate(adminAllTasksProvider);
          ref.invalidate(adminTaskStatusCountsProvider);
          await ref.read(adminAllTasksProvider.future);
        },
        child: Column(
          children: [
            const SizedBox(height: 8),
            _StatusFilterChips(
              selected: filters.status,
              counts: counts,
              onSelected: (v) {
                ref.read(adminTasksFiltersProvider.notifier).setStatus(v);
              },
            ),
            const SizedBox(height: 8),
            Expanded(
              child: tasksAsync.when(
                loading: () => Skeletonizer(
                  enabled: true,
                  child: _TasksPanel(tasks: _skeletonRows),
                ),
                error: (error, _) => ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  children: [
                    AppErrorState(
                      title: 'Could not load tasks',
                      message: error.toString(),
                      onRetry: () => ref.invalidate(adminAllTasksProvider),
                    ),
                  ],
                ),
                data: (tasks) {
                  if (tasks.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: [
                        if (filters.isEmpty)
                          const AppEmptyState(
                            icon: Icons.task_alt_outlined,
                            title: 'No tasks yet',
                            subtitle:
                                'Once tasks are created, they will appear here.',
                          )
                        else
                          _FilteredEmptyState(
                            onClear: () => ref
                                .read(adminTasksFiltersProvider.notifier)
                                .clear(),
                          ),
                      ],
                    );
                  }
                  return AppEnter(child: _TasksPanel(tasks: tasks));
                },
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.adminCreateTask),
        icon: const Icon(LucideIcons.plus),
        label: const Text('New Task'),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _StatusFilterChips extends StatelessWidget {
  final TaskStatus? selected;
  final Map<TaskStatus, int> counts;
  final ValueChanged<TaskStatus?> onSelected;

  const _StatusFilterChips({
    required this.selected,
    required this.counts,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final options = [
      for (final s in TaskStatus.values)
        FilterChipOption<TaskStatus>(
          value: s,
          label: s.displayName,
          activeColor: AdminTasksScreen._statusColors(s).$2,
          count: counts[s],
        ),
    ];
    return FilterChipsRow<TaskStatus>(
      options: options,
      selectedValue: selected,
      onSelected: onSelected,
    );
  }
}

class _FilteredEmptyState extends StatelessWidget {
  final VoidCallback onClear;
  const _FilteredEmptyState({required this.onClear});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
      child: Column(
        children: [
          Icon(
            Icons.search_off,
            size: 48,
            color: AppTheme.slate300,
          ),
          const SizedBox(height: 12),
          Text(
            'No tasks match your filters',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate700,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            'Try a different search term or status.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate500,
                ),
          ),
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: onClear,
            icon: const Icon(Icons.close, size: 16),
            label: const Text('Clear filters'),
          ),
        ],
      ),
    );
  }
}

class _TasksPanel extends StatelessWidget {
  final List<Task> tasks;
  const _TasksPanel({required this.tasks});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: AppListPanel(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: tasks.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.slate100,
          ),
          itemBuilder: (context, index) {
            final task = tasks[index];
            return AppListRow(
              onTap: () =>
                  context.push(AppRoute.taskDetailPath(task.id)),
              title: Text(
                task.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                _subtitleFor(task),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              meta: Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  TaskPriorityChip(priority: task.priority),
                  TaskStatusBadge(status: task.status),
                ],
              ),
              trailing: const Icon(
                LucideIcons.chevronRight,
                color: AppTheme.slate300,
              ),
            );
          },
        ),
      ),
    );
  }

  String _subtitleFor(Task task) {
    final assigneeNames = task.assignments
        .where((a) => a.isActive)
        .map((a) => a.userName)
        .toList();
    final assigneeText = assigneeNames.isEmpty
        ? null
        : (assigneeNames.length == 1
            ? assigneeNames.first
            : '${assigneeNames.first} +${assigneeNames.length - 1}');

    final parts = <String>[
      task.clientDisplayName,
      ?assigneeText,
      if (task.deadlineDate != null) formatDeadlineLabel(task.deadlineDate!),
    ];
    return parts.join('  ·  ');
  }
}
