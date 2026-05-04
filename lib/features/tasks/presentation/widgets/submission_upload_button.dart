import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/task.dart';
import '../../../../shared/models/task_status.dart';
import '../../../auth/data/auth_providers.dart';
import '../../data/attachments_providers.dart';

/// Button shown above the submission attachment list when the current user
/// is the leader AND the task is in a state that allows submission uploads
/// (in_progress or changes_requested).
///
/// Otherwise renders nothing.
class SubmissionUploadButton extends ConsumerStatefulWidget {
  final Task task;

  const SubmissionUploadButton({super.key, required this.task});

  @override
  ConsumerState<SubmissionUploadButton> createState() =>
      _SubmissionUploadButtonState();
}

class _SubmissionUploadButtonState
    extends ConsumerState<SubmissionUploadButton> {
  bool _isUploading = false;

  /// Allowed extensions per the backend (Day 11 constants).
  static const _allowedExtensions = [
    'jpg',
    'jpeg',
    'png',
    'webp',
    'mp4',
    'mov',
    'pdf',
    'docx',
    'xlsx',
    'zip',
  ];

  bool _shouldShow() {
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) return false;
    if (!widget.task.isLeaderUser(auth.user.id)) return false;

    final status = widget.task.status;
    return status == TaskStatus.inProgress ||
        status == TaskStatus.changesRequested;
  }

  Future<void> _pickAndUpload() async {
    setState(() => _isUploading = true);

    try {
      // Open the OS file picker — multi-file with extension filter.
      final result = await FilePicker.pickFiles(
        allowMultiple: true,
        type: FileType.custom,
        allowedExtensions: _allowedExtensions,
        withData: false, // we use file paths, not in-memory bytes
      );

      if (result == null || result.files.isEmpty) {
        // User cancelled
        return;
      }

      final paths = result.files
          .map((f) => f.path)
          .whereType<String>()
          .toList(growable: false);

      if (paths.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not read selected files.'),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
        return;
      }

      final repo = ref.read(attachmentsRepositoryProvider);
      final uploaded = await repo.uploadSubmission(
        taskId: widget.task.id,
        filePaths: paths,
      );

      // Refresh the attachment list so the new files appear.
      ref.invalidate(taskAttachmentsProvider(widget.task.id));

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            uploaded.length == 1
                ? 'Uploaded 1 file.'
                : 'Uploaded ${uploaded.length} files.',
          ),
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
          content: Text('Upload failed: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_shouldShow()) return const SizedBox.shrink();

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.cloud_upload_outlined,
                  size: 16,
                  color: AppTheme.slate500,
                ),
                const SizedBox(width: 6),
                Text(
                  'SUBMISSION FILES',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.slate500,
                        fontWeight: FontWeight.w700,
                        letterSpacing: 0.8,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Attach your work for the admin to review.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                  ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _isUploading ? null : _pickAndUpload,
              style: ElevatedButton.styleFrom(
                minimumSize: const Size.fromHeight(44),
              ),
              child: _isUploading
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Row(
                      mainAxisSize: MainAxisSize.min,
                      children: const [
                        Icon(Icons.add_rounded, size: 18),
                        SizedBox(width: 6),
                        Text('Add Files'),
                      ],
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              'Allowed: jpg, png, webp, mp4, mov, pdf, docx, xlsx, zip · max 25MB each',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.slate500,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
