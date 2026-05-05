import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../models/task.dart';

/// Compact row of "unseen" indicators shown next to a task list row.
///
/// Renders one of:
///   - "NEW" pill, if the user has never opened this task.
///   - One or more small icon badges otherwise:
///       💬 N  — unread comments
///       📎    — new brief and/or submission files since last view
///       ✏️    — task fields edited since last view
///
/// Returns SizedBox.shrink() when there is nothing new to show — so
/// it's safe to drop in any list row's trailing slot unconditionally.
class TaskUnseenBadges extends StatelessWidget {
  final TaskUnseen? unseen;

  const TaskUnseenBadges({super.key, required this.unseen});

  @override
  Widget build(BuildContext context) {
    final u = unseen;
    if (u == null || !u.hasAnySignal) {
      return const SizedBox.shrink();
    }

    if (u.isUnviewed) {
      return _NewPill();
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (u.unreadComments > 0) ...[
          _CountBadge(
            icon: Icons.chat_bubble_rounded,
            count: u.unreadComments,
            color: AppTheme.error,
          ),
          const SizedBox(width: 6),
        ],
        if (u.hasNewBrief || u.hasNewSubmission) ...[
          _DotIcon(
            icon: Icons.attach_file_rounded,
            color: AppTheme.info,
            tooltip: u.hasNewSubmission ? 'New submission' : 'New brief file',
          ),
          const SizedBox(width: 6),
        ],
        if (u.wasUpdated) ...[
          _DotIcon(
            icon: Icons.edit_rounded,
            color: AppTheme.warning,
            tooltip: 'Task updated',
          ),
        ],
      ],
    );
  }
}

class _NewPill extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppTheme.warning,
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Text(
        'NEW',
        style: TextStyle(
          color: Colors.white,
          fontSize: 10,
          fontWeight: FontWeight.w800,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

/// Red badge with a chat icon and count — exactly what the user
/// described ("display the red badge appearing in there").
class _CountBadge extends StatelessWidget {
  final IconData icon;
  final int count;
  final Color color;

  const _CountBadge({
    required this.icon,
    required this.count,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final label = count > 99 ? '99+' : '$count';
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 11, color: Colors.white),
          const SizedBox(width: 3),
          Text(
            label,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

/// Small colored circle holding an icon — used for binary signals
/// where a count would be misleading (any new file / fields updated).
class _DotIcon extends StatelessWidget {
  final IconData icon;
  final Color color;
  final String tooltip;

  const _DotIcon({
    required this.icon,
    required this.color,
    required this.tooltip,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, size: 12, color: color),
      ),
    );
  }
}
