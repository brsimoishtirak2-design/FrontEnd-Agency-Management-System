import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/attachment.dart';
import '../../../../shared/models/task.dart';
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

        // Pure read-only display now that the + FAB on the detail
        // screen handles upload via the dedicated picker route.
        if (briefs.isEmpty && submissions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Column(
          children: [
            if (briefs.isNotEmpty)
              _AttachmentGroup(
                label: 'Brief',
                icon: Icons.description_outlined,
                attachments: briefs,
              ),
            if (briefs.isNotEmpty && submissions.isNotEmpty)
              const SizedBox(height: 12),
            if (submissions.isNotEmpty)
              _AttachmentGroup(
                label: 'Submission',
                icon: Icons.cloud_upload_outlined,
                attachments: submissions,
              ),
          ],
        );
      },
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

  const _AttachmentGroup({
    required this.label,
    required this.icon,
    required this.attachments,
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
              ],
            ),
            const SizedBox(height: 4),
            for (final a in attachments)
              _AttachmentRow(attachment: a),
          ],
        ),
      ),
    );
  }
}

class _AttachmentRow extends ConsumerStatefulWidget {
  final Attachment attachment;

  const _AttachmentRow({required this.attachment});

  @override
  ConsumerState<_AttachmentRow> createState() => _AttachmentRowState();
}

class _AttachmentRowState extends ConsumerState<_AttachmentRow> {
  bool _isDownloading = false;

  Future<void> _handleTap() async {
    if (_isDownloading) return;
    setState(() => _isDownloading = true);

    try {
      final repo = ref.read(attachmentsRepositoryProvider);
      final bytes = await repo.downloadBytes(widget.attachment.id);

      // Save to temp dir using the original filename
      final tempDir = await getTemporaryDirectory();
      final safeName = widget.attachment.fileName
          .replaceAll(RegExp(r'[/\\]'), '_'); // strip path separators
      final file = File('${tempDir.path}/$safeName');
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

    return InkWell(
      onTap: _handleTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
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
                ],
              ),
            ),
            const SizedBox(width: 8),
            _isDownloading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: AppTheme.brandPrimary,
                    ),
                  )
                : Icon(
                    Icons.download_outlined,
                    size: 20,
                    color: AppTheme.slate500,
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
