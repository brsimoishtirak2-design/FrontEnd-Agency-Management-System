import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/comment.dart';
import '../../auth/data/auth_providers.dart';
import 'comments_repository.dart';

/// Provides the CommentsRepository as a singleton.
final commentsRepositoryProvider = Provider<CommentsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return CommentsRepository(api);
});

/// Auto-fetched list of comments for a specific task (keyed by taskId).
///
/// UI reads with: ref.watch(taskCommentsProvider(taskId))
/// Refresh with: ref.invalidate(taskCommentsProvider(taskId))
final taskCommentsProvider =
    FutureProvider.family<List<Comment>, int>((ref, taskId) async {
  final repo = ref.watch(commentsRepositoryProvider);
  return repo.listForTask(taskId);
});

/// In-memory "last seen comments at" marker keyed by task id. The
/// comments screen sets this to `now()` whenever it opens; the unread
/// count derives from comments newer than this marker.
///
/// State doesn't survive an app restart, so after a fresh launch every
/// task with comments will surface as having unread items until the
/// user opens that thread once. Acceptable trade-off for now;
/// persistence can move to secure_storage later.
class CommentsLastSeenNotifier extends StateNotifier<Map<int, DateTime>> {
  CommentsLastSeenNotifier() : super(const {});

  void markSeen(int taskId) {
    state = {...state, taskId: DateTime.now()};
  }
}

final commentsLastSeenProvider =
    StateNotifierProvider<CommentsLastSeenNotifier, Map<int, DateTime>>(
        (ref) => CommentsLastSeenNotifier());

/// Cached at the moment of first access — used as the implicit baseline
/// for "unread" when the user has not yet opened a task's chat. Only
/// comments created AFTER this point count toward the unread badge,
/// so historical comments don't backfill on first encounter.
final appStartTimeProvider = Provider<DateTime>((_) => DateTime.now());

/// Task id whose comments screen is currently visible, or null when
/// the comments screen isn't on top. The screen sets this in initState
/// and clears it in dispose so background components (like the FCM
/// foreground handler) can suppress redundant UI.
final activeCommentsTaskProvider = StateProvider<int?>((ref) => null);

/// Number of comments on [taskId] that the current user hasn't seen
/// yet, excluding their own messages. Returns 0 while the comment list
/// is loading or errors.
///
/// Baseline: when the user has explicitly opened this task's chat
/// during the session, [commentsLastSeenProvider] holds an exact
/// timestamp and we count from there. Otherwise we fall back to
/// [appStartTimeProvider] — comments older than the app launch don't
/// backfill as unread, but anything that arrives while the user is
/// using the app DOES count, so the FAB badge surfaces new chatter
/// even on tasks the user hasn't opened yet.
final unreadCommentsCountProvider =
    Provider.family<int, int>((ref, taskId) {
  final explicitLastSeen =
      ref.watch(commentsLastSeenProvider)[taskId];
  final DateTime baseline =
      explicitLastSeen ?? ref.watch(appStartTimeProvider);

  final auth = ref.watch(authStateProvider);
  final myId = auth is AuthAuthenticated ? auth.user.id : null;
  final commentsAsync = ref.watch(taskCommentsProvider(taskId));

  return commentsAsync.maybeWhen(
    data: (comments) {
      var count = 0;
      for (final c in comments) {
        if (c.userId == myId) continue;
        final created = DateTime.tryParse(c.createdAt);
        if (created == null) continue;
        if (created.isAfter(baseline)) count++;
      }
      return count;
    },
    orElse: () => 0,
  );
});
