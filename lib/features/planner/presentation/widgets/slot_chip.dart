import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/planner_slot.dart';
import '../../../../shared/utils/initials.dart';

/// A compact chip representing a single planner slot inside a calendar cell.
///
/// Layout: [P|V badge] [client name short] [assignee initials]
/// Visual cues:
///   - blue/orange background per type (post = info blue, video = warning amber)
///   - lock icon if is_locked
///   - check overlay if completed
///   - strike-through if cancelled
class SlotChip extends StatelessWidget {
  final PlannerSlot slot;
  final VoidCallback? onTap;
  final bool dense;

  const SlotChip({
    super.key,
    required this.slot,
    this.onTap,
    this.dense = false,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = slot.isPost ? AppTheme.info : AppTheme.warning;
    final bg = typeColor.withValues(alpha: 0.12);
    final border = typeColor.withValues(alpha: 0.45);

    final clientName = slot.clientName ?? 'Client';
    final initials = nameInitials(slot.assignedUserName ?? '?');

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 4 : 6,
            vertical: dense ? 2 : 3,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Type badge — single letter for compactness
              Container(
                width: dense ? 14 : 16,
                height: dense ? 14 : 16,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: typeColor,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  slot.isPost ? 'P' : 'V',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: dense ? 9 : 10,
                    fontWeight: FontWeight.w700,
                    height: 1.0,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  clientName,
                  style: TextStyle(
                    fontSize: dense ? 10 : 11,
                    fontWeight: FontWeight.w600,
                    color: AppTheme.slate900,
                    decoration: slot.isCancelled
                        ? TextDecoration.lineThrough
                        : null,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              if (slot.isLocked)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.lock,
                    size: dense ? 10 : 11,
                    color: AppTheme.slate500,
                  ),
                ),
              if (slot.isCompleted)
                Padding(
                  padding: const EdgeInsets.only(right: 2),
                  child: Icon(
                    Icons.check_circle,
                    size: dense ? 10 : 11,
                    color: AppTheme.success,
                  ),
                ),
              Container(
                padding: EdgeInsets.symmetric(
                  horizontal: dense ? 3 : 4,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.slate200,
                  borderRadius: BorderRadius.circular(3),
                ),
                child: Text(
                  initials,
                  style: TextStyle(
                    fontSize: dense ? 8 : 9,
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                    height: 1.0,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
