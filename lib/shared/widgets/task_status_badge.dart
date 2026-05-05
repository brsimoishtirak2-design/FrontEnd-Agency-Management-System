import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/task_status.dart';

/// Compact colored chip showing a task's current status. Visually
/// matches `TaskPriorityChip` and the deadline label so the metadata
/// row reads as one cohesive group.
class TaskStatusBadge extends StatelessWidget {
  final TaskStatus status;

  const TaskStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final color = _colorFor(status);
    final icon = _iconFor(status);

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
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            status.displayName,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: color,
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }

  Color _colorFor(TaskStatus s) {
    switch (s) {
      case TaskStatus.assigned:
        return AppTheme.slate500;
      case TaskStatus.inProgress:
        return AppTheme.info;
      case TaskStatus.submitted:
        return AppTheme.brandPrimaryDark;
      case TaskStatus.changesRequested:
        return AppTheme.warning;
      case TaskStatus.approved:
        return AppTheme.success;
      case TaskStatus.overdue:
        return AppTheme.error;
      case TaskStatus.cancelled:
        return AppTheme.slate500;
    }
  }

  IconData _iconFor(TaskStatus s) {
    switch (s) {
      case TaskStatus.assigned:
        return Icons.assignment_outlined;
      case TaskStatus.inProgress:
        return Icons.autorenew_rounded;
      case TaskStatus.submitted:
        return Icons.send_outlined;
      case TaskStatus.changesRequested:
        return Icons.edit_note_rounded;
      case TaskStatus.approved:
        return Icons.check_circle_outline_rounded;
      case TaskStatus.overdue:
        return Icons.warning_amber_rounded;
      case TaskStatus.cancelled:
        return Icons.cancel_outlined;
    }
  }
}
