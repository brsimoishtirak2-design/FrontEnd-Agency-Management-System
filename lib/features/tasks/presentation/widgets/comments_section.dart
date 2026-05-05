import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/comment.dart';
import '../../../../shared/utils/date_format.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/comments_providers.dart';

/// Comments section embedded in the task detail screen.
///
/// Shows the comments list, allows posting new comments, and (for the
/// current user's own comments) editing and deleting.
class CommentsSection extends ConsumerStatefulWidget {
  final int taskId;

  const CommentsSection({super.key, required this.taskId});

  @override
  ConsumerState<CommentsSection> createState() => _CommentsSectionState();
}

class _CommentsSectionState extends ConsumerState<CommentsSection> {
  final _composeController = TextEditingController();
  bool _isPosting = false;

  @override
  void dispose() {
    _composeController.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final body = _composeController.text.trim();
    if (body.isEmpty) return;

    setState(() => _isPosting = true);
    try {
      final repo = ref.read(commentsRepositoryProvider);
      await repo.create(taskId: widget.taskId, body: body);

      if (!mounted) return;
      _composeController.clear();
      FocusScope.of(context).unfocus();
      ref.invalidate(taskCommentsProvider(widget.taskId));
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
      if (mounted) setState(() => _isPosting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(taskCommentsProvider(widget.taskId));
    final authState = ref.watch(authStateProvider);
    final currentUserId =
        (authState is AuthAuthenticated) ? authState.user.id : null;

    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Header(commentsAsync: commentsAsync),
            const SizedBox(height: 8),
            commentsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                ),
              ),
              error: (error, _) => _InlineError(
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(taskCommentsProvider(widget.taskId)),
              ),
              data: (comments) {
                if (comments.isEmpty) return const _EmptyState();
                return Column(
                  children: [
                    for (final c in comments)
                      _CommentItem(
                        comment: c,
                        currentUserId: currentUserId,
                        taskId: widget.taskId,
                      ),
                  ],
                );
              },
            ),
            const SizedBox(height: 12),
            const Divider(height: 1),
            const SizedBox(height: 12),
            _Composer(
              controller: _composeController,
              isPosting: _isPosting,
              onSend: _post,
            ),
          ],
        ),
      ),
    );
  }
}

// --- Header ---

class _Header extends StatelessWidget {
  final AsyncValue<List<Comment>> commentsAsync;

  const _Header({required this.commentsAsync});

  @override
  Widget build(BuildContext context) {
    final count = commentsAsync.maybeWhen(
      data: (list) => list.length,
      orElse: () => null,
    );

    return Row(
      children: [
        Text(
          'COMMENTS',
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppTheme.slate500,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
        ),
        if (count != null) ...[
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: AppTheme.slate100,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              '$count',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.slate700,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

// --- Empty / Error ---

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Center(
        child: Text(
          'No comments yet. Be the first to post.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.slate500,
                fontStyle: FontStyle.italic,
              ),
        ),
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _InlineError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: AppTheme.error, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.error,
                  ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// --- One comment row ---

class _CommentItem extends ConsumerWidget {
  final Comment comment;
  final int? currentUserId;
  final int taskId;

  const _CommentItem({
    required this.comment,
    required this.currentUserId,
    required this.taskId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isMine = comment.isAuthor(currentUserId);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          UserAvatar(
            name: comment.userName,
            photoUrl: comment.userProfilePhoto,
            radius: 16,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        comment.userName,
                        style: Theme.of(context)
                            .textTheme
                            .bodyMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    Text(
                      formatRelativeTimestamp(comment.createdAt),
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.slate500,
                              ),
                    ),
                    if (isMine) ...[
                      const SizedBox(width: 4),
                      _OwnerMenu(comment: comment, taskId: taskId),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  comment.body,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        height: 1.4,
                      ),
                ),
                if (comment.isEdited) ...[
                  const SizedBox(height: 2),
                  Text(
                    '(edited)',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate500,
                          fontStyle: FontStyle.italic,
                        ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }


}

// --- Owner-only edit/delete menu ---

class _OwnerMenu extends ConsumerWidget {
  final Comment comment;
  final int taskId;

  const _OwnerMenu({required this.comment, required this.taskId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_horiz, size: 18),
      tooltip: 'Comment options',
      padding: EdgeInsets.zero,
      onSelected: (value) async {
        if (value == 'edit') {
          await _handleEdit(context, ref);
        } else if (value == 'delete') {
          await _handleDelete(context, ref);
        }
      },
      itemBuilder: (_) => [
        const PopupMenuItem(value: 'edit', child: Text('Edit')),
        const PopupMenuItem(value: 'delete', child: Text('Delete')),
      ],
    );
  }

  Future<void> _handleEdit(BuildContext context, WidgetRef ref) async {
    final controller = TextEditingController(text: comment.body);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(
          controller: controller,
          maxLines: 4,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Comment'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () =>
                Navigator.of(ctx).pop(controller.text.trim()),
            child: const Text('Save'),
          ),
        ],
      ),
    );

    if (result == null || result.isEmpty || result == comment.body) return;

    try {
      final repo = ref.read(commentsRepositoryProvider);
      await repo.update(
        taskId: taskId,
        commentId: comment.id,
        body: result,
      );
      ref.invalidate(taskCommentsProvider(taskId));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  Future<void> _handleDelete(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete comment?'),
        content: const Text('This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final repo = ref.read(commentsRepositoryProvider);
      await repo.delete(taskId: taskId, commentId: comment.id);
      ref.invalidate(taskCommentsProvider(taskId));
    } on ApiException catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}

// --- Composer at the bottom ---

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isPosting;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isPosting,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: TextField(
            controller: controller,
            enabled: !isPosting,
            minLines: 1,
            maxLines: 4,
            textInputAction: TextInputAction.newline,
            decoration: const InputDecoration(
              hintText: 'Add a comment',
              isDense: true,
            ),
          ),
        ),
        const SizedBox(width: 8),
        SizedBox(
          height: 48,
          child: ElevatedButton(
            onPressed: isPosting ? null : onSend,
            style: ElevatedButton.styleFrom(
              minimumSize: const Size(48, 48),
              padding: const EdgeInsets.symmetric(horizontal: 14),
            ),
            child: isPosting
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send_rounded, size: 18),
          ),
        ),
      ],
    );
  }
}
