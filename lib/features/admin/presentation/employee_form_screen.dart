import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_department.dart';
import '../../../shared/models/agency_job_title.dart';
import '../../../shared/models/agency_location.dart';
import '../../../shared/models/agency_user.dart';
import '../../../shared/widgets/app_dropdown_states.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../../auth/data/auth_providers.dart';
import '../data/admin_departments_providers.dart';
import '../data/admin_job_titles_providers.dart';
import '../data/admin_locations_providers.dart';
import '../data/admin_users_providers.dart';

/// Dual-mode form for creating OR editing an employee.
///
/// `initialUser` null → create mode (password section visible, no
/// Active toggle, defaults role=employee).
/// `initialUser` non-null → edit mode (no password — use the dedicated
/// reset endpoint from the detail screen instead).
///
/// Self-protection guards: if the admin is editing their own row,
/// the Role segmented button is disabled and the Active toggle is
/// hidden — both backend-enforced (403 with self_role_change_blocked
/// or self_deactivate_blocked).
class EmployeeFormScreen extends ConsumerStatefulWidget {
  final AgencyUser? initialUser;

  const EmployeeFormScreen({super.key, this.initialUser});

  @override
  ConsumerState<EmployeeFormScreen> createState() =>
      _EmployeeFormScreenState();
}

class _EmployeeFormScreenState extends ConsumerState<EmployeeFormScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();

  String _role = 'employee';
  AgencyLocation? _selectedLocation;
  AgencyDepartment? _selectedDepartment;
  AgencyJobTitle? _selectedJobTitle;
  bool _isActive = true;
  bool _passwordVisible = false;
  bool _isSubmitting = false;

  // One-shot guards for async pre-fill of dropdowns when editing.
  bool _locationPreFilled = false;
  bool _departmentPreFilled = false;
  bool _jobTitlePreFilled = false;

  bool get _isEditing => widget.initialUser != null;

  @override
  void initState() {
    super.initState();
    void rebuildOnChange() => setState(() {});
    _nameController.addListener(rebuildOnChange);
    _emailController.addListener(rebuildOnChange);
    _passwordController.addListener(rebuildOnChange);

    final initial = widget.initialUser;
    if (initial != null) {
      _nameController.text = initial.name;
      _emailController.text = initial.email;
      _phoneController.text = initial.phone ?? '';
      _role = initial.role;
      _isActive = initial.isActive;

      // Seed FK dropdowns from currently-cached provider data after the
      // first frame. The ref.listen calls in build() handle the case
      // where the providers load AFTER the form opens; this handles the
      // common case where another screen (e.g. Employees list) already
      // populated them, so listen wouldn't fire on attach.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _seedDropdownsFromCachedProviders();
      });
    }
  }

  void _seedDropdownsFromCachedProviders() {
    final initial = widget.initialUser;
    if (initial == null) return;

    if (!_locationPreFilled && initial.locationId != null) {
      ref.read(adminLocationsListProvider).whenData((locations) {
        final match = locations
            .where((l) => l.id == initial.locationId)
            .firstOrNull;
        if (match != null && _selectedLocation == null && mounted) {
          setState(() {
            _selectedLocation = match;
            _locationPreFilled = true;
          });
        }
      });
    }
    if (!_departmentPreFilled && initial.departmentId != null) {
      ref.read(adminDepartmentsListProvider).whenData((depts) {
        final match =
            depts.where((d) => d.id == initial.departmentId).firstOrNull;
        if (match != null && _selectedDepartment == null && mounted) {
          setState(() {
            _selectedDepartment = match;
            _departmentPreFilled = true;
          });
        }
      });
    }
    if (!_jobTitlePreFilled && initial.jobTitleId != null) {
      ref.read(adminJobTitlesListProvider).whenData((jobs) {
        final match =
            jobs.where((j) => j.id == initial.jobTitleId).firstOrNull;
        if (match != null && _selectedJobTitle == null && mounted) {
          setState(() {
            _selectedJobTitle = match;
            _jobTitlePreFilled = true;
          });
        }
      });
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _isSelf(WidgetRef ref) {
    final initial = widget.initialUser;
    if (initial == null) return false;
    final auth = ref.read(authStateProvider);
    if (auth is! AuthAuthenticated) return false;
    return auth.user.id == initial.id;
  }

  bool get _canSubmit {
    if (_isSubmitting) return false;
    if (_nameController.text.trim().isEmpty) return false;
    if (_emailController.text.trim().isEmpty) return false;
    // FK fields and password are only required in create mode.
    // In edit mode the server already has values for these; the patch
    // only sends fields the admin actually changed.
    if (!_isEditing) {
      if (_selectedLocation == null) return false;
      if (_selectedDepartment == null) return false;
      if (_selectedJobTitle == null) return false;
      if (_passwordController.text.length < 8) return false;
    }
    return true;
  }

  String? _validateEmail(String? v) {
    final text = v?.trim() ?? '';
    if (text.isEmpty) return 'Email is required.';
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
    if (!_isEditing) {
      // Create mode: defense in depth — should already be gated by _canSubmit.
      if (_selectedLocation == null ||
          _selectedDepartment == null ||
          _selectedJobTitle == null) {
        return;
      }
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSubmitting = true);

    try {
      final repo = ref.read(adminUsersRepositoryProvider);
      final name = _nameController.text.trim();
      final email = _emailController.text.trim();
      final phone = _trimOrNull(_phoneController);

      if (_isEditing) {
        final initial = widget.initialUser!;
        final isSelf = _isSelf(ref);

        final map = <String, dynamic>{
          'name': name,
          'email': email,
        };
        if (phone != null) map['phone'] = phone;
        // Only include FK fields when the admin actually picked one.
        // Leaving them out preserves the server-side value, which matters
        // when the form opens with an FK that no longer has pickable
        // options (e.g. archived department, location with no departments).
        if (_selectedLocation != null) {
          map['location_id'] = _selectedLocation!.id;
        }
        if (_selectedDepartment != null) {
          map['department_id'] = _selectedDepartment!.id;
        }
        if (_selectedJobTitle != null) {
          map['job_title_id'] = _selectedJobTitle!.id;
        }
        if (!isSelf) {
          map['role'] = _role;
          map['is_active'] = _isActive;
        }

        final updated = await repo.updateUser(initial.id, map);
        ref.invalidate(adminAllUsersProvider);
        ref.invalidate(adminUserDetailProvider(initial.id));

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee "${updated.name}" updated.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      } else {
        final draft = AgencyUser(
          id: 0,
          name: name,
          email: email,
          phone: phone,
          role: _role,
          isActive: true,
          profilePhoto: null,
          locationName: null,
          departmentName: null,
          jobTitleName: null,
          locationId: _selectedLocation!.id,
          departmentId: _selectedDepartment!.id,
          jobTitleId: _selectedJobTitle!.id,
        );

        final created =
            await repo.createUser(draft, _passwordController.text);
        ref.invalidate(adminAllUsersProvider);

        if (!mounted) return;

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Employee "${created.name}" created.'),
            backgroundColor: AppTheme.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
        context.pop();
      }
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
                ? 'Could not update employee: $e'
                : 'Could not create employee: $e',
          ),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // One-shot async pre-fill of dropdowns from initialUser FK ids.
    // The ref.listen calls below handle the "data arrives later" case;
    // the matching post-frame seed in initState handles the "data is
    // already cached" case (Riverpod 2.x ref.listen doesn't support
    // fireImmediately).
    ref.listen<AsyncValue<List<AgencyLocation>>>(
      adminLocationsListProvider,
      (prev, next) {
        if (_locationPreFilled || !_isEditing) return;
        final locId = widget.initialUser?.locationId;
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
    ref.listen<AsyncValue<List<AgencyDepartment>>>(
      adminDepartmentsListProvider,
      (prev, next) {
        if (_departmentPreFilled || !_isEditing) return;
        final deptId = widget.initialUser?.departmentId;
        if (deptId == null) {
          _departmentPreFilled = true;
          return;
        }
        next.whenData((depts) {
          final match = depts.where((d) => d.id == deptId).firstOrNull;
          if (match != null && _selectedDepartment == null) {
            setState(() {
              _selectedDepartment = match;
              _departmentPreFilled = true;
            });
          } else {
            _departmentPreFilled = true;
          }
        });
      },
    );
    ref.listen<AsyncValue<List<AgencyJobTitle>>>(
      adminJobTitlesListProvider,
      (prev, next) {
        if (_jobTitlePreFilled || !_isEditing) return;
        final jobId = widget.initialUser?.jobTitleId;
        if (jobId == null) {
          _jobTitlePreFilled = true;
          return;
        }
        next.whenData((jobs) {
          final match = jobs.where((j) => j.id == jobId).firstOrNull;
          if (match != null && _selectedJobTitle == null) {
            setState(() {
              _selectedJobTitle = match;
              _jobTitlePreFilled = true;
            });
          } else {
            _jobTitlePreFilled = true;
          }
        });
      },
    );

    final isSelf = _isSelf(ref);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Employee' : 'New Employee'),
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
                AppSectionLabel('Name *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _nameController,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(100)],
                  decoration: const InputDecoration(
                    hintText: 'Full name',
                  ),
                  validator: (v) {
                    final text = v?.trim() ?? '';
                    if (text.isEmpty) return 'Name is required.';
                    if (text.length > 100) return 'Max 100 characters.';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Email *'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(255)],
                  decoration: const InputDecoration(
                    hintText: 'name@example.com',
                    prefixIcon: Icon(Icons.alternate_email, size: 18),
                  ),
                  validator: _validateEmail,
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Phone'),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _phoneController,
                  keyboardType: TextInputType.phone,
                  textInputAction: TextInputAction.next,
                  inputFormatters: [LengthLimitingTextInputFormatter(30)],
                  decoration: const InputDecoration(
                    hintText: 'Optional',
                    prefixIcon: Icon(Icons.phone_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 24),

                // ----- Login (CREATE only) -----
                if (!_isEditing) ...[
                  AppSectionLabel('Password *'),
                  const SizedBox(height: 6),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: !_passwordVisible,
                    textInputAction: TextInputAction.next,
                    decoration: InputDecoration(
                      hintText: 'At least 8 characters',
                      helperText:
                          'User will be required to change this on first login.',
                      prefixIcon: const Icon(Icons.lock_outline, size: 18),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _passwordVisible
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 18,
                        ),
                        onPressed: () => setState(
                          () => _passwordVisible = !_passwordVisible,
                        ),
                      ),
                    ),
                    validator: (v) {
                      final text = v ?? '';
                      if (text.isEmpty) return 'Password is required.';
                      if (text.length < 8) {
                        return 'Must be at least 8 characters.';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 24),
                ],

                // ----- Role -----
                AppSectionLabel('Role *'),
                const SizedBox(height: 8),
                SegmentedButton<String>(
                  segments: const [
                    ButtonSegment(
                      value: 'employee',
                      label: Text('Employee'),
                    ),
                    ButtonSegment(
                      value: 'admin',
                      label: Text('Admin'),
                    ),
                  ],
                  selected: {_role},
                  onSelectionChanged: (_isEditing && isSelf)
                      ? null
                      : (set) {
                          if (set.isNotEmpty) {
                            setState(() => _role = set.first);
                          }
                        },
                  showSelectedIcon: false,
                ),
                if (_isEditing && isSelf) ...[
                  const SizedBox(height: 6),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Text(
                      'You cannot change your own role.',
                      style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppTheme.slate500,
                          ),
                    ),
                  ),
                ],
                const SizedBox(height: 24),

                // ----- Assignment -----
                AppSectionLabel('Location *'),
                const SizedBox(height: 6),
                _LocationDropdown(
                  selected: _selectedLocation,
                  onChanged: (loc) {
                    if (loc?.id == _selectedLocation?.id) return;
                    setState(() {
                      _selectedLocation = loc;
                      _selectedDepartment = null;
                      _locationPreFilled = true;
                    });
                  },
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Department *'),
                const SizedBox(height: 6),
                _DepartmentDropdown(
                  selectedLocation: _selectedLocation,
                  selected: _selectedDepartment,
                  onChanged: (dept) {
                    setState(() {
                      _selectedDepartment = dept;
                      _departmentPreFilled = true;
                    });
                  },
                ),
                const SizedBox(height: 16),

                AppSectionLabel('Job Title *'),
                const SizedBox(height: 6),
                _JobTitleDropdown(
                  selected: _selectedJobTitle,
                  onChanged: (job) {
                    setState(() {
                      _selectedJobTitle = job;
                      _jobTitlePreFilled = true;
                    });
                  },
                ),
                const SizedBox(height: 24),

                // ----- Active toggle (EDIT only, hidden for self) -----
                if (_isEditing && !isSelf) ...[
                  Card(
                    child: SwitchListTile(
                      title: const Text(
                        'Active',
                        style: TextStyle(fontWeight: FontWeight.w600),
                      ),
                      subtitle: const Text(
                        'Inactive users cannot log in.',
                      ),
                      value: _isActive,
                      onChanged: (v) => setState(() => _isActive = v),
                    ),
                  ),
                  if (!_isActive) ...[
                    const SizedBox(height: 6),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: Text(
                        'User cannot log in while inactive.',
                        style:
                            Theme.of(context).textTheme.labelSmall?.copyWith(
                                  color: AppTheme.warning,
                                ),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                ],

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
                              : 'Create Employee',
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
// Dropdowns
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
      loading: () => const AppDropdownLoading(),
      error: (e, _) => AppDropdownError(
        message: 'Could not load locations.',
        onRetry: () => ref.invalidate(adminLocationsListProvider),
      ),
      data: (locations) {
        final pickable =
            locations.where((l) => !l.isArchived).toList();
        if (pickable.isEmpty) {
          return const AppDropdownEmpty(
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

class _DepartmentDropdown extends ConsumerWidget {
  final AgencyLocation? selectedLocation;
  final AgencyDepartment? selected;
  final ValueChanged<AgencyDepartment?> onChanged;

  const _DepartmentDropdown({
    required this.selectedLocation,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (selectedLocation == null) {
      return const AppDropdownEmpty(
        message: 'Pick a location first.',
      );
    }

    final deptsAsync = ref.watch(adminDepartmentsListProvider);
    return deptsAsync.when(
      loading: () => const AppDropdownLoading(),
      error: (e, _) => AppDropdownError(
        message: 'Could not load departments.',
        onRetry: () => ref.invalidate(adminDepartmentsListProvider),
      ),
      data: (depts) {
        final pickable = depts
            .where(
              (d) =>
                  !d.isArchived &&
                  d.locationId == selectedLocation!.id,
            )
            .toList();
        if (pickable.isEmpty) {
          return AppDropdownEmpty(
            message:
                'No departments in ${selectedLocation!.name}. Add one '
                'in Settings → Departments.',
          );
        }
        return DropdownButtonFormField<int>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select a department',
          ),
          items: pickable
              .map(
                (d) => DropdownMenuItem<int>(
                  value: d.id,
                  child: Text(d.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) {
              onChanged(null);
              return;
            }
            final picked = pickable.firstWhere((d) => d.id == id);
            onChanged(picked);
          },
          validator: (value) =>
              value == null ? 'Department is required.' : null,
        );
      },
    );
  }
}

class _JobTitleDropdown extends ConsumerWidget {
  final AgencyJobTitle? selected;
  final ValueChanged<AgencyJobTitle?> onChanged;

  const _JobTitleDropdown({
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final jobsAsync = ref.watch(adminJobTitlesListProvider);
    return jobsAsync.when(
      loading: () => const AppDropdownLoading(),
      error: (e, _) => AppDropdownError(
        message: 'Could not load job titles.',
        onRetry: () => ref.invalidate(adminJobTitlesListProvider),
      ),
      data: (jobs) {
        final pickable = jobs.where((j) => !j.isArchived).toList();
        if (pickable.isEmpty) {
          return const AppDropdownEmpty(
            message: 'No active job titles. Add one first.',
          );
        }
        return DropdownButtonFormField<int>(
          initialValue: selected?.id,
          isExpanded: true,
          decoration: const InputDecoration(
            hintText: 'Select a job title',
          ),
          items: pickable
              .map(
                (j) => DropdownMenuItem<int>(
                  value: j.id,
                  child: Text(j.name, overflow: TextOverflow.ellipsis),
                ),
              )
              .toList(),
          onChanged: (id) {
            if (id == null) {
              onChanged(null);
              return;
            }
            final picked = pickable.firstWhere((j) => j.id == id);
            onChanged(picked);
          },
          validator: (value) =>
              value == null ? 'Job title is required.' : null,
        );
      },
    );
  }
}

