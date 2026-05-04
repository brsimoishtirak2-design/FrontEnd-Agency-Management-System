import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/user.dart';
import '../../admin/data/admin_tasks_providers.dart';
import '../../auth/data/auth_providers.dart';
import 'tasks_repository.dart';

/// Provides the TasksRepository as a singleton.
final tasksRepositoryProvider = Provider<TasksRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return TasksRepository(api);
});

/// Auto-fetched list of the current user's tasks.
///
/// UI consumes this with `ref.watch(myTasksProvider)` and gets an
/// `AsyncValue<List<Task>>` with three states:
///   - loading (initial fetch)
///   - error (network/auth failure)
///   - data (the task list)
///
/// To refresh: `ref.invalidate(myTasksProvider)` — triggers a re-fetch.
final myTasksProvider = FutureProvider<List<Task>>((ref) async {
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.listMyTasks();
});

/// Auto-fetched single task detail (keyed by task id).
///
/// Role-aware: admin users hit /api/admin/tasks/{id} (which can read any
/// task in the agency); employees hit /api/tasks/{id} (which 404s on tasks
/// they're not assigned to). UI doesn't need to know which endpoint —
/// just `ref.watch(taskDetailProvider(taskId))`.
final taskDetailProvider =
    FutureProvider.family<Task, int>((ref, id) async {
  final auth = ref.watch(authStateProvider);
  if (auth is AuthAuthenticated && auth.user.isAdmin) {
    final adminRepo = ref.watch(adminTasksRepositoryProvider);
    return adminRepo.getTask(id);
  }
  final repo = ref.watch(tasksRepositoryProvider);
  return repo.getTask(id);
});
