import 'dart:async';
import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/comment.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/data/auth_providers.dart';
import '../data/comments_providers.dart';

/// Full-screen chat-style comments view for a task. Pushed from the
/// task detail screen via the comments-icon FAB.
///
/// Layout follows the WhatsApp / iMessage convention: messages stack
/// from the top, "mine" align right with a brand-purple bubble, others
/// align left with a slate bubble. Composer is pinned at the bottom.
class TaskCommentsScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskCommentsScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskCommentsScreen> createState() =>
      _TaskCommentsScreenState();
}

class _TaskCommentsScreenState
    extends ConsumerState<TaskCommentsScreen>
    with WidgetsBindingObserver {
  final _composeController = TextEditingController();
  final _scrollController = ScrollController();
  bool _isPosting = false;

  // Poll the comments endpoint so messages from others appear without
  // forcing the user to close + reopen the app. We pause polling while
  // the app is backgrounded and resume on foreground.
  //
  // Platforms WITH FCM (iOS / Android) get near-instant updates from
  // push notifications, so a 10s poll is just a safety net. Platforms
  // WITHOUT FCM (macOS, web, tests) rely entirely on polling, so they
  // poll much faster to keep the chat feeling live — including for
  // edits and deletes from other devices.
  static Duration get _pollInterval {
    if (kIsWeb || (!Platform.isIOS && !Platform.isAndroid)) {
      return const Duration(seconds: 2);
    }
    return const Duration(seconds: 10);
  }

  Timer? _pollTimer;

  /// Tracks the most recently observed comment count so the auto-scroll
  /// listener can detect new messages independently of intermediate
  /// AsyncValue.loading states (where prev/next .value would be null).
  int _lastKnownLength = 0;

  /// Cached notifier reference. Held so dispose() can clear the active
  /// marker without going through `ref` (ref is invalid post-dispose).
  StateController<int?>? _activeMarker;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _startPolling();
    // Mark this task's comments as seen on entry so the FAB badge
    // clears. Re-mark on every resume below so badges stay correct
    // when the user comes back to the screen after answering a call,
    // etc. Also flag this task as the currently-visible chat so the
    // FCM foreground handler can suppress its redundant snackbar.
    // Finally, pin the scroll position to the latest message once the
    // first frame has rendered with data.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final marker = ref.read(activeCommentsTaskProvider.notifier);
      _activeMarker = marker;
      ref
          .read(commentsLastSeenProvider.notifier)
          .markSeen(widget.taskId);
      marker.state = widget.taskId;
      _scrollToBottomSoon();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _pollTimer?.cancel();
    // Use the cached notifier — calling ref.read() after dispose throws.
    // Only clear if the marker still points at us (a fast back-and-forth
    // could have already moved it to another chat).
    final marker = _activeMarker;
    if (marker != null && marker.state == widget.taskId) {
      marker.state = null;
    }
    _composeController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Refresh once on resume, resume polling, and re-mark seen so
      // the FAB badge clears when returning to the chat.
      ref.invalidate(taskCommentsProvider(widget.taskId));
      _startPolling();
      ref
          .read(commentsLastSeenProvider.notifier)
          .markSeen(widget.taskId);
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      _pollTimer?.cancel();
    }
  }

  void _startPolling() {
    _pollTimer?.cancel();
    _pollTimer = Timer.periodic(_pollInterval, (_) {
      if (!mounted) return;
      ref.invalidate(taskCommentsProvider(widget.taskId));
    });
  }

  Future<void> _manualRefresh() async {
    ref.invalidate(taskCommentsProvider(widget.taskId));
    await ref.read(taskCommentsProvider(widget.taskId).future);
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) return;
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
      );
    });
  }

  /// True when the user has scrolled up far enough to be reading older
  /// messages. We avoid auto-scrolling them to the bottom on a new
  /// message in that case — only scroll when they're already near the
  /// latest message.
  bool _isNearBottom() {
    if (!_scrollController.hasClients) return true;
    final pos = _scrollController.position;
    return pos.maxScrollExtent - pos.pixels < 120;
  }

  Future<void> _send() async {
    final body = _composeController.text.trim();
    if (body.isEmpty || _isPosting) return;

    setState(() => _isPosting = true);
    try {
      final repo = ref.read(commentsRepositoryProvider);
      await repo.create(taskId: widget.taskId, body: body);

      if (!mounted) return;
      _composeController.clear();
      // Invalidate AND await the refresh so we know the new data has
      // landed before we try to scroll to it. Doing the scroll before
      // the new comment renders would just snap to the OLD bottom.
      ref.invalidate(taskCommentsProvider(widget.taskId));
      try {
        await ref.read(taskCommentsProvider(widget.taskId).future);
      } catch (_) {
        // Refresh failure is non-fatal here — the chat list will retry
        // via polling and the user can pull-to-refresh.
      }
      if (!mounted) return;
      _scrollToBottomSoon();
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

  Future<void> _editComment(Comment c) async {
    final controller = TextEditingController(text: c.body);
    final result = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit comment'),
        content: TextField(
          controller: controller,
          maxLines: 5,
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
    if (result == null || result.isEmpty || result == c.body) return;
    try {
      final repo = ref.read(commentsRepositoryProvider);
      await repo.update(
        taskId: widget.taskId,
        commentId: c.id,
        body: result,
      );
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
    }
  }

  Future<void> _deleteComment(Comment c) async {
    final ok = await showDialog<bool>(
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
            style:
                ElevatedButton.styleFrom(backgroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      final repo = ref.read(commentsRepositoryProvider);
      await repo.delete(taskId: widget.taskId, commentId: c.id);
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
    }
  }

  @override
  Widget build(BuildContext context) {
    // Auto-scroll to the bottom whenever a new message lands AND the
    // user is already viewing the latest. If they've scrolled up to
    // read history, leave them be. We track length internally instead
    // of comparing prev/next.value because intermediate loading states
    // would break that comparison.
    ref.listen(taskCommentsProvider(widget.taskId), (_, next) {
      next.whenData((list) {
        final grew = list.length > _lastKnownLength;
        _lastKnownLength = list.length;
        if (grew && _isNearBottom()) {
          _scrollToBottomSoon();
        }
      });
    });

    final commentsAsync = ref.watch(taskCommentsProvider(widget.taskId));
    final auth = ref.watch(authStateProvider);
    final myId = auth is AuthAuthenticated ? auth.user.id : null;

    return Scaffold(
      backgroundColor: AppTheme.slate50,
      appBar: AppBar(
        title: const Text('Comments'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: commentsAsync.when(
                loading: () => const Center(
                  child: SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: AppTheme.brandPrimary,
                    ),
                  ),
                ),
                error: (error, _) => _Error(
                  message: error.toString(),
                  onRetry: () => ref
                      .invalidate(taskCommentsProvider(widget.taskId)),
                ),
                data: (comments) {
                  if (comments.isEmpty) {
                    return RefreshIndicator(
                      color: AppTheme.brandPrimary,
                      onRefresh: _manualRefresh,
                      child: LayoutBuilder(
                        builder: (context, constraints) =>
                            SingleChildScrollView(
                          physics:
                              const AlwaysScrollableScrollPhysics(),
                          child: ConstrainedBox(
                            constraints: BoxConstraints(
                              minHeight: constraints.maxHeight,
                            ),
                            child: const Center(child: _EmptyState()),
                          ),
                        ),
                      ),
                    );
                  }
                  return RefreshIndicator(
                    color: AppTheme.brandPrimary,
                    onRefresh: _manualRefresh,
                    child: ListView.builder(
                      controller: _scrollController,
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(12, 16, 12, 12),
                      itemCount: comments.length,
                      itemBuilder: (context, index) {
                        final c = comments[index];
                        final isMine = c.isAuthor(myId);
                        // Show name if previous message wasn't from same author.
                        final showName = !isMine &&
                            (index == 0 ||
                                !comments[index - 1].isAuthor(c.userId));
                        return _MessageBubble(
                          comment: c,
                          isMine: isMine,
                          showName: showName,
                          onEdit:
                              isMine ? () => _editComment(c) : null,
                          onDelete:
                              isMine ? () => _deleteComment(c) : null,
                        );
                      },
                    ),
                  );
                },
              ),
            ),
            _Composer(
              controller: _composeController,
              isPosting: _isPosting,
              onSend: _send,
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.chat_bubble_outline_rounded,
              size: 48,
              color: AppTheme.slate300,
            ),
            const SizedBox(height: 12),
            Text(
              'No messages yet',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
            ),
            const SizedBox(height: 4),
            Text(
              'Start the conversation below.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Error extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _Error({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              'Could not load comments',
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              message,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                  ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  final Comment comment;
  final bool isMine;
  final bool showName;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;

  const _MessageBubble({
    required this.comment,
    required this.isMine,
    required this.showName,
    this.onEdit,
    this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final bg = isMine ? AppTheme.brandPrimary : Colors.white;
    final fg = isMine ? Colors.white : AppTheme.slate900;
    final timeColor = isMine
        ? Colors.white.withValues(alpha: 0.7)
        : AppTheme.slate500;
    final radius = const Radius.circular(14);
    final tail = const Radius.circular(4);

    final bubble = GestureDetector(
      onLongPress: isMine ? () => _showActionsSheet(context) : null,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.72,
        ),
        child: Container(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.only(
              topLeft: radius,
              topRight: radius,
              bottomLeft: isMine ? radius : tail,
              bottomRight: isMine ? tail : radius,
            ),
            border: isMine
                ? null
                : Border.all(color: AppTheme.slate100, width: 1),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                comment.body,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: fg,
                      height: 1.35,
                    ),
              ),
              const SizedBox(height: 4),
              Row(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (comment.isEdited) ...[
                    Text(
                      'edited',
                      style: TextStyle(
                        color: timeColor,
                        fontSize: 10,
                        fontStyle: FontStyle.italic,
                      ),
                    ),
                    const SizedBox(width: 6),
                  ],
                  Text(
                    formatChatTimestamp(comment.createdAt),
                    style: TextStyle(
                      color: timeColor,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );

    // Mine: right-aligned, no avatar — keep the existing minimal look.
    if (isMine) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 3),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [bubble],
        ),
      );
    }

    // Other side: avatar on the left, name above the bubble. When this
    // is a consecutive message from the same sender (`showName` is
    // false), render a transparent spacer the size of the avatar so
    // the bubble stays aligned with the streak above.
    const avatarRadius = 14.0;
    const avatarSlotWidth = avatarRadius * 2;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          SizedBox(
            width: avatarSlotWidth,
            child: showName
                ? UserAvatar(
                    name: comment.userName,
                    photoUrl: comment.userProfilePhoto,
                    radius: avatarRadius,
                  )
                : null,
          ),
          const SizedBox(width: 8),
          Flexible(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (showName)
                  Padding(
                    padding: const EdgeInsets.only(left: 4, bottom: 2),
                    child: Text(
                      comment.userName,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.brandPrimaryDark,
                            fontWeight: FontWeight.w700,
                          ),
                    ),
                  ),
                bubble,
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showActionsSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Material(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
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
                const SizedBox(height: 14),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text(
                    'MESSAGE OPTIONS',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate500,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                        ),
                  ),
                ),
                const SizedBox(height: 10),
                if (onEdit != null)
                  _SheetAction(
                    icon: Icons.edit_outlined,
                    label: 'Edit message',
                    color: AppTheme.brandPrimaryDark,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onEdit!();
                    },
                  ),
                if (onDelete != null) ...[
                  const SizedBox(height: 6),
                  _SheetAction(
                    icon: Icons.delete_outline,
                    label: 'Delete message',
                    color: AppTheme.error,
                    onTap: () {
                      Navigator.of(ctx).pop();
                      onDelete!();
                    },
                  ),
                ],
                const SizedBox(height: 10),
                _SheetAction(
                  icon: Icons.close,
                  label: 'Cancel',
                  color: AppTheme.slate700,
                  background: AppTheme.slate100,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

}

/// One row in the message-options bottom sheet — pill-shaped, tinted
/// background that matches the action's color, large tap area.
class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;
  final Color? background;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.color,
    required this.onTap,
    this.background,
  });

  @override
  Widget build(BuildContext context) {
    final bg = background ?? color.withValues(alpha: 0.08);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          child: Row(
            children: [
              Icon(icon, color: color, size: 20),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  label,
                  style: TextStyle(
                    color: color,
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
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
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          top: BorderSide(color: AppTheme.slate100, width: 1),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 120),
              child: TextField(
                controller: controller,
                enabled: !isPosting,
                minLines: 1,
                maxLines: 5,
                textInputAction: TextInputAction.newline,
                decoration: InputDecoration(
                  hintText: 'Message',
                  isDense: true,
                  filled: true,
                  fillColor: AppTheme.slate100,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
          // The send button only takes space when there's text or we're
          // actively posting. AnimatedSwitcher gives it the WhatsApp-style
          // pop-in/pop-out feel when the user starts/stops typing.
          ValueListenableBuilder<TextEditingValue>(
            valueListenable: controller,
            builder: (context, value, _) {
              final hasText = value.text.trim().isNotEmpty;
              final showButton = hasText || isPosting;
              return AnimatedSwitcher(
                duration: const Duration(milliseconds: 180),
                switchInCurve: Curves.easeOut,
                switchOutCurve: Curves.easeIn,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: animation,
                  child: FadeTransition(opacity: animation, child: child),
                ),
                child: showButton
                    ? Padding(
                        key: const ValueKey('send-on'),
                        padding: const EdgeInsets.only(left: 8),
                        child: _SendButton(
                          isPosting: isPosting,
                          onTap: onSend,
                        ),
                      )
                    : const SizedBox(
                        key: ValueKey('send-off'),
                        width: 0,
                        height: 44,
                      ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  final bool isPosting;
  final VoidCallback onTap;

  const _SendButton({required this.isPosting, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppTheme.brandPrimary,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: isPosting ? null : onTap,
        child: SizedBox(
          width: 44,
          height: 44,
          child: isPosting
              ? const Padding(
                  padding: EdgeInsets.all(12),
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(
                  Icons.send_rounded,
                  color: Colors.white,
                  size: 20,
                ),
        ),
      ),
    );
  }
}
