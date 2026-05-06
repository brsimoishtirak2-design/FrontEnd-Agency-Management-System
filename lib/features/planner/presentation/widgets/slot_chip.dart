import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/planner_slot.dart';
import '../../../../shared/utils/initials.dart';

/// A compact chip representing a single planner slot inside a calendar cell.
///
/// Two layouts:
/// - **default**: [P|V] [client name] [lock] [✔] [initials] — used in the
///   master view where each cell may host slots from many clients.
/// - **singleClient**: large centred "Post" or "Video" label, with lock /
///   completion / assignee initials kept small on the right edge. Used when
///   the calendar is filtered to one client — the name is implicit so the
///   type becomes the dominant visual.
class SlotChip extends StatelessWidget {
  final PlannerSlot slot;
  final VoidCallback? onTap;
  final bool dense;
  final bool singleClient;

  const SlotChip({
    super.key,
    required this.slot,
    this.onTap,
    this.dense = false,
    this.singleClient = false,
  });

  @override
  Widget build(BuildContext context) {
    final typeColor = slot.isPost ? AppTheme.info : AppTheme.warning;
    final bg = typeColor.withValues(alpha: 0.12);
    final border = typeColor.withValues(alpha: 0.45);

    final clientName = slot.clientName ?? 'Client';
    final initials = nameInitials(slot.assignedUserName ?? '?');
    final typeLabel = slot.isPost ? 'Post' : 'Video';

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(6),
        child: Container(
          padding: EdgeInsets.symmetric(
            horizontal: dense ? 6 : 10,
            vertical: dense ? 3 : 5,
          ),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(6),
            border: Border.all(color: border, width: 1),
          ),
          child: singleClient
              ? _singleClientLayout(
                  typeColor: typeColor,
                  typeLabel: typeLabel,
                  initials: initials,
                )
              : _multiClientLayout(
                  typeColor: typeColor,
                  clientName: clientName,
                  initials: initials,
                ),
        ),
      ),
    );
  }

  /// Master-view layout: small P/V badge, then client name, with badges on
  /// the right.
  Widget _multiClientLayout({
    required Color typeColor,
    required String clientName,
    required String initials,
  }) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
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
              decoration:
                  slot.isCancelled ? TextDecoration.lineThrough : null,
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
        _initialsTag(initials),
      ],
    );
  }

  /// Single-client layout: large type label centred, badges on the right.
  Widget _singleClientLayout({
    required Color typeColor,
    required String typeLabel,
    required String initials,
  }) {
    return Row(
      children: [
        // Right-side badges are mirrored as an invisible spacer on the left
        // so the centred label is actually centred and not nudged off by
        // the trailing icons.
        Opacity(
          opacity: 0,
          child: _trailingCluster(initials),
        ),
        Expanded(
          child: Center(
            child: Text(
              typeLabel,
              style: TextStyle(
                fontSize: dense ? 13 : 16,
                fontWeight: FontWeight.w800,
                color: typeColor,
                letterSpacing: 0.4,
                decoration:
                    slot.isCancelled ? TextDecoration.lineThrough : null,
                height: 1.1,
              ),
            ),
          ),
        ),
        _trailingCluster(initials),
      ],
    );
  }

  Widget _trailingCluster(String initials) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (slot.isLocked)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.lock,
              size: dense ? 11 : 13,
              color: AppTheme.slate500,
            ),
          ),
        if (slot.isCompleted)
          Padding(
            padding: const EdgeInsets.only(right: 4),
            child: Icon(
              Icons.check_circle,
              size: dense ? 11 : 13,
              color: AppTheme.success,
            ),
          ),
        _initialsTag(initials),
      ],
    );
  }

  Widget _initialsTag(String initials) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: dense ? 4 : 5,
        vertical: dense ? 1 : 2,
      ),
      decoration: BoxDecoration(
        color: AppTheme.slate200,
        borderRadius: BorderRadius.circular(3),
      ),
      child: Text(
        initials,
        style: TextStyle(
          fontSize: dense ? 9 : 10,
          fontWeight: FontWeight.w700,
          color: AppTheme.slate700,
          height: 1.0,
        ),
      ),
    );
  }
}
