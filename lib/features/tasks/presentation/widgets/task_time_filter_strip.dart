import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';

/// Time-window filter for the employee Tasks tab.
///
/// Filters use the task's `deadline_date`. Tasks with no deadline are
/// always visible under [TaskTimeFilter.all] and excluded from the
/// time-bound options.
enum TaskTimeFilter { all, today, week, month }

extension TaskTimeFilterX on TaskTimeFilter {
  String get label {
    switch (this) {
      case TaskTimeFilter.all:
        return 'All';
      case TaskTimeFilter.today:
        return 'Today';
      case TaskTimeFilter.week:
        return 'This week';
      case TaskTimeFilter.month:
        return 'This month';
    }
  }
}

final taskTimeFilterProvider =
    StateProvider<TaskTimeFilter>((ref) => TaskTimeFilter.all);

class TaskTimeFilterStrip extends ConsumerWidget {
  /// Optional badge counts shown after each label, e.g. `{today: 2}`.
  final Map<TaskTimeFilter, int>? counts;

  const TaskTimeFilterStrip({super.key, this.counts});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(taskTimeFilterProvider);

    return SizedBox(
      height: 48,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: TaskTimeFilter.values.map((filter) {
          final isSelected = filter == selected;
          final count = counts?[filter];
          return Padding(
            padding: const EdgeInsets.only(right: 6, top: 8, bottom: 8),
            child: InkWell(
              onTap: () =>
                  ref.read(taskTimeFilterProvider.notifier).state = filter,
              borderRadius: BorderRadius.circular(20),
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: isSelected ? AppTheme.brandPrimary : Colors.white,
                  border: Border.all(
                    color:
                        isSelected ? AppTheme.brandPrimary : AppTheme.slate200,
                  ),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      filter.label,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color:
                            isSelected ? Colors.white : AppTheme.slate800,
                      ),
                    ),
                    if (count != null) ...[
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 6,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? Colors.white.withValues(alpha: 0.25)
                              : AppTheme.slate100,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          '$count',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? Colors.white
                                : AppTheme.slate700,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}
