import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/router/app_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/attachment.dart';
import '../../../../shared/models/task.dart';
import '../../../../shared/models/task_status.dart';
import '../../../../shared/models/user.dart';
import '../../../../shared/utils/date_format.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/attachments_providers.dart';

/// Attachments section shown on the task detail screen.
///
/// Groups attachments by purpose:
///   - Brief: files admin attached when creating the task
///   - Submission: files the leader uploaded when submitting work
///
/// Read-only in this prompt. Upload UI comes in the next prompt.
class AttachmentsSection extends ConsumerWidget {
  final Task task;

  const AttachmentsSection({super.key, required this.task});

  int get taskId => task.id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final attachmentsAsync = ref.watch(taskAttachmentsProvider(taskId));
    final auth = ref.watch(authStateProvider);
    final canAddBrief = _canAdminAddBrief(auth);
    final canAddSubmission = _canLeaderAddSubmission(auth);

    return attachmentsAsync.when(
      loading: () => const _LoadingCard(),
      error: (error, _) => _ErrorCard(
        message: error.toString(),
        onRetry: () => ref.invalidate(taskAttachmentsProvider(taskId)),
      ),
      data: (attachments) {
        // Filter task-level attachments only (not comment attachments)
        final taskAttachments =
            attachments.where((a) => a.commentId == null).toList();

        final briefs = taskAttachments
            .where((a) => a.isBrief)
            .toList(growable: false);
        final submissions = taskAttachments
            .where((a) => a.isSubmission)
            .toList(growable: false);

        void goPicker() => context.push(AppRoute.taskAttachPath(taskId));

        // Nothing to show and nobody can upload — render nothing.
        if (briefs.isEmpty &&
            submissions.isEmpty &&
            !canAddBrief &&
            !canAddSubmission) {
          return const SizedBox.shrink();
        }

        return Column(
          children: [
            // --- BRIEF ---
            if (briefs.isNotEmpty)
              _AttachmentGroup(
                label: 'Brief',
                icon: Icons.description_outlined,
                attachments: briefs,
                trailing: canAddBrief
                    ? IconButton(
                        tooltip: 'Add brief files',
                        icon: const Icon(Icons.add, size: 20),
                        color: AppTheme.brandPrimaryDark,
                        onPressed: goPicker,
                      )
                    : null,
              )
            else if (canAddBrief)
              _EmptyUploadCard(
                title: 'No brief files yet',
                subtitle: 'Add reference material the assignees can read.',
                icon: Icons.description_outlined,
                onAdd: goPicker,
              ),

            if ((briefs.isNotEmpty || canAddBrief) &&
                (submissions.isNotEmpty || canAddSubmission))
              const SizedBox(height: 12),

            // --- SUBMISSION ---
            if (submissions.isNotEmpty)
              _AttachmentGroup(
                label: 'Submission',
                icon: Icons.cloud_upload_outlined,
                attachments: submissions,
                trailing: canAddSubmission
                    ? IconButton(
                        tooltip: 'Add files',
                        icon: const Icon(Icons.add, size: 20),
                        color: AppTheme.brandPrimaryDark,
                        onPressed: goPicker,
                      )
                    : null,
              )
            else if (canAddSubmission)
              _EmptyUploadCard(
                title: 'No submission files yet',
                subtitle: 'Tap to attach work for the admin to review.',
                icon: Icons.cloud_upload_outlined,
                onAdd: goPicker,
              ),
          ],
        );
      },
    );
  }

  /// Admin can add brief attachments anytime EXCEPT when the task is
  /// in a terminal state (approved or cancelled).
  bool _canAdminAddBrief(AuthState auth) {
    if (auth is! AuthAuthenticated) return false;
    if (!auth.user.isAdmin) return false;
    return task.status != TaskStatus.approved &&
        task.status != TaskStatus.cancelled;
  }

  /// Leader can add submission files only while work is in flight.
  bool _canLeaderAddSubmission(AuthState auth) {
    if (auth is! AuthAuthenticated) return false;
    if (!task.isLeaderUser(auth.user.id)) return false;
    return task.status == TaskStatus.inProgress ||
        task.status == TaskStatus.changesRequested;
  }
}

/// Minimal CTA card used when a section has no files yet but the
/// current user is allowed to upload — used for both Brief (admin)
/// and Submission (leader) empty states.
class _EmptyUploadCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onAdd;

  const _EmptyUploadCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onAdd,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  icon,
                  size: 18,
                  color: AppTheme.brandPrimaryDark,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      subtitle,
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slate500,
                          ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.add, size: 22, color: AppTheme.slate500),
            ],
          ),
        ),
      ),
    );
  }
}

class _LoadingCard extends StatelessWidget {
  const _LoadingCard();

  @override
  Widget build(BuildContext context) {
    return const Card(
      child: Padding(
        padding: EdgeInsets.symmetric(vertical: 18),
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
    );
  }
}

class _ErrorCard extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorCard({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            Icon(Icons.error_outline, color: AppTheme.error, size: 18),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Could not load attachments. ${message.replaceAll('ApiException', '').trim()}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.error,
                    ),
              ),
            ),
            TextButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

class _AttachmentGroup extends StatelessWidget {
  final String label;
  final IconData icon;
  final List<Attachment> attachments;

  /// Optional widget rendered on the right edge of the header row
  /// (e.g. an "Add files" icon button for the leader on the
  /// Submission group).
  final Widget? trailing;

  const _AttachmentGroup({
    required this.label,
    required this.icon,
    required this.attachments,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 16, color: AppTheme.slate500),
                const SizedBox(width: 6),
                Text(
                  label.toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.slate500,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Text(
                    '${attachments.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate700,
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                ),
                if (trailing != null) ...[
                  const Spacer(),
                  trailing!,
                ],
              ],
            ),
            const SizedBox(height: 4),
            for (final a in attachments)
              _AttachmentRow(attachment: a, taskId: a.taskId),
          ],
        ),
      ),
    );
  }
}

class _AttachmentRow extends ConsumerStatefulWidget {
  final Attachment attachment;
  final int taskId;

  const _AttachmentRow({required this.attachment, required this.taskId});

  @override
  ConsumerState<_AttachmentRow> createState() => _AttachmentRowState();
}

class _AttachmentRowState extends ConsumerState<_AttachmentRow> {
  bool _isDownloading = false;
  bool _isDeleting = false;

  /// True when the current user is allowed to delete this attachment:
  /// admin OR the original uploader.
  bool _canDelete() {
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) return false;
    return auth.user.isAdmin || auth.user.id == widget.attachment.uploadedBy;
  }

  Future<void> _handleDelete() async {
    if (_isDeleting) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete file?'),
        content: Text(
          'This will permanently remove "${widget.attachment.fileName}". '
          'This cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _isDeleting = true);
    try {
      await ref.read(attachmentsRepositoryProvider).delete(
            taskId: widget.taskId,
            attachmentId: widget.attachment.id,
          );
      ref.invalidate(taskAttachmentsProvider(widget.taskId));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('File deleted.'),
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
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  Future<void> _handleTap() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final repo = ref.read(attachmentsRepositoryProvider);
      final bytes = await repo.downloadBytes(widget.attachment.id);

      // Save to temp dir using the original filename. On macOS the
      // sandbox container's Caches subdirectory isn't always created
      // up-front, so create it explicitly before writing — otherwise
      // the write fails with PathNotFoundException.
      final tempDir = await getTemporaryDirectory();
      final safeName = widget.attachment.fileName
          .replaceAll(RegExp(r'[/\\]'), '_'); // strip path separators
      final file = File('${tempDir.path}/$safeName');
      await file.parent.create(recursive: true);
      await file.writeAsBytes(bytes, flush: true);

      // Open with system viewer
      final result = await OpenFilex.open(file.path);

      if (!mounted) return;
      if (result.type != ResultType.done) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open file: ${result.message}'),
            backgroundColor: AppTheme.warning,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not save file: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDownloading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.attachment;
    final canDelete = _canDelete();
    final uploadedAt = formatFullDateTime(a.createdAt);

    return InkWell(
      onTap: _isDeleting ? null : _handleTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: AppTheme.slate100,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Icon(
                _iconFor(a.iconKey),
                size: 18,
                color: AppTheme.slate700,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    a.fileName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${a.displaySize}  ·  ${a.uploaderName}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate500,
                        ),
                  ),
                  const SizedBox(height: 1),
                  Text(
                    uploadedAt,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate500,
                        ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 4),
            _isDownloading
                ? const Padding(
                    padding: EdgeInsets.all(8),
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.brandPrimary,
                      ),
                    ),
                  )
                : IconButton(
                    tooltip: 'Download',
                    icon: const Icon(Icons.download_outlined, size: 20),
                    color: AppTheme.slate500,
                    onPressed: _isDeleting ? null : _handleTap,
                  ),
            if (canDelete)
              _isDeleting
                  ? const Padding(
                      padding: EdgeInsets.all(8),
                      child: SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.error,
                        ),
                      ),
                    )
                  : IconButton(
                      tooltip: 'Delete',
                      icon: const Icon(Icons.delete_outline, size: 20),
                      color: AppTheme.error,
                      onPressed: _isDownloading ? null : _handleDelete,
                    ),
          ],
        ),
      ),
    );
  }

  IconData _iconFor(String key) {
    switch (key) {
      case 'image':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'video':
        return Icons.movie_outlined;
      case 'spreadsheet':
        return Icons.table_chart_outlined;
      case 'document':
        return Icons.description_outlined;
      case 'archive':
        return Icons.folder_zip_outlined;
      case 'file':
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
