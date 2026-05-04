import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/agency_user.dart';
import '../../data/admin_users_providers.dart';

/// Bottom-sheet picker for selecting assignees.
///
/// Pops with the new list of selected user IDs (or null if user cancelled).
/// Caller is responsible for tracking which is leader — this sheet just
/// returns who's selected.
class AssigneePickerSheet extends ConsumerStatefulWidget {
  /// User IDs already selected. Used to pre-check rows.
  final Set<int> initiallySelected;

  const AssigneePickerSheet({
    super.key,
    required this.initiallySelected,
  });

  /// Show as modal bottom sheet. Returns the new set of selected user IDs,
  /// or null if cancelled.
  static Future<Set<int>?> show(
    BuildContext context, {
    required Set<int> initiallySelected,
  }) {
    return showModalBottomSheet<Set<int>>(
      context: context,
      isScrollControlled: true,
      // Material 3's surface tint over the brand-primary purple gives the
      // sheet a pinkish cast by default. Force a clean white surface.
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Material(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: AssigneePickerSheet(
          initiallySelected: initiallySelected,
        ),
      ),
    );
  }

  @override
  ConsumerState<AssigneePickerSheet> createState() =>
      _AssigneePickerSheetState();
}

class _AssigneePickerSheetState extends ConsumerState<AssigneePickerSheet> {
  late Set<int> _selected;
  String _searchQuery = '';
  String? _filterLocation;
  String? _filterDepartment;
  String? _filterJobTitle;

  @override
  void initState() {
    super.initState();
    _selected = {...widget.initiallySelected};
  }

  void _toggle(int userId) {
    setState(() {
      if (_selected.contains(userId)) {
        _selected.remove(userId);
      } else {
        _selected.add(userId);
      }
    });
  }

  bool get _anyFilterActive =>
      _filterLocation != null ||
      _filterDepartment != null ||
      _filterJobTitle != null;

  void _clearAllFilters() {
    setState(() {
      _filterLocation = null;
      _filterDepartment = null;
      _filterJobTitle = null;
    });
  }

  List<AgencyUser> _filterUsers(List<AgencyUser> all) {
    final q = _searchQuery.trim().toLowerCase();
    return all.where((u) {
      if (q.isNotEmpty) {
        final hit = u.name.toLowerCase().contains(q) ||
            u.email.toLowerCase().contains(q) ||
            (u.jobTitleName?.toLowerCase().contains(q) ?? false) ||
            (u.locationName?.toLowerCase().contains(q) ?? false) ||
            (u.departmentName?.toLowerCase().contains(q) ?? false);
        if (!hit) return false;
      }
      if (_filterLocation != null && u.locationName != _filterLocation) {
        return false;
      }
      if (_filterDepartment != null &&
          u.departmentName != _filterDepartment) {
        return false;
      }
      if (_filterJobTitle != null && u.jobTitleName != _filterJobTitle) {
        return false;
      }
      return true;
    }).toList();
  }

  /// Distinct, non-null values for one user attribute, sorted alphabetically.
  List<String> _distinctValues(
    List<AgencyUser> users,
    String? Function(AgencyUser) selector,
  ) {
    final set = <String>{};
    for (final u in users) {
      final v = selector(u);
      if (v != null && v.isNotEmpty) set.add(v);
    }
    final list = set.toList()..sort();
    return list;
  }

  Future<void> _pickFilter({
    required String label,
    required List<String> options,
    required String? current,
    required ValueChanged<String?> onPicked,
  }) async {
    if (options.isEmpty) return;
    final picked = await showModalBottomSheet<_FilterPick>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => Material(
        color: Colors.white,
        surfaceTintColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        clipBehavior: Clip.antiAlias,
        child: _FilterOptionsSheet(
          label: label,
          options: options,
          current: current,
        ),
      ),
    );
    if (picked == null) return;
    onPicked(picked.value);
  }

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminActiveEmployeesProvider);
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    final maxSheetHeight = MediaQuery.of(context).size.height * 0.85;

    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxSheetHeight),
      child: Padding(
        padding: EdgeInsets.only(bottom: viewInsets),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),

            // Header row
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Add assignees',
                      style:
                          Theme.of(context).textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(_selected),
                    child: Text('Done (${_selected.length})'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            // Search field
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                onChanged: (v) => setState(() => _searchQuery = v),
                decoration: const InputDecoration(
                  prefixIcon: Icon(Icons.search, size: 18),
                  hintText: 'Search by name, role, location, or email',
                  isDense: true,
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Filter chips row — Location / Department / Job title.
            // Counts and option sets come from the loaded users; options
            // hidden when there's only one (or zero) distinct value to
            // avoid showing a useless filter.
            usersAsync.maybeWhen(
              data: (users) {
                final locationOptions = _distinctValues(
                  users,
                  (u) => u.locationName,
                );
                final departmentOptions = _distinctValues(
                  users,
                  (u) => u.departmentName,
                );
                final jobTitleOptions = _distinctValues(
                  users,
                  (u) => u.jobTitleName,
                );
                final anyFilterPossible = locationOptions.length > 1 ||
                    departmentOptions.length > 1 ||
                    jobTitleOptions.length > 1;
                if (!anyFilterPossible) return const SizedBox.shrink();

                return SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: [
                      if (locationOptions.length > 1)
                        _FilterChip(
                          label: 'Location',
                          value: _filterLocation,
                          icon: Icons.place_outlined,
                          onTap: () => _pickFilter(
                            label: 'Filter by location',
                            options: locationOptions,
                            current: _filterLocation,
                            onPicked: (v) =>
                                setState(() => _filterLocation = v),
                          ),
                          onClear: _filterLocation == null
                              ? null
                              : () => setState(() => _filterLocation = null),
                        ),
                      if (locationOptions.length > 1 &&
                          departmentOptions.length > 1)
                        const SizedBox(width: 8),
                      if (departmentOptions.length > 1)
                        _FilterChip(
                          label: 'Department',
                          value: _filterDepartment,
                          icon: Icons.account_tree_outlined,
                          onTap: () => _pickFilter(
                            label: 'Filter by department',
                            options: departmentOptions,
                            current: _filterDepartment,
                            onPicked: (v) =>
                                setState(() => _filterDepartment = v),
                          ),
                          onClear: _filterDepartment == null
                              ? null
                              : () =>
                                  setState(() => _filterDepartment = null),
                        ),
                      if (departmentOptions.length > 1 &&
                          jobTitleOptions.length > 1)
                        const SizedBox(width: 8),
                      if (jobTitleOptions.length > 1)
                        _FilterChip(
                          label: 'Job title',
                          value: _filterJobTitle,
                          icon: Icons.badge_outlined,
                          onTap: () => _pickFilter(
                            label: 'Filter by job title',
                            options: jobTitleOptions,
                            current: _filterJobTitle,
                            onPicked: (v) =>
                                setState(() => _filterJobTitle = v),
                          ),
                          onClear: _filterJobTitle == null
                              ? null
                              : () => setState(() => _filterJobTitle = null),
                        ),
                      if (_anyFilterActive) ...[
                        const SizedBox(width: 8),
                        TextButton.icon(
                          onPressed: _clearAllFilters,
                          icon: const Icon(Icons.close, size: 14),
                          label: const Text('Clear'),
                          style: TextButton.styleFrom(
                            foregroundColor: AppTheme.slate500,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              },
              orElse: () => const SizedBox.shrink(),
            ),
            const SizedBox(height: 8),
            const Divider(height: 1),

            // List
            Flexible(
              child: usersAsync.when(
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 32),
                  child: Center(
                    child: SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.brandPrimary,
                      ),
                    ),
                  ),
                ),
                error: (error, _) => Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      Icon(Icons.error_outline,
                          color: AppTheme.error, size: 32),
                      const SizedBox(height: 8),
                      Text(
                        'Could not load employees.',
                        style: TextStyle(color: AppTheme.error),
                      ),
                      const SizedBox(height: 8),
                      TextButton(
                        onPressed: () => ref
                            .invalidate(adminActiveEmployeesProvider),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
                data: (users) {
                  final filtered = _filterUsers(users);
                  if (filtered.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(32),
                      child: Center(
                        child: Text(
                          users.isEmpty
                              ? 'No active employees found.'
                              : 'No employees match your search or filters.',
                          style: TextStyle(
                            color: AppTheme.slate500,
                            fontStyle: FontStyle.italic,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ),
                    );
                  }
                  return ListView.builder(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final user = filtered[index];
                      final isSelected = _selected.contains(user.id);
                      return _UserRow(
                        user: user,
                        isSelected: isSelected,
                        onTap: () => _toggle(user.id),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _UserRow extends StatelessWidget {
  final AgencyUser user;
  final bool isSelected;
  final VoidCallback onTap;

  const _UserRow({
    required this.user,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.slate100,
              child: Text(
                user.initials,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppTheme.slate700,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                  ),
                  if (user.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 2),
                    Text(
                      user.subtitle,
                      style:
                          Theme.of(context).textTheme.labelSmall?.copyWith(
                                color: AppTheme.slate500,
                              ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              isSelected
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked,
              color: isSelected
                  ? AppTheme.brandPrimary
                  : AppTheme.slate300,
              size: 22,
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Filter chip — used for Location / Department / Job title
// ---------------------------------------------------------------------------

class _FilterChip extends StatelessWidget {
  final String label;
  final String? value;
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  const _FilterChip({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
    this.onClear,
  });

  @override
  Widget build(BuildContext context) {
    final active = value != null;
    return Material(
      color: active
          ? AppTheme.brandPrimary.withValues(alpha: 0.10)
          : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(
          color: active ? AppTheme.brandPrimary : AppTheme.slate200,
        ),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 6, 10, 6),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 14,
                color: active
                    ? AppTheme.brandPrimaryDark
                    : AppTheme.slate500,
              ),
              const SizedBox(width: 6),
              Text(
                value ?? label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: active
                          ? AppTheme.brandPrimaryDark
                          : AppTheme.slate700,
                    ),
              ),
              const SizedBox(width: 4),
              if (active && onClear != null)
                InkWell(
                  onTap: onClear,
                  borderRadius: BorderRadius.circular(12),
                  child: Padding(
                    padding: const EdgeInsets.all(2),
                    child: Icon(
                      Icons.close,
                      size: 14,
                      color: AppTheme.brandPrimaryDark,
                    ),
                  ),
                )
              else
                Icon(
                  Icons.expand_more,
                  size: 16,
                  color: active
                      ? AppTheme.brandPrimaryDark
                      : AppTheme.slate500,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FilterPick {
  final String? value;
  const _FilterPick(this.value);
}

class _FilterOptionsSheet extends StatelessWidget {
  final String label;
  final List<String> options;
  final String? current;

  const _FilterOptionsSheet({
    required this.label,
    required this.options,
    required this.current,
  });

  @override
  Widget build(BuildContext context) {
    final maxHeight = MediaQuery.of(context).size.height * 0.6;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: maxHeight),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 8),
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppTheme.slate300,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    label,
                    style:
                        Theme.of(context).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                  ),
                ),
                if (current != null)
                  TextButton(
                    onPressed: () =>
                        Navigator.of(context).pop(const _FilterPick(null)),
                    child: const Text('Clear'),
                  ),
              ],
            ),
          ),
          const Divider(height: 12),
          Flexible(
            child: ListView.builder(
              padding: const EdgeInsets.only(bottom: 16),
              itemCount: options.length,
              itemBuilder: (context, i) {
                final opt = options[i];
                final selected = opt == current;
                return InkWell(
                  onTap: () =>
                      Navigator.of(context).pop(_FilterPick(opt)),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            opt,
                            style: Theme.of(context).textTheme.bodyMedium
                                ?.copyWith(
                                  fontWeight: selected
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: selected
                                      ? AppTheme.brandPrimaryDark
                                      : AppTheme.slate900,
                                ),
                          ),
                        ),
                        if (selected)
                          Icon(
                            Icons.check_rounded,
                            size: 20,
                            color: AppTheme.brandPrimary,
                          ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
