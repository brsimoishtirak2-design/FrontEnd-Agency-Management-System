import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/task.dart';
import '../../../shared/models/task_status.dart';
import '../../../shared/models/user.dart';
import '../../auth/data/auth_providers.dart';
import '../data/attachments_providers.dart';
import '../data/tasks_providers.dart';

/// Full-screen picker that lets the leader choose what kind of file to
/// attach to a task — Image, Video, or File. Picks via the OS file
/// picker, uploads through [AttachmentsRepository.uploadSubmission],
/// then pops back to the task detail screen.
///
/// The screen renders a "not available" state when the current user
/// isn't allowed to attach (not the leader, or the task isn't in a
/// submittable state). The FAB on the detail screen is also gated, so
/// in normal usage the unavailable state shouldn't be reached.
class TaskAttachPickerScreen extends ConsumerStatefulWidget {
  final int taskId;

  const TaskAttachPickerScreen({super.key, required this.taskId});

  @override
  ConsumerState<TaskAttachPickerScreen> createState() =>
      _TaskAttachPickerScreenState();
}

enum _PickerKind { image, video, file }

/// Who is uploading and therefore which `purpose` the file gets.
/// `brief`  → admin attaching reference material (any non-terminal status).
/// `submission` → leader uploading work (in_progress / changes_requested).
enum _AttachRole { admin, leader }

class _TaskAttachPickerScreenState
    extends ConsumerState<TaskAttachPickerScreen> {
  bool _isUploading = false;

  /// Returns the role under which the current user is allowed to
  /// attach files to this task, or null if they aren't.
  _AttachRole? _resolveRole(Task task) {
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) return null;
    final user = auth.user;

    // Admin: can add briefs anytime EXCEPT terminal states.
    if (user.isAdmin) {
      if (task.status == TaskStatus.approved ||
          task.status == TaskStatus.cancelled) {
        return null;
      }
      return _AttachRole.admin;
    }

    // Leader: can add submission files in-progress or changes-requested.
    if (task.isLeaderUser(user.id)) {
      if (task.status == TaskStatus.inProgress ||
          task.status == TaskStatus.changesRequested) {
        return _AttachRole.leader;
      }
    }
    return null;
  }

  Future<void> _pickAndUpload(_PickerKind kind, _AttachRole role) async {
    if (_isUploading) return;
    setState(() => _isUploading = true);

    try {
      final FilePickerResult? result;
      switch (kind) {
        case _PickerKind.image:
          result = await FilePicker.pickFiles(
            type: FileType.image,
            allowMultiple: true,
            withData: false,
          );
          break;
        case _PickerKind.video:
          result = await FilePicker.pickFiles(
            type: FileType.video,
            allowMultiple: true,
            withData: false,
          );
          break;
        case _PickerKind.file:
          result = await FilePicker.pickFiles(
            type: FileType.custom,
            allowedExtensions: const ['pdf', 'docx', 'xlsx', 'zip'],
            allowMultiple: true,
            withData: false,
          );
          break;
      }

      if (result == null || result.files.isEmpty) {
        if (mounted) setState(() => _isUploading = false);
        return; // user cancelled
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
      final uploaded = role == _AttachRole.admin
          ? await repo.uploadBrief(
              taskId: widget.taskId,
              filePaths: paths,
            )
          : await repo.uploadSubmission(
              taskId: widget.taskId,
              filePaths: paths,
            );

      ref.invalidate(taskAttachmentsProvider(widget.taskId));

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
      context.pop();
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
    final taskAsync = ref.watch(taskDetailProvider(widget.taskId));

    return Scaffold(
      appBar: AppBar(title: const Text('Attach files')),
      body: taskAsync.when(
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
          onRetry: () =>
              ref.invalidate(taskDetailProvider(widget.taskId)),
        ),
        data: (task) {
          final role = _resolveRole(task);
          if (role == null) {
            return const _NotAllowed();
          }
          return _PickerBody(
            role: role,
            isUploading: _isUploading,
            onPick: (kind) => _pickAndUpload(kind, role),
          );
        },
      ),
    );
  }
}

class _PickerBody extends StatelessWidget {
  final _AttachRole role;
  final bool isUploading;
  final void Function(_PickerKind) onPick;

  const _PickerBody({
    required this.role,
    required this.isUploading,
    required this.onPick,
  });

  @override
  Widget build(BuildContext context) {
    final isAdmin = role == _AttachRole.admin;
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          Text(
            isAdmin
                ? 'Add reference files'
                : 'What do you want to attach?',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: AppTheme.slate900,
                ),
          ),
          const SizedBox(height: 4),
          Text(
            isAdmin
                ? 'Files added here show up under "Brief" for the assignees. '
                  'Multi-select is supported. Max 25 MB per file.'
                : 'Pick a category — you can choose multiple files at once. '
                  'Max 25 MB per file.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppTheme.slate500,
                ),
          ),
          const SizedBox(height: 20),
          _PickerTile(
            icon: Icons.image_outlined,
            label: 'Images',
            description: 'JPG · PNG · WEBP',
            color: AppTheme.info,
            disabled: isUploading,
            onTap: () => onPick(_PickerKind.image),
          ),
          const SizedBox(height: 12),
          _PickerTile(
            icon: Icons.movie_outlined,
            label: 'Videos',
            description: 'MP4 · MOV',
            color: AppTheme.warning,
            disabled: isUploading,
            onTap: () => onPick(_PickerKind.video),
          ),
          const SizedBox(height: 12),
          _PickerTile(
            icon: Icons.description_outlined,
            label: 'Files',
            description: 'PDF · DOCX · XLSX · ZIP',
            color: AppTheme.brandPrimary,
            disabled: isUploading,
            onTap: () => onPick(_PickerKind.file),
          ),
          if (isUploading) ...[
            const SizedBox(height: 24),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppTheme.brandPrimary,
                  ),
                ),
                const SizedBox(width: 10),
                Text(
                  'Uploading…',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.slate500,
                      ),
                ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String description;
  final Color color;
  final bool disabled;
  final VoidCallback onTap;

  const _PickerTile({
    required this.icon,
    required this.label,
    required this.description,
    required this.color,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      label,
                      style: Theme.of(context).textTheme.titleMedium
                          ?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppTheme.slate900,
                          ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: Theme.of(context).textTheme.bodySmall
                          ?.copyWith(color: AppTheme.slate500),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right,
                color: AppTheme.slate300,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotAllowed extends StatelessWidget {
  const _NotAllowed();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.lock_outline,
              size: 48,
              color: AppTheme.slate300,
            ),
            const SizedBox(height: 12),
            Text(
              'Attaching is not available right now',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate700,
                  ),
            ),
            const SizedBox(height: 6),
            Text(
              'Only the task leader can attach submission files, and '
              'only while the task is in progress or changes have been '
              'requested.',
              textAlign: TextAlign.center,
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
              'Could not load task',
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
