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
import '../../../shared/widgets/client_avatar.dart';
import '../../../shared/widgets/task_unseen_badges.dart';
import '../data/tasks_providers.dart';
import 'widgets/task_time_filter_strip.dart';

/// Home screen — shows the current user's task list.
///
/// Embedded inside [EmployeeShellScreen] which provides the app bar
/// and bottom navigation.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tasksAsync = ref.watch(myTasksProvider);
    final filter = ref.watch(taskTimeFilterProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppTheme.brandPrimary,
        onRefresh: () async {
          ref.invalidate(myTasksProvider);
          await ref.read(myTasksProvider.future);
        },
        child: tasksAsync.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: Column(
              children: [
                const TaskTimeFilterStrip(),
                Expanded(child: _MyTasksPanel(tasks: _skeletonRows)),
              ],
            ),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState(
                title: 'Could not load tasks',
                message: error.toString(),
                onRetry: () => ref.invalidate(myTasksProvider),
              ),
            ],
          ),
          data: (tasks) {
            final counts = _bucketCounts(tasks);
            final filtered = _applyFilter(tasks, filter);

            return Column(
              children: [
                TaskTimeFilterStrip(counts: counts),
                Expanded(
                  child: filtered.isEmpty
                      ? LayoutBuilder(
                          builder: (context, constraints) =>
                              SingleChildScrollView(
                            physics: const AlwaysScrollableScrollPhysics(),
                            child: ConstrainedBox(
                              constraints: BoxConstraints(
                                minHeight: constraints.maxHeight,
                              ),
                              child: Center(
                                child: AppEmptyState(
                                  icon: Icons.inbox_outlined,
                                  title: tasks.isEmpty
                                      ? 'No tasks assigned'
                                      : 'Nothing for ${filter.label.toLowerCase()}',
                                  subtitle: tasks.isEmpty
                                      ? "You're all caught up. New tasks will appear here."
                                      : 'Try a different filter to see other tasks.',
                                ),
                              ),
                            ),
                          ),
                        )
                      : AppEnter(child: _MyTasksPanel(tasks: filtered)),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  /// Apply the time filter. Tasks with no deadline date are visible only
  /// under [TaskTimeFilter.all]; date-bound filters drop them.
  List<Task> _applyFilter(List<Task> tasks, TaskTimeFilter filter) {
    if (filter == TaskTimeFilter.all) return tasks;

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    bool inRange(DateTime d) {
      switch (filter) {
        case TaskTimeFilter.today:
          return d == today;
        case TaskTimeFilter.week:
          // rolling 7 days from today (inclusive)
          final end = today.add(const Duration(days: 6));
          return !d.isBefore(today) && !d.isAfter(end);
        case TaskTimeFilter.month:
          return d.year == today.year && d.month == today.month;
        case TaskTimeFilter.all:
          return true;
      }
    }

    return tasks.where((t) {
      final raw = t.deadlineDate;
      if (raw == null || raw.isEmpty) return false;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) return false;
      final dateOnly = DateTime(parsed.year, parsed.month, parsed.day);
      return inRange(dateOnly);
    }).toList();
  }

  /// Counts of how many tasks fall into each time bucket — drives the
  /// little number badges on the filter chips.
  Map<TaskTimeFilter, int> _bucketCounts(List<Task> tasks) {
    final result = <TaskTimeFilter, int>{
      TaskTimeFilter.all: tasks.length,
      TaskTimeFilter.today: 0,
      TaskTimeFilter.week: 0,
      TaskTimeFilter.month: 0,
    };
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final weekEnd = today.add(const Duration(days: 6));

    for (final t in tasks) {
      final raw = t.deadlineDate;
      if (raw == null || raw.isEmpty) continue;
      final parsed = DateTime.tryParse(raw);
      if (parsed == null) continue;
      final d = DateTime(parsed.year, parsed.month, parsed.day);
      if (d == today) result[TaskTimeFilter.today] = result[TaskTimeFilter.today]! + 1;
      if (!d.isBefore(today) && !d.isAfter(weekEnd)) {
        result[TaskTimeFilter.week] = result[TaskTimeFilter.week]! + 1;
      }
      if (d.year == today.year && d.month == today.month) {
        result[TaskTimeFilter.month] = result[TaskTimeFilter.month]! + 1;
      }
    }
    return result;
  }
}

class _MyTasksPanel extends StatelessWidget {
  final List<Task> tasks;

  const _MyTasksPanel({required this.tasks});

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
              leading: ClientAvatar(
                name: task.client?.name ?? task.clientDisplayName,
                logoUrl: task.client?.logo,
              ),
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
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TaskUnseenBadges(unseen: task.unseen),
                  if (task.unseen?.hasAnySignal ?? false)
                    const SizedBox(width: 8),
                  const Icon(
                    LucideIcons.chevronRight,
                    color: AppTheme.slate300,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  String _subtitleFor(Task task) {
    final parts = <String>[
      task.clientDisplayName,
      if (task.deadlineDate != null) formatDeadlineLabel(task.deadlineDate!),
    ];
    return parts.join('  ·  ');
  }
}
