import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_location.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../data/admin_locations_providers.dart';

/// Dual-mode form for creating OR editing a location.
class LocationFormScreen extends ConsumerStatefulWidget {
  final AgencyLocation? initialLocation;

  const LocationFormScreen({super.key, this.initialLocation});

  @override
  ConsumerState<LocationFormScreen> createState() =>
      _LocationFormScreenState();
}

class _LocationFormScreenState extends ConsumerState<LocationFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  bool _isActive = true;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  bool get _isEditing => widget.initialLocation != null;

  @override
  void initState() {
    super.initState();
    _nameController.addListener(() => setState(() {}));

    final initial = widget.initialLocation;
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
    return true;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(adminLocationsRepositoryProvider);
      final name = _nameController.text.trim();

      final AgencyLocation result;
      if (_isEditing) {
        result = await repo.updateLocation(
          widget.initialLocation!.id,
          {'name': name, 'is_active': _isActive},
        );
        ref.invalidate(
          adminLocationDetailProvider(widget.initialLocation!.id),
        );
      } else {
        final draft = AgencyLocation(
          id: 0, // toJsonForCreate ignores id
          name: name,
          isActive: _isActive,
        );
        result = await repo.createLocation(draft);
      }

      ref.invalidate(adminLocationsListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location "${result.name}" '
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
                ? 'Could not update location: $e'
                : 'Could not create location: $e',
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
    final initial = widget.initialLocation;
    if (initial == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete location?'),
        content: Text(
          'Permanently delete "${initial.name}"?\n'
          'If users or departments are linked, deletion is blocked — '
          'use "Archive" instead to deactivate without losing data.',
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
      final repo = ref.read(adminLocationsRepositoryProvider);
      await repo.deleteLocation(initial.id);

      ref.invalidate(adminLocationsListProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Location "${initial.name}" deleted.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
      context.pop();
    } on ApiException catch (e) {
      if (!mounted) return;

      // 409 = blocked because dependent rows exist; offer archive instead.
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
                .read(adminLocationsRepositoryProvider)
                .archiveLocation(initial.id);
            ref.invalidate(adminLocationsListProvider);
            ref.invalidate(adminLocationDetailProvider(initial.id));

            if (!mounted) return;

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Location "${initial.name}" archived.'),
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
          content: Text('Could not delete location: $e'),
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
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Location' : 'New Location'),
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
                AppSectionLabel('Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.done,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: const InputDecoration(
                    hintText: 'e.g. Erbil',
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
                      'Inactive locations are hidden from new task '
                      'and employee assignment.',
                    ),
                    value: _isActive,
                    onChanged: (v) => setState(() => _isActive = v),
                  ),
                ),
                if (_isEditing &&
                    widget.initialLocation!.isArchived) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'Archived locations are hidden from new task/'
                      'employee assignment.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slate500,
                          ),
                    ),
                  ),
                ],
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
                              : 'Create Location',
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

