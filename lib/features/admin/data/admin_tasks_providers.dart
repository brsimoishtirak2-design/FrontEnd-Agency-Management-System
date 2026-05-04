import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_status.dart';
import 'admin_tasks_repository.dart';

/// Provides AdminTasksRepository as a singleton.
final adminTasksRepositoryProvider = Provider<AdminTasksRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AdminTasksRepository(api);
});

/// Filter state for the admin Tasks list.
///
/// Held in a small immutable value type so Riverpod equality works
/// out of the box (status enum + String).
class AdminTasksFilters {
  final TaskStatus? status;
  final String search;

  const AdminTasksFilters({this.status, this.search = ''});

  AdminTasksFilters withStatus(TaskStatus? value) =>
      AdminTasksFilters(status: value, search: search);

  AdminTasksFilters withSearch(String value) =>
      AdminTasksFilters(status: status, search: value);

  bool get isEmpty => status == null && search.trim().isEmpty;

  @override
  bool operator ==(Object other) =>
      other is AdminTasksFilters &&
      other.status == status &&
      other.search == search;

  @override
  int get hashCode => Object.hash(status, search);
}

class AdminTasksFiltersNotifier extends StateNotifier<AdminTasksFilters> {
  AdminTasksFiltersNotifier() : super(const AdminTasksFilters());

  void setStatus(TaskStatus? value) => state = state.withStatus(value);
  void setSearch(String value) => state = state.withSearch(value);
  void clear() => state = const AdminTasksFilters();
}

/// Mutable filter state — driven by the SearchAppBar + status chips.
final adminTasksFiltersProvider =
    StateNotifierProvider<AdminTasksFiltersNotifier, AdminTasksFilters>(
        (ref) => AdminTasksFiltersNotifier());

/// Auto-fetched list of all tasks honoring the current filter state.
/// Riverpod re-runs this when [adminTasksFiltersProvider] changes.
///
/// UI consumes with: `ref.watch(adminAllTasksProvider)`
/// Refresh manually with: `ref.invalidate(adminAllTasksProvider)`
final adminAllTasksProvider = FutureProvider<List<Task>>((ref) async {
  final filters = ref.watch(adminTasksFiltersProvider);
  final repo = ref.watch(adminTasksRepositoryProvider);
  return repo.listAllTasks(
    statusFilter: filters.status,
    search: filters.search,
  );
});

/// Auto-fetched list of tasks filtered by a specific status.
/// Reserved for ad-hoc usage outside the main filter state.
final adminTasksByStatusProvider =
    FutureProvider.family<List<Task>, TaskStatus>((ref, status) async {
  final repo = ref.watch(adminTasksRepositoryProvider);
  return repo.listAllTasks(statusFilter: status);
});

/// Counts of tasks per status for the badge-on-chip UI.
///
/// Search-aware (so counts reflect what's relevant to the current
/// query) but **status-agnostic**: we deliberately do NOT pass
/// `filters.status` to the fetch so the chip can show the full
/// distribution across statuses even while a status filter is
/// applied. Returns a map with every [TaskStatus] key present (zero
/// when no tasks of that status match the search).
final adminTaskStatusCountsProvider =
    FutureProvider<Map<TaskStatus, int>>((ref) async {
  final filters = ref.watch(adminTasksFiltersProvider);
  final repo = ref.watch(adminTasksRepositoryProvider);
  // includeCompleted: true so Approved + Cancelled tasks are present
  // in the count; otherwise the backend's active() scope hides them
  // when no explicit status filter is set, and the chips would always
  // show 0 for completed states.
  final tasks = await repo.listAllTasks(
    search: filters.search,
    includeCompleted: true,
  );
  final counts = <TaskStatus, int>{
    for (final s in TaskStatus.values) s: 0,
  };
  for (final t in tasks) {
    counts[t.status] = (counts[t.status] ?? 0) + 1;
  }
  return counts;
});
