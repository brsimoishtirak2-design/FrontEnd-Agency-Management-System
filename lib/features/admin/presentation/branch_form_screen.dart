import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_client.dart';
import '../../../shared/models/agency_location.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../data/admin_clients_providers.dart';
import '../data/admin_locations_providers.dart';

/// Dual-mode form for creating OR editing a client branch.
///
/// `initialBranch` null → create mode.
/// `initialBranch` non-null → edit mode (with delete action in the AppBar).
class BranchFormScreen extends ConsumerStatefulWidget {
  final int clientId;
  final AgencyClientBranch? initialBranch;

  const BranchFormScreen({
    super.key,
    required this.clientId,
    this.initialBranch,
  });

  @override
  ConsumerState<BranchFormScreen> createState() => _BranchFormScreenState();
}

class _BranchFormScreenState extends ConsumerState<BranchFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _branchNameController = TextEditingController();
  final _addressController = TextEditingController();
  final _contactPersonController = TextEditingController();
  final _contactRoleController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _notesController = TextEditingController();

  AgencyLocation? _selectedLocation;
  bool _isPrimary = false;
  bool _isSubmitting = false;
  bool _isDeleting = false;

  // One-shot guard: locations list arrives async; we only want to
  // pre-fill _selectedLocation from initialBranch.locationId once.
  bool _locationPreFilled = false;

  bool get _isEditing => widget.initialBranch != null;

  @override
  void initState() {
    super.initState();
    _branchNameController.addListener(() => setState(() {}));

    final initial = widget.initialBranch;
    if (initial != null) {
      _branchNameController.text = initial.branchName;
      _addressController.text = initial.address ?? '';
      _contactPersonController.text = initial.contactPerson ?? '';
      _contactRoleController.text = initial.contactRole ?? '';
      _emailController.text = initial.email ?? '';
      _phoneController.text = initial.phone ?? '';
      _whatsappController.text = initial.whatsapp ?? '';
      _notesController.text = initial.notes ?? '';
      _isPrimary = initial.isPrimary;
    }
  }

  @override
  void dispose() {
    _branchNameController.dispose();
    _addressController.dispose();
    _contactPersonController.dispose();
    _contactRoleController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _whatsappController.dispose();
    _notesController.dispose();
    super.dispose();
  }

  bool get _canSubmit {
    if (_isSubmitting || _isDeleting) return false;
    if (_branchNameController.text.trim().isEmpty) return false;
    return true;
  }

  String? _validateEmail(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return null;
    if (text.length > 255) return 'Max 255 characters.';
    final regex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!regex.hasMatch(text)) return 'Enter a valid email address.';
    return null;
  }

  String? _trimOrNull(TextEditingController c) {
    final t = c.text.trim();
    return t.isEmpty ? null : t;
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(adminClientsRepositoryProvider);

      // Cascade un-primary on OTHER branches when this one is being
      // newly promoted to primary (create with primary=true, OR edit
      // where it wasn't primary before but is now).
      final wasPrimary = widget.initialBranch?.isPrimary ?? false;
      if (_isPrimary && !wasPrimary) {
        final existing =
            await repo.listBranches(clientId: widget.clientId);
        for (final b in existing) {
          if (b.isPrimary && b.id != widget.initialBranch?.id) {
            await repo.updateBranch(b.id, {'is_primary': false});
          }
        }
      }

      final draft = AgencyClientBranch(
        id: widget.initialBranch?.id ?? 0,
        clientId: widget.clientId,
        branchName: _branchNameController.text.trim(),
        locationName: null,
        isPrimary: _isPrimary,
        locationId: _selectedLocation?.id,
        address: _trimOrNull(_addressController),
        contactPerson: _trimOrNull(_contactPersonController),
        contactRole: _trimOrNull(_contactRoleController),
        email: _trimOrNull(_emailController),
        phone: _trimOrNull(_phoneController),
        whatsapp: _trimOrNull(_whatsappController),
        notes: _trimOrNull(_notesController),
      );

      final AgencyClientBranch result;
      if (_isEditing) {
        result = await repo.updateBranch(
          widget.initialBranch!.id,
          draft.toJsonForUpdate(),
        );
      } else {
        result = await repo.createBranch(draft);
      }

      ref.invalidate(adminBranchesForClientProvider(widget.clientId));
      ref.invalidate(adminClientWithBranchesProvider(widget.clientId));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Branch "${result.branchName}" '
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
                ? 'Could not update branch: $e'
                : 'Could not create branch: $e',
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
    final initial = widget.initialBranch;
    if (initial == null) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete branch?'),
        content: Text(
          'Deleting "${initial.branchName}" is PERMANENT.\n'
          'All branch info will be removed. Tasks that referenced '
          'this branch will keep working but their branch field will '
          'become empty.',
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
      await ref
          .read(adminClientsRepositoryProvider)
          .deleteBranch(initial.id);
      ref.invalidate(adminBranchesForClientProvider(widget.clientId));
      ref.invalidate(adminClientWithBranchesProvider(widget.clientId));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Branch "${initial.branchName}" deleted.'),
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
          content: Text('Could not delete branch: $e'),
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
    // One-shot async pre-fill of location dropdown once locations arrive.
    ref.listen<AsyncValue<List<AgencyLocation>>>(
      adminLocationsListProvider,
      (prev, next) {
        if (_locationPreFilled) return;
        if (!_isEditing) return;
        final locId = widget.initialBranch?.locationId;
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
        title: Text(_isEditing ? 'Edit Branch' : 'New Branch'),
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
                // ----- Identity -----
                AppSectionLabel('Branch name *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _branchNameController,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: const InputDecoration(
                    hintText: 'e.g. Erbil Main Branch',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Branch name is required.';
                    if (text.length > 100) return 'Max 100 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Location'),
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

                AppSectionLabel('Address'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _addressController,
                  maxLines: 2,
                  textInputAction: TextInputAction.newline,
                  inputFormatters: [LengthLimitingTextInputFormatter(500)],
                  decoration: const InputDecoration(
                    hintText: 'Street, neighborhood, city',
                  ),
                ),
                const SizedBox(height: 24),

                // ----- Contact -----
                AppSectionLabel('Contact person'),
                const SizedBox(height: 6),
                LayoutBuilder(
                  builder: (context, constraints) {
                    final wide = constraints.maxWidth > 500;
                    final fieldWidth = wide
                        ? (constraints.maxWidth - 12) / 2
                        : constraints.maxWidth;
                    return Wrap(
                      spacing: 12,
                      runSpacing: 12,
                      children: [
                        SizedBox(
                          width: fieldWidth,
                          child: TextFormField(
                            controller: _contactPersonController,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(100),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Name',
                            ),
                          ),
                        ),
                        SizedBox(
                          width: fieldWidth,
                          child: TextFormField(
                            controller: _contactRoleController,
                            textInputAction: TextInputAction.next,
                            inputFormatters: [
                              LengthLimitingTextInputFormatter(100),
                            ],
                            decoration: const InputDecoration(
                              hintText: 'Role/title',
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Reach'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(255)],
                  decoration: const InputDecoration(
                    hintText: 'Email',
                    prefixIcon: Icon(Icons.alternate_email, size: 18),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    hintText: 'Phone',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                TextFormField(
                  controller: _whatsappController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    hintText: 'WhatsApp number',
                    prefixIcon: Icon(Icons.message_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 24),

                // ----- Notes -----
                AppSectionLabel('Notes'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _notesController,
                  maxLines: 4,
                  textInputAction: TextInputAction.newline,
                  decoration: const InputDecoration(
                    hintText: 'Optional. Anything to remember.',
                  ),
                ),
                const SizedBox(height: 24),

                // ----- Primary toggle -----
                Card(
                  child: SwitchListTile(
                    title: const Text(
                      'Primary branch',
                      style: TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: const Text(
                      'The default branch for this client',
                    ),
                    value: _isPrimary,
                    onChanged: (v) => setState(() => _isPrimary = v),
                  ),
                ),
                if (_isEditing &&
                    widget.initialBranch!.isPrimary &&
                    !_isPrimary) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'This is currently the primary branch. Toggling '
                      'off will leave the client without a primary.',
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.warning,
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
                          _isEditing ? 'Save Changes' : 'Create Branch',
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
// Location dropdown + small loading/empty/error states
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
        if (locations.isEmpty) {
          return const _DropdownEmpty(
            message: 'No locations defined yet.',
          );
        }
        return DropdownButtonFormField<int>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select a location',
          ),
          items: locations
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
            final picked = locations.firstWhere((l) => l.id == id);
            onChanged(picked);
          },
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
