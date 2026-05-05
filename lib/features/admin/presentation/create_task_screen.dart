import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_client.dart';
import '../../../shared/models/agency_user.dart';
import '../../../shared/models/task_priority.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/widgets/app_dropdown_states.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../../tasks/data/attachments_providers.dart';
import '../data/admin_clients_providers.dart';
import '../data/admin_tasks_providers.dart';
import '../data/admin_tasks_repository.dart';
import '../data/admin_users_providers.dart';
import 'widgets/assignee_picker_sheet.dart';

/// Form for admin to create a new task.
///
/// This is a multi-stage build. Currently supports:
///   - Title (required)
///   - Description (optional)
///   - Priority selector (Low/Medium/High/Urgent, default Medium)
///   - Deadline date + time pickers (both optional; time requires date)
///
/// Coming in next prompts:
///   - Client + branch dropdowns
///   - Assignee multi-select
///   - Brief attachments
///
/// Submit is currently DISABLED with a hint to add client + assignees.
class CreateTaskScreen extends ConsumerStatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  ConsumerState<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends ConsumerState<CreateTaskScreen> {
  final _formKey = GlobalKey<FormState>();
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();

  TaskPriority _priority = TaskPriority.medium;
  DateTime? _deadlineDate;
  TimeOfDay? _deadlineTime;
  AgencyClient? _selectedClient;
  AgencyClientBranch? _selectedBranch;
  final List<TaskAssigneeInput> _assignees = [];
  final List<PlatformFile> _briefFiles = [];
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();
    _titleController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadlineDate ?? today,
      firstDate: today,
      lastDate: today.add(const Duration(days: 365 * 2)),
    );
    if (picked != null) {
      setState(() => _deadlineDate = picked);
    }
  }

  Future<void> _pickTime() async {
    if (_deadlineDate == null) return; // guarded by UI but defensive
    final picked = await showTimePicker(
      context: context,
      initialTime: _deadlineTime ?? const TimeOfDay(hour: 17, minute: 0),
    );
    if (picked != null) {
      setState(() => _deadlineTime = picked);
    }
  }

  void _clearDate() {
    setState(() {
      _deadlineDate = null;
      _deadlineTime = null;
    });
  }

  void _clearTime() {
    setState(() => _deadlineTime = null);
  }

  Future<void> _openAssigneePicker() async {
    final currentIds = _assignees.map((a) => a.userId).toSet();
    final result = await AssigneePickerSheet.show(
      context,
      initiallySelected: currentIds,
    );
    if (result == null) return; // cancelled

    setState(() {
      // Build new assignee list from the returned ID set.
      // Preserve leader designation if the leader is still in the set.
      final existingLeaderId = _assignees
          .where((a) => a.isLeader)
          .map((a) => a.userId)
          .firstOrNull;

      final newAssignees = <TaskAssigneeInput>[];
      for (final id in result) {
        final isLeader = id == existingLeaderId;
        newAssignees.add(
          TaskAssigneeInput(userId: id, isLeader: isLeader),
        );
      }

      // If there's no leader (because previous leader was deselected),
      // promote the first one.
      if (newAssignees.isNotEmpty &&
          !newAssignees.any((a) => a.isLeader)) {
        newAssignees[0] = TaskAssigneeInput(
          userId: newAssignees[0].userId,
          isLeader: true,
        );
      }

      _assignees
        ..clear()
        ..addAll(newAssignees);
    });
  }

  void _makeLeader(int userId) {
    setState(() {
      for (var i = 0; i < _assignees.length; i++) {
        _assignees[i] = TaskAssigneeInput(
          userId: _assignees[i].userId,
          isLeader: _assignees[i].userId == userId,
        );
      }
    });
  }

  void _removeAssignee(int userId) {
    setState(() {
      _assignees.removeWhere((a) => a.userId == userId);
      // If we just removed the leader and others remain, promote first.
      if (_assignees.isNotEmpty &&
          !_assignees.any((a) => a.isLeader)) {
        _assignees[0] = TaskAssigneeInput(
          userId: _assignees[0].userId,
          isLeader: true,
        );
      }
    });
  }

  Future<void> _pickBriefFiles() async {
    final result = await FilePicker.pickFiles(
      type: FileType.any,
      allowMultiple: true,
      withData: false,
    );
    if (result == null) return;
    setState(() {
      // De-dupe by path so re-picking doesn't list the same file twice.
      final existingPaths = _briefFiles.map((f) => f.path).toSet();
      for (final f in result.files) {
        if (f.path != null && !existingPaths.contains(f.path)) {
          _briefFiles.add(f);
        }
      }
    });
  }

  void _removeBriefFile(PlatformFile file) {
    setState(() => _briefFiles.removeWhere((f) => f.path == file.path));
  }

  Future<void> _submit() async {
    // Run form validation first — catches empty title, etc.
    if (!_formKey.currentState!.validate()) return;
    // _canSubmit already enforced by button state, but defense-in-depth:
    if (_selectedClient == null || _assignees.isEmpty) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(adminTasksRepositoryProvider);
      final newTask = await repo.createTask(
        title: _titleController.text.trim(),
        description: _descriptionController.text.trim().isEmpty
            ? null
            : _descriptionController.text.trim(),
        clientId: _selectedClient!.id,
        clientBranchId: _selectedBranch?.id,
        priority: _priority.wireValue,
        deadlineDate: formatBackendDate(_deadlineDate),
        deadlineTime: formatBackendTime(_deadlineTime),
        assignees: _assignees,
      );

      // Upload any brief attachments AFTER the task exists. Failures
      // here don't roll back the task — surface a warning and let the
      // admin retry from the detail screen.
      String? briefWarning;
      if (_briefFiles.isNotEmpty) {
        try {
          final paths = _briefFiles
              .map((f) => f.path)
              .whereType<String>()
              .toList(growable: false);
          if (paths.isNotEmpty) {
            await ref.read(attachmentsRepositoryProvider).uploadBrief(
                  taskId: newTask.id,
                  filePaths: paths,
                );
            // Make sure the detail screen shows the new files.
            ref.invalidate(taskAttachmentsProvider(newTask.id));
          }
        } on ApiException catch (e) {
          briefWarning = 'Task created, but attachments failed: ${e.message}';
        } catch (e) {
          briefWarning = 'Task created, but attachments failed to upload.';
        }
      }

      // Refresh list so admin Tasks tab shows the new task immediately.
      ref.invalidate(adminAllTasksProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(briefWarning ?? 'Task "${newTask.title}" created.'),
          backgroundColor:
              briefWarning == null ? AppTheme.success : AppTheme.warning,
          behavior: SnackBarBehavior.floating,
          duration: Duration(seconds: briefWarning == null ? 3 : 5),
        ),
      );

      // Replace this screen with the new task's detail screen.
      // pushReplacement so back-button skips the form.
      context.pushReplacement(AppRoute.taskDetailPath(newTask.id));
    } on ApiException catch (e) {
      if (!mounted) return;
      // Show inline validation errors if 422; otherwise the generic message.
      String displayMessage = e.message;
      if (e.isValidationError && e.validationErrors != null) {
        // Concatenate the first error from each field.
        final firstErrors = e.validationErrors!.entries
            .map((entry) => '${entry.key}: ${entry.value.first}')
            .take(3)
            .join('\n');
        displayMessage = firstErrors;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not create task: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }


  bool get _canSubmit {
    if (_titleController.text.trim().isEmpty) return false;
    if (_selectedClient == null) return false;
    if (_assignees.isEmpty) return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Task'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // ----- Card 1 — Basics -----
                _FormCard(
                  title: 'Basics',
                  children: [
                    const AppSectionLabel('Title *'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _titleController,
                      textInputAction: TextInputAction.next,
                      inputFormatters: [
                        LengthLimitingTextInputFormatter(200),
                      ],
                      decoration: const InputDecoration(
                        hintText: 'e.g. Daily Instagram post for Cafe Aroma',
                      ),
                      validator: (v) {
                        final text = v?.trim() ?? '';
                        if (text.isEmpty) return 'Title is required.';
                        if (text.length > 200) return 'Max 200 characters.';
                        return null;
                      },
                    ),
                    const SizedBox(height: 16),
                    const AppSectionLabel('Description'),
                    const SizedBox(height: 6),
                    TextFormField(
                      controller: _descriptionController,
                      maxLines: 4,
                      textInputAction: TextInputAction.newline,
                      decoration: const InputDecoration(
                        hintText: 'Optional. What needs to be done?',
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ----- Card 2 — Schedule -----
                _FormCard(
                  title: 'Schedule',
                  children: [
                    const AppSectionLabel('Priority'),
                    const SizedBox(height: 8),
                    _PrioritySelector(
                      selected: _priority,
                      onChanged: (p) => setState(() => _priority = p),
                    ),
                    const SizedBox(height: 16),
                    const AppSectionLabel('Deadline'),
                    const SizedBox(height: 8),
                    _DateTimeRow(
                      date: _deadlineDate,
                      time: _deadlineTime,
                      onPickDate: _pickDate,
                      onPickTime: _pickTime,
                      onClearDate: _clearDate,
                      onClearTime: _clearTime,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ----- Card 3 — Client -----
                _FormCard(
                  title: 'Client',
                  children: [
                    const AppSectionLabel('Client *'),
                    const SizedBox(height: 6),
                    _ClientDropdown(
                      selected: _selectedClient,
                      onChanged: (client) {
                        setState(() {
                          _selectedClient = client;
                          _selectedBranch = null;
                        });
                      },
                    ),
                    if (_selectedClient != null) ...[
                      const SizedBox(height: 16),
                      const AppSectionLabel('Branch (optional)'),
                      const SizedBox(height: 6),
                      _BranchDropdown(
                        clientId: _selectedClient!.id,
                        selected: _selectedBranch,
                        onChanged: (branch) =>
                            setState(() => _selectedBranch = branch),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 16),

                // ----- Card 4 — Assignees -----
                _FormCard(
                  title: 'Assignees *',
                  children: [
                    _AssigneesSection(
                      assignees: _assignees,
                      onAdd: _openAssigneePicker,
                      onMakeLeader: _makeLeader,
                      onRemove: _removeAssignee,
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // ----- Card 5 — Brief attachments (optional) -----
                _FormCard(
                  title: 'Brief attachments (optional)',
                  children: [
                    _BriefAttachmentsSection(
                      files: _briefFiles,
                      onAdd: _isSubmitting ? null : _pickBriefFiles,
                      onRemove: _isSubmitting ? null : _removeBriefFile,
                    ),
                  ],
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: (_canSubmit && !_isSubmitting) ? _submit : null,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size.fromHeight(48),
                  ),
                  child: _isSubmitting
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text('Create Task'),
                ),
                const SizedBox(height: 8),
                if (!_canSubmit)
                  Text(
                    'Add a client and at least one assignee to enable submit.',
                    textAlign: TextAlign.center,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate500,
                        ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// FormCard — wraps a section's fields in a Card with title + breathing room
// ---------------------------------------------------------------------------

class _FormCard extends StatelessWidget {
  final String title;
  final List<Widget> children;

  const _FormCard({required this.title, required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title.toUpperCase(),
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppTheme.slate500,
                    letterSpacing: 0.6,
                  ),
            ),
            const SizedBox(height: 10),
            ...children,
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Priority selector — segmented buttons
// ---------------------------------------------------------------------------

class _PrioritySelector extends StatelessWidget {
  final TaskPriority selected;
  final ValueChanged<TaskPriority> onChanged;

  const _PrioritySelector({
    required this.selected,
    required this.onChanged,
  });

  static Color _colorFor(TaskPriority p) {
    switch (p) {
      case TaskPriority.low:
        return AppTheme.slate500;
      case TaskPriority.medium:
        return AppTheme.success;
      case TaskPriority.high:
        return AppTheme.warning;
      case TaskPriority.urgent:
        return AppTheme.error;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final p in TaskPriority.values) ...[
          Expanded(
            child: _PriorityPill(
              priority: p,
              color: _colorFor(p),
              isSelected: selected == p,
              onTap: () => onChanged(p),
            ),
          ),
          if (p != TaskPriority.urgent) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _PriorityPill extends StatelessWidget {
  final TaskPriority priority;
  final Color color;
  final bool isSelected;
  final VoidCallback onTap;

  const _PriorityPill({
    required this.priority,
    required this.color,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: isSelected ? color.withValues(alpha: 0.15) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
        side: BorderSide(
          color: isSelected ? color : AppTheme.slate200,
          width: isSelected ? 1.5 : 1,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          height: 36,
          child: Center(
            child: Text(
              priority.displayName,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: isSelected ? color : AppTheme.slate700,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Deadline date + time row
// ---------------------------------------------------------------------------

class _DateTimeRow extends StatelessWidget {
  final DateTime? date;
  final TimeOfDay? time;
  final VoidCallback onPickDate;
  final VoidCallback onPickTime;
  final VoidCallback onClearDate;
  final VoidCallback onClearTime;

  const _DateTimeRow({
    required this.date,
    required this.time,
    required this.onPickDate,
    required this.onPickTime,
    required this.onClearDate,
    required this.onClearTime,
  });

  @override
  Widget build(BuildContext context) {
    final dateText =
        date == null ? 'Pick date' : DateFormat('EEE, MMM d, yyyy').format(date!);
    final timeText = time == null
        ? 'Pick time'
        : time!.format(context);

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: onPickDate,
                icon: const Icon(Icons.event_outlined, size: 18),
                label: Text(
                  dateText,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            if (date != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Clear date',
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClearDate,
              ),
            ],
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: date == null ? null : onPickTime,
                icon: const Icon(Icons.schedule_outlined, size: 18),
                label: Text(
                  timeText,
                  overflow: TextOverflow.ellipsis,
                ),
                style: OutlinedButton.styleFrom(
                  alignment: Alignment.centerLeft,
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
            if (time != null) ...[
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Clear time',
                icon: const Icon(Icons.close, size: 20),
                onPressed: onClearTime,
              ),
            ],
          ],
        ),
        if (date == null) ...[
          const SizedBox(height: 4),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Pick a date first to set a time.',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.slate500,
                  ),
            ),
          ),
        ],
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Client dropdown
// ---------------------------------------------------------------------------

class _ClientDropdown extends ConsumerWidget {
  final AgencyClient? selected;
  final ValueChanged<AgencyClient?> onChanged;

  const _ClientDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientsAsync = ref.watch(adminClientsListProvider);

    return clientsAsync.when(
      loading: () => const AppDropdownLoading(),
      error: (error, _) => AppDropdownError(
        message: 'Could not load clients.',
        onRetry: () => ref.invalidate(adminClientsListProvider),
      ),
      data: (clients) {
        // Repo returns ALL clients; archived ones can't have new tasks
        // (backend rejects with 422), so hide them from the picker.
        final pickable = clients.where((c) => !c.isArchived).toList();
        if (pickable.isEmpty) {
          return const AppDropdownEmpty(
            message: 'No active clients found. Add a client first.',
          );
        }
        return DropdownButtonFormField<int>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select a client',
          ),
          items: pickable
              .map(
                (c) => DropdownMenuItem<int>(
                  value: c.id,
                  child: Text(
                    c.name,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) {
              onChanged(null);
              return;
            }
            final picked = clients.firstWhere((c) => c.id == id);
            onChanged(picked);
          },
          validator: (value) =>
              value == null ? 'Client is required.' : null,
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Branch dropdown — auto-fetches client detail (with branches) when shown
// ---------------------------------------------------------------------------

class _BranchDropdown extends ConsumerWidget {
  final int clientId;
  final AgencyClientBranch? selected;
  final ValueChanged<AgencyClientBranch?> onChanged;

  const _BranchDropdown({
    required this.clientId,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final clientAsync =
        ref.watch(adminClientWithBranchesProvider(clientId));

    return clientAsync.when(
      loading: () => const AppDropdownLoading(),
      error: (error, _) => AppDropdownError(
        message: 'Could not load branches.',
        onRetry: () =>
            ref.invalidate(adminClientWithBranchesProvider(clientId)),
      ),
      data: (client) {
        final branches = client.branches ?? const <AgencyClientBranch>[];
        if (branches.isEmpty) {
          return const AppDropdownEmpty(
            message: 'This client has no branches. You can leave it empty.',
          );
        }

        // Sort: primary first, then alphabetical
        final sorted = [...branches]..sort((a, b) {
          if (a.isPrimary && !b.isPrimary) return -1;
          if (!a.isPrimary && b.isPrimary) return 1;
          return a.branchName.compareTo(b.branchName);
        });

        return DropdownButtonFormField<int>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select a branch (optional)',
          ),
          items: sorted
              .map(
                (b) => DropdownMenuItem<int>(
                  value: b.id,
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          b.displayLabel,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (b.isPrimary) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: AppTheme.brandPrimary,
                            borderRadius: BorderRadius.circular(4),
                          ),
                          child: const Text(
                            'Primary',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) {
              onChanged(null);
              return;
            }
            final picked = sorted.firstWhere((b) => b.id == id);
            onChanged(picked);
          },
        );
      },
    );
  }
}

// ---------------------------------------------------------------------------
// Assignees section — chips + Add button
// ---------------------------------------------------------------------------

class _AssigneesSection extends ConsumerWidget {
  final List<TaskAssigneeInput> assignees;
  final VoidCallback onAdd;
  final ValueChanged<int> onMakeLeader;
  final ValueChanged<int> onRemove;

  const _AssigneesSection({
    required this.assignees,
    required this.onAdd,
    required this.onMakeLeader,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Lookup map for displaying user names — read the cached provider value.
    final usersAsync = ref.watch(adminActiveEmployeesProvider);
    final users = usersAsync.maybeWhen(
      data: (list) => list,
      orElse: () => const <AgencyUser>[],
    );
    final userById = {for (final u in users) u.id: u};

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (assignees.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.slate100, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No assignees yet. Tap "Add assignees" to pick employees.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final a in assignees)
                _AssigneeChip(
                  assignee: a,
                  user: userById[a.userId],
                  onMakeLeader: () => onMakeLeader(a.userId),
                  onRemove: () => onRemove(a.userId),
                ),
            ],
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.person_add_alt_1, size: 18),
          label: Text(
            assignees.isEmpty ? 'Add assignees' : 'Edit assignees',
          ),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
        if (assignees.length > 1) ...[
          const SizedBox(height: 6),
          Text(
            'Tap a chip to make that person the leader.',
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: AppTheme.slate500,
                ),
          ),
        ],
      ],
    );
  }
}

class _AssigneeChip extends StatelessWidget {
  final TaskAssigneeInput assignee;
  final AgencyUser? user;
  final VoidCallback onMakeLeader;
  final VoidCallback onRemove;

  const _AssigneeChip({
    required this.assignee,
    required this.user,
    required this.onMakeLeader,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    final name = user?.name ?? 'User #${assignee.userId}';
    final isLeader = assignee.isLeader;

    return InkWell(
      onTap: isLeader ? null : onMakeLeader,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 6, 6),
        decoration: BoxDecoration(
          color: isLeader
              ? AppTheme.brandPrimary.withValues(alpha: 0.15)
              : AppTheme.slate100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isLeader
                ? AppTheme.brandPrimary
                : AppTheme.slate100,
            width: 1,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              name,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: isLeader
                        ? AppTheme.brandPrimaryDark
                        : AppTheme.slate900,
                  ),
            ),
            if (isLeader) ...[
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 6,
                  vertical: 1,
                ),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Leader',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
            const SizedBox(width: 4),
            InkWell(
              onTap: onRemove,
              borderRadius: BorderRadius.circular(20),
              child: Padding(
                padding: const EdgeInsets.all(2),
                child: Icon(
                  Icons.close,
                  size: 16,
                  color: isLeader
                      ? AppTheme.brandPrimaryDark
                      : AppTheme.slate500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Brief attachments section — file rows + Add button
// ---------------------------------------------------------------------------

class _BriefAttachmentsSection extends StatelessWidget {
  final List<PlatformFile> files;
  final VoidCallback? onAdd;
  final ValueChanged<PlatformFile>? onRemove;

  const _BriefAttachmentsSection({
    required this.files,
    required this.onAdd,
    required this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (files.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              border: Border.all(color: AppTheme.slate100, width: 1.5),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              'No attachments yet. Add reference files the assignees '
              'can read alongside the task.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                    fontStyle: FontStyle.italic,
                  ),
            ),
          )
        else
          Column(
            children: [
              for (final f in files)
                _BriefFileRow(file: f, onRemove: () => onRemove?.call(f)),
            ],
          ),
        const SizedBox(height: 10),
        OutlinedButton.icon(
          onPressed: onAdd,
          icon: const Icon(Icons.attach_file_rounded, size: 18),
          label: Text(files.isEmpty ? 'Add files' : 'Add more files'),
          style: OutlinedButton.styleFrom(
            minimumSize: const Size.fromHeight(44),
          ),
        ),
      ],
    );
  }
}

class _BriefFileRow extends StatelessWidget {
  final PlatformFile file;
  final VoidCallback? onRemove;

  const _BriefFileRow({required this.file, required this.onRemove});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
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
              _iconFor(file.extension),
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
                  file.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                      ),
                ),
                const SizedBox(height: 2),
                Text(
                  _displaySize(file.size),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                        color: AppTheme.slate500,
                      ),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Remove',
            icon: const Icon(Icons.close, size: 20),
            color: AppTheme.slate500,
            onPressed: onRemove,
          ),
        ],
      ),
    );
  }

  static String _displaySize(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  static IconData _iconFor(String? ext) {
    switch (ext?.toLowerCase()) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'webp':
      case 'gif':
        return Icons.image_outlined;
      case 'pdf':
        return Icons.picture_as_pdf_outlined;
      case 'mp4':
      case 'mov':
      case 'avi':
        return Icons.movie_outlined;
      case 'xlsx':
      case 'xls':
      case 'csv':
        return Icons.table_chart_outlined;
      case 'doc':
      case 'docx':
        return Icons.description_outlined;
      case 'zip':
      case 'rar':
      case '7z':
        return Icons.folder_zip_outlined;
      default:
        return Icons.insert_drive_file_outlined;
    }
  }
}
