import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_department.dart';
import '../../../shared/models/agency_location.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../data/admin_departments_providers.dart';
import '../data/admin_locations_providers.dart';

/// Dual-mode form for creating OR editing a department.
class DepartmentFormScreen extends ConsumerStatefulWidget {
  final AgencyDepartment? initialDepartment;

  const DepartmentFormScreen({super.key, this.initialDepartment});

  @override
  ConsumerState<DepartmentFormScreen> createState() =>
      _DepartmentFormScreenState();
}

class _DepartmentFormScreenState
    extends ConsumerState<DepartmentFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  AgencyLocation? _selectedLocation;
  bool _isActive = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  // One-shot guard: locations list arrives async; only pre-fill once.
  bool _locationPreFilled = false;

  bool get _isEditing => widget.initialDepartment != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));

    final initial = widget.initialDepartment;
    if (initial != null) {
      _nameController.text = initial.name;
      _isActive = initial.isActive;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting || _isDeleting) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_selectedLocation == null) return false;
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedLocation == null) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(adminDepartmentsRepositoryProvider);
      final name = _nameController.text.trim();

      final draft = AgencyDepartment(
        id: widget.initialDepartment?.id ?? 0,
        name: name,
        locationId: _selectedLocation!.id,
        locationName: _selectedLocation!.name,
        isActive: _isActive,
      );

      final AgencyDepartment result;
      if (_isEditing) {
        result = await repo.updateDepartment(
          widget.initialDepartment!.id,
          draft.toJsonForUpdate(),
        );
        ref.invalidate(
          adminDepartmentDetailProvider(widget.initialDepartment!.id),
        );
      } else {
        result = await repo.createDepartment(draft);
      }

      ref.invalidate(adminDepartmentsListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Department "${result.name}" '
            '${_isEditing ? "updated" : "created"}.',
          ),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;
      String displayMessage = e.message;
      if (e.isValidationError && e.validationErrors != null) {
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
          content: Text(
            _isEditing
                ? 'Could not update department: $e'
                : 'Could not create department: $e',
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  Future<void> _handleDelete() async {
    final initial = widget.initialDepartment;
    if (initial == null) return;

    final locName = initial.locationName ?? '—';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete department?'),
        content: Text(
          'Permanently delete "${initial.name}" in $locName? '
          'If users are linked, deletion is blocked — use "Archive" '
          'instead.',
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
    if (!mounted) return;

    setState(() => _isDeleting = true);
    try {
      final repo = ref.read(adminDepartmentsRepositoryProvider);
      await repo.deleteDepartment(initial.id);

      ref.invalidate(adminDepartmentsListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Department "${initial.name}" deleted.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;

      if (e.statusCode == 409) {
        final archive = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Cannot delete'),
            content: Text(e.message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(ctx).pop(false),
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.brandPrimary,
                  foregroundColor: Colors.white,
                ),
                onPressed: () => Navigator.of(ctx).pop(true),
                child: const Text('Archive instead'),
              ),
            ],
          ),
        );

        if (archive == true && mounted) {
          try {
            await ref
                .read(adminDepartmentsRepositoryProvider)
                .archiveDepartment(initial.id);
            ref.invalidate(adminDepartmentsListProvider);
            ref.invalidate(adminDepartmentDetailProvider(initial.id));

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Department "${initial.name}" archived.',
                ),
                backgroundColor: AppTheme.success,
                behavior: SnackBarBehavior.floating,
              ),
            );
            context.pop();
          } on ApiException catch (e2) {
            if (!mounted) return;
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(e2.message),
                backgroundColor: AppTheme.error,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        }
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(e.message),
            backgroundColor: AppTheme.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not delete department: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isDeleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // One-shot async pre-fill of location dropdown for edit mode.
    ref.listen<AsyncValue<List<AgencyLocation>>>(
      adminLocationsListProvider,
      (prev, next) {
        if (_locationPreFilled) return;
        if (!_isEditing) return;
        final locId = widget.initialDepartment?.locationId;
        if (locId == null) {
          _locationPreFilled = true;
          return;
        }
        next.whenData((locations) {
          final match =
              locations.where((l) => l.id == locId).firstOrNull;
          if (match != null && _selectedLocation == null) {
            setState(() {
              _selectedLocation = match;
              _locationPreFilled = true;
            });
          } else {
            _locationPreFilled = true;
          }
        });
      },
    );

    return Scaffold(
      appBar: AppBar(
        title:
            Text(_isEditing ? 'Edit Department' : 'New Department'),
        actions: _isEditing
            ? [
                IconButton(
                  tooltip: 'Delete',
                  icon: const Icon(Icons.delete_outline),
                  onPressed: (_isSubmitting || _isDeleting)
                      ? null
                      : _handleDelete,
                ),
              ]
            : null,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AppSectionLabel('Location *'),
                const SizedBox(height: 6),
                _LocationDropdown(
                  selected: _selectedLocation,
                  onChanged: (loc) {
                    setState(() {
                      _selectedLocation = loc;
                      _locationPreFilled = true;
                    });
                  },
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: const InputDecoration(
                    hintText: 'e.g. Technology, Marketing',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Name is required.';
                    if (text.length > 100) return 'Max 100 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Active',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'Inactive departments are hidden from new '
                      'employee assignment.',
                    ),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
                const SizedBox(height: 24),

                ElevatedButton(
                  onPressed: _canSubmit ? _submit : null,
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
                      : Text(
                          _isEditing
                              ? 'Save Changes'
                              : 'Create Department',
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
// Location dropdown — filters out archived locations from the picker.
// ---------------------------------------------------------------------------

class _LocationDropdown extends ConsumerWidget {
  final AgencyLocation? selected;
  final ValueChanged<AgencyLocation?> onChanged;

  const _LocationDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final locsAsync = ref.watch(adminLocationsListProvider);
    return locsAsync.when(
      loading: () => const _DropdownLoading(),
      error: (e, _) => _DropdownError(
        message: 'Could not load locations.',
        onRetry: () => ref.invalidate(adminLocationsListProvider),
      ),
      data: (locations) {
        final pickable =
            locations.where((l) => !l.isArchived).toList();
        if (pickable.isEmpty) {
          return const _DropdownEmpty(
            message: 'No active locations. Add one first.',
          );
        }
        return DropdownButtonFormField<int>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select a location',
          ),
          items: pickable
              .map(
                (l) => DropdownMenuItem<int>(
                  value: l.id,
                  child: Text(l.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) {
              onChanged(null);
              return;
            }
            final picked = pickable.firstWhere((l) => l.id == id);
            onChanged(picked);
          },
          validator: (value) =>
              value == null ? 'Location is required.' : null,
        );
      },
    );
  }
}

class _DropdownLoading extends StatelessWidget {
  const _DropdownLoading();

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.brandPrimary,
          ),
        ),
      ),
    );
  }
}

class _DropdownEmpty extends StatelessWidget {
  final String message;
  const _DropdownEmpty({required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.slate500,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

class _DropdownError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _DropdownError({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppTheme.error),
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
