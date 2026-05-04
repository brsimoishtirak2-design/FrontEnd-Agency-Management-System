import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/task_status.dart';

/// Compact colored badge showing a task's current status.
class TaskStatusBadge extends StatelessWidget {
  final TaskStatus status;

  const TaskStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (bg, fg) = _colorsFor(status);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        status.displayName,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: fg,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }

  (Color bg, Color fg) _colorsFor(TaskStatus s) {
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
}
