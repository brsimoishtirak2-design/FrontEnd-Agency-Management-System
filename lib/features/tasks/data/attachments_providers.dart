import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/providers.dart';
import '../../../shared/models/attachment.dart';
import 'attachments_repository.dart';

/// Provides the AttachmentsRepository as a singleton.
final attachmentsRepositoryProvider = Provider<AttachmentsRepository>((ref) {
  final api = ref.watch(apiClientProvider);
  return AttachmentsRepository(api);
});

/// Auto-fetched list of attachments for a specific task (keyed by taskId).
///
/// UI reads with: `ref.watch(taskAttachmentsProvider(taskId))`
/// Refresh with: `ref.invalidate(taskAttachmentsProvider(taskId))`
final taskAttachmentsProvider =
    FutureProvider.family<List<Attachment>, int>((ref, taskId) async {
  final repo = ref.watch(attachmentsRepositoryProvider);
  return repo.listForTask(taskId);
});
