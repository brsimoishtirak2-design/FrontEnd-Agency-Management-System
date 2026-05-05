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
            child: _MyTasksPanel(tasks: _skeletonRows),
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
            if (tasks.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  AppEmptyState(
                    icon: Icons.inbox_outlined,
                    title: 'No tasks assigned',
                    subtitle:
                        "You're all caught up. New tasks will appear here.",
                  ),
                ],
              );
            }
            return AppEnter(
              child: _MyTasksPanel(tasks: tasks),
            );
          },
        ),
      ),
    );
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
