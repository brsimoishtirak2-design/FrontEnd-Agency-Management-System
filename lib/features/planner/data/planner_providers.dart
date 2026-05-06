import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/monthly_plan.dart';
import 'planner_repository.dart';

/// Singleton repository.
final plannerRepositoryProvider = Provider<PlannerRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return PlannerRepository(api);
});

/// (year, month) the Schedule tab is currently displaying.
class PlannerMonth {
  final int year;
  final int month;
  const PlannerMonth(this.year, this.month);

  PlannerMonth previous() {
    if (month == 1) return PlannerMonth(year - 1, 12);
    return PlannerMonth(year, month - 1);
  }

  PlannerMonth next() {
    if (month == 12) return PlannerMonth(year + 1, 1);
    return PlannerMonth(year, month + 1);
  }

  @override
  bool operator ==(Object other) =>
      other is PlannerMonth && other.year == year && other.month == month;

  @override
  int get hashCode => Object.hash(year, month);
}

PlannerMonth _today() {
  final now = DateTime.now();
  return PlannerMonth(now.year, now.month);
}

/// Currently-selected month (defaults to today's month).
final plannerSelectedMonthProvider =
    StateProvider<PlannerMonth>((ref) => _today());

/// Per-client filter — null means "master view (all clients)".
final plannerClientFilterProvider = StateProvider<int?>((ref) => null);

/// The plan for the selected month, fetched from the API. Returns null when
/// no plan exists yet for that month.
final plannerPlanProvider =
    FutureProvider.autoDispose<MonthlyPlan?>((ref) async {
  final selected = ref.watch(plannerSelectedMonthProvider);
  final repo = ref.watch(plannerRepositoryProvider);
  return repo.planForMonth(selected.year, selected.month);
});
