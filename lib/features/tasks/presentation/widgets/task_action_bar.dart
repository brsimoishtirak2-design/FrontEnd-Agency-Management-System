import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/task.dart';
import '../../../../shared/models/task_status.dart';
import '../../../../shared/models/user.dart';
import '../../../admin/data/admin_tasks_providers.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/tasks_providers.dart';

/// Action bar shown at the bottom of TaskDetailScreen.
///
/// Renders different action buttons depending on:
///   - the current user's role (employee vs admin)
///   - whether the user is the leader (employees only)
///   - the task's current status
///
/// Returns SizedBox.shrink() when no action is available.
class TaskActionBar extends ConsumerStatefulWidget {
  final Task task;
  final int? currentUserId;

  const TaskActionBar({
    super.key,
    required this.task,
    required this.currentUserId,
  });

  @override
  ConsumerState<TaskActionBar> createState() => _TaskActionBarState();
}

class _TaskActionBarState extends ConsumerState<TaskActionBar> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth is AuthAuthenticated && auth.user.isAdmin;

    final actions =
        isAdmin ? _adminActions() : _employeeActions(widget.currentUserId);

    if (actions.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: EdgeInsets.fromLTRB(
        16,
        12,
        16,
        12 + MediaQuery.of(context).padding.bottom,
      ),
      decoration: BoxDecoration(
        color: Theme.of(context).scaffoldBackgroundColor,
        border: Border(
          top: BorderSide(color: AppTheme.slate100, width: 1),
        ),
      ),
      child: Row(
        children: [
          for (var i = 0; i < actions.length; i++) ...[
            if (i > 0) const SizedBox(width: 10),
            Expanded(
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : () => _handle(actions[i]),
                style: ElevatedButton.styleFrom(
                  backgroundColor: actions[i].color,
                  foregroundColor: Colors.white,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: _isSubmitting
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      )
                    : Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(actions[i].icon, size: 18),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              actions[i].label,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Actions available to the EMPLOYEE leader on a given task state.
  List<_AvailableAction> _employeeActions(int? userId) {
    if (userId == null) return const [];
    if (!widget.task.isLeaderUser(userId)) return const [];

    switch (widget.task.status) {
      case TaskStatus.assigned:
        return [
          _AvailableAction(
            label: 'Start Task',
            icon: Icons.play_arrow_rounded,
            color: AppTheme.brandPrimary,
            kind: _ActionKind.start,
          ),
        ];
      case TaskStatus.inProgress:
        return [
          _AvailableAction(
            label: 'Submit for Review',
            icon: Icons.send_rounded,
            color: AppTheme.brandPrimaryDark,
            kind: _ActionKind.submit,
          ),
        ];
      case TaskStatus.changesRequested:
        return [
          _AvailableAction(
            label: 'Resume Work',
            icon: Icons.refresh_rounded,
            color: AppTheme.warning,
            kind: _ActionKind.reProgress,
          ),
        ];
      case TaskStatus.overdue:
        final leader = widget.task.leader;
        final hasStarted = leader?.startedAt != null;
        return [
          if (hasStarted)
            _AvailableAction(
              label: 'Submit for Review',
              icon: Icons.send_rounded,
              color: AppTheme.brandPrimaryDark,
              kind: _ActionKind.submit,
            )
          else
            _AvailableAction(
              label: 'Start Task',
              icon: Icons.play_arrow_rounded,
              color: AppTheme.brandPrimary,
              kind: _ActionKind.start,
            ),
        ];
      case TaskStatus.submitted:
      case TaskStatus.approved:
      case TaskStatus.cancelled:
        return const [];
    }
  }

  /// Actions available to ADMIN on a given task state.
  List<_AvailableAction> _adminActions() {
    switch (widget.task.status) {
      case TaskStatus.submitted:
        return [
          _AvailableAction(
            label: 'Request Changes',
            icon: Icons.refresh_rounded,
            color: AppTheme.warning,
            kind: _ActionKind.requestChanges,
          ),
          _AvailableAction(
            label: 'Approve',
            icon: Icons.check_circle_rounded,
            color: AppTheme.success,
            kind: _ActionKind.approve,
          ),
        ];
      case TaskStatus.assigned:
      case TaskStatus.inProgress:
      case TaskStatus.changesRequested:
      case TaskStatus.overdue:
        return [
          _AvailableAction(
            label: 'Cancel Task',
            icon: Icons.cancel_outlined,
            color: AppTheme.error,
            kind: _ActionKind.cancel,
          ),
        ];
      case TaskStatus.approved:
      case TaskStatus.cancelled:
        return const [];
    }
  }

  Future<void> _handle(_AvailableAction action) async {
    final taskId = widget.task.id;

    // Some actions need a note; collect it first.
    String? noteOrReason;
    if (action.kind == _ActionKind.submit) {
      noteOrReason = await _promptForNote(
        title: 'Submit for review',
        subtitle: 'Add an optional note for the admin.',
        hint: 'Anything the admin should know? (optional)',
        minChars: 0,
        confirmLabel: 'Submit',
      );
      if (noteOrReason == null) return; // cancelled
    } else if (action.kind == _ActionKind.requestChanges) {
      noteOrReason = await _promptForNote(
        title: 'Request changes',
        subtitle: 'Tell the leader what needs to be revised. '
            'Minimum 10 characters.',
        hint: 'Describe the changes needed…',
        minChars: 10,
        confirmLabel: 'Send',
      );
      if (noteOrReason == null) return;
    } else if (action.kind == _ActionKind.cancel) {
      noteOrReason = await _promptForNote(
        title: 'Cancel task',
        subtitle: 'Provide a reason for cancelling. '
            'Minimum 10 characters.',
        hint: 'Why is this task being cancelled?',
        minChars: 10,
        confirmLabel: 'Cancel Task',
        confirmIsDestructive: true,
      );
      if (noteOrReason == null) return;
    }

    setState(() => _isSubmitting = true);
    try {
      switch (action.kind) {
        case _ActionKind.start:
          await ref.read(tasksRepositoryProvider).startTask(taskId);
        case _ActionKind.submit:
          await ref
              .read(tasksRepositoryProvider)
              .submitTask(taskId, note: noteOrReason);
        case _ActionKind.reProgress:
          await ref.read(tasksRepositoryProvider).reProgressTask(taskId);
        case _ActionKind.approve:
          await ref.read(adminTasksRepositoryProvider).approveTask(taskId);
        case _ActionKind.requestChanges:
          await ref
              .read(adminTasksRepositoryProvider)
              .requestChanges(taskId, note: noteOrReason!);
        case _ActionKind.cancel:
          await ref
              .read(adminTasksRepositoryProvider)
              .cancelTask(taskId, reason: noteOrReason!);
      }

      // Refresh detail + both list providers (admin + employee) so any
      // visible list reflects the new state.
      ref.invalidate(taskDetailProvider(taskId));
      ref.invalidate(myTasksProvider);
      ref.invalidate(adminAllTasksProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_successMessage(action.kind)),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  String _successMessage(_ActionKind kind) {
    switch (kind) {
      case _ActionKind.start:
        return 'Task started.';
      case _ActionKind.submit:
        return 'Task submitted for review.';
      case _ActionKind.reProgress:
        return 'Resumed work on the task.';
      case _ActionKind.approve:
        return 'Task approved.';
      case _ActionKind.requestChanges:
        return 'Changes requested.';
      case _ActionKind.cancel:
        return 'Task cancelled.';
    }
  }

  /// Generic bottom-sheet note prompt used for submit/request-changes/cancel.
  ///
  /// Returns the entered text (or empty if minChars==0 and user submitted
  /// blank). Returns null if the user cancelled.
  Future<String?> _promptForNote({
    required String title,
    required String subtitle,
    required String hint,
    required int minChars,
    required String confirmLabel,
    bool confirmIsDestructive = false,
  }) async {
    final controller = TextEditingController();
    final result = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) {
        return _NoteSheet(
          controller: controller,
          title: title,
          subtitle: subtitle,
          hint: hint,
          minChars: minChars,
          confirmLabel: confirmLabel,
          confirmIsDestructive: confirmIsDestructive,
        );
      },
    );
    return result;
  }
}

class _NoteSheet extends StatefulWidget {
  final TextEditingController controller;
  final String title;
  final String subtitle;
  final String hint;
  final int minChars;
  final String confirmLabel;
  final bool confirmIsDestructive;

  const _NoteSheet({
    required this.controller,
    required this.title,
    required this.subtitle,
    required this.hint,
    required this.minChars,
    required this.confirmLabel,
    required this.confirmIsDestructive,
  });

  @override
  State<_NoteSheet> createState() => _NoteSheetState();
}

class _NoteSheetState extends State<_NoteSheet> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final text = widget.controller.text.trim();
    final isValid = text.length >= widget.minChars;
    final remaining = widget.minChars - text.length;

    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 20,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.title,
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 6),
          Text(
            widget.subtitle,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppTheme.slate500,
                ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: widget.controller,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: InputDecoration(
              hintText: widget.hint,
              helperText: widget.minChars > 0 && !isValid
                  ? '$remaining more character${remaining == 1 ? '' : 's'} needed'
                  : null,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: const Text('Cancel'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: !isValid
                      ? null
                      : () => Navigator.of(context).pop(text),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                    backgroundColor: widget.confirmIsDestructive
                        ? AppTheme.error
                        : null,
                    foregroundColor: widget.confirmIsDestructive
                        ? Colors.white
                        : null,
                  ),
                  child: Text(widget.confirmLabel),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ActionKind {
  start,
  submit,
  reProgress,
  approve,
  requestChanges,
  cancel,
}

class _AvailableAction {
  final String label;
  final IconData icon;
  final Color color;
  final _ActionKind kind;

  const _AvailableAction({
    required this.label,
    required this.icon,
    required this.color,
    required this.kind,
  });
}
