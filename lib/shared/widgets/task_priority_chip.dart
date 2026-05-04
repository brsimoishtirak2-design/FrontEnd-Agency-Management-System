import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/task_priority.dart';

/// Small chip indicating a task's priority. Color-coded by rank.
class TaskPriorityChip extends StatelessWidget {
  final TaskPriority priority;

  const TaskPriorityChip({super.key, required this.priority});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(priority);

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
          Icon(Icons.flag_outlined, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            priority.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return AppTheme.slate500;
      case TaskPriority.medium:
        return AppTheme.info;
      case TaskPriority.high:
        return AppTheme.warning;
      case TaskPriority.urgent:
        return AppTheme.error;
    }
  }
}
