import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/agency_user.dart';
import '../../../../shared/models/planner_slot.dart';
import '../../../../shared/widgets/user_avatar.dart';
import '../../../admin/data/admin_users_providers.dart';
import '../../data/planner_providers.dart';

/// Bottom sheet shown when an admin taps a slot. Lets them reassign,
/// change the date, toggle lock, or delete the slot.
class SlotEditSheet extends ConsumerStatefulWidget {
  final PlannerSlot slot;
  final int planId;

  const SlotEditSheet({
    super.key,
    required this.slot,
    required this.planId,
  });

  @override
  ConsumerState<SlotEditSheet> createState() => _SlotEditSheetState();
}

class _SlotEditSheetState extends ConsumerState<SlotEditSheet> {
  late int _assignedUserId;
  late DateTime _slotDate;
  late bool _isLocked;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _assignedUserId = widget.slot.assignedUserId;
    _slotDate = widget.slot.slotDate;
    _isLocked = widget.slot.isLocked;
  }

  @override
  Widget build(BuildContext context) {
    final employees = ref.watch(adminActiveEmployeesProvider);

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(slot: widget.slot),
              const SizedBox(height: 20),

              // Date
              _SectionLabel('Date'),
              const SizedBox(height: 8),
              InkWell(
                onTap: _saving ? null : _pickDate,
                borderRadius: BorderRadius.circular(8),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                  decoration: BoxDecoration(
                    border: Border.all(color: AppTheme.slate300),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.calendar_today, size: 18, color: AppTheme.slate500),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          DateFormat('EEE, MMM d').format(_slotDate),
                          style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: AppTheme.slate500),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Assignee
              _SectionLabel('Assigned to'),
              const SizedBox(height: 8),
              employees.when(
                data: (list) => _AssigneeDropdown(
                  users: list,
                  selectedId: _assignedUserId,
                  onChanged: _saving
                      ? null
                      : (id) => setState(() => _assignedUserId = id),
                ),
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load employees: $e',
                    style: const TextStyle(color: AppTheme.error)),
              ),
              const SizedBox(height: 16),

              // Lock
              SwitchListTile.adaptive(
                contentPadding: EdgeInsets.zero,
                value: _isLocked,
                onChanged: _saving ? null : (v) => setState(() => _isLocked = v),
                title: const Text(
                  'Lock this slot',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                subtitle: const Text(
                  'Locked slots are kept in place when "Re-balance unlocked" runs.',
                  style: TextStyle(fontSize: 12),
                ),
              ),
              const SizedBox(height: 8),

              // Buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _saving ? null : _delete,
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('Delete'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppTheme.error,
                        side: const BorderSide(color: AppTheme.error),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: _saving ? null : _save,
                      icon: _saving
                          ? const SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.check),
                      label: Text(_saving ? 'Saving…' : 'Save changes'),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickDate() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _slotDate,
      firstDate: DateTime(_slotDate.year, _slotDate.month, 1),
      lastDate: DateTime(_slotDate.year, _slotDate.month + 1, 0),
      selectableDayPredicate: (d) => d.weekday != DateTime.friday,
    );
    if (selected != null) {
      setState(() => _slotDate = selected);
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      final repo = ref.read(plannerRepositoryProvider);
      await repo.updateSlot(
        planId: widget.planId,
        slotId: widget.slot.id,
        slotDate: DateFormat('yyyy-MM-dd').format(_slotDate),
        assignedUserId: _assignedUserId,
        isLocked: _isLocked,
      );
      ref.invalidate(plannerPlanProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() => _saving = false);
    }
  }

  Future<void> _delete() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Delete slot?'),
        content: Text(
          widget.slot.isMaterialized
              ? 'This slot has a task already. Deleting will cancel the task with reason "Removed from plan".'
              : 'This slot will be removed from the plan.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _saving = true);
    try {
      final repo = ref.read(plannerRepositoryProvider);
      await repo.deleteSlot(planId: widget.planId, slotId: widget.slot.id);
      ref.invalidate(plannerPlanProvider);
      if (mounted) Navigator.of(context).pop(true);
    } on ApiException catch (e) {
      _showError(e.message);
      setState(() => _saving = false);
    }
  }

  void _showError(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _Header extends StatelessWidget {
  final PlannerSlot slot;
  const _Header({required this.slot});

  @override
  Widget build(BuildContext context) {
    final typeColor = slot.isPost ? AppTheme.info : AppTheme.warning;
    return Row(
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: typeColor,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            slot.isPost ? 'P' : 'V',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                slot.clientName ?? 'Client',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              Text(
                '${slot.isPost ? 'Post' : 'Video'}'
                '${slot.isMaterialized ? ' · Task active' : ' · Not yet a task'}',
                style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionLabel extends StatelessWidget {
  final String label;
  const _SectionLabel(this.label);

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: const TextStyle(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppTheme.slate500,
        letterSpacing: 0.5,
      ),
    );
  }
}

class _AssigneeDropdown extends StatelessWidget {
  final List<AgencyUser> users;
  final int selectedId;
  final ValueChanged<int>? onChanged;

  const _AssigneeDropdown({
    required this.users,
    required this.selectedId,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final selected = users.firstWhere(
      (u) => u.id == selectedId,
      orElse: () => users.isNotEmpty
          ? users.first
          : const AgencyUser(
              id: 0,
              name: '?',
              email: '',
              phone: null,
              role: 'employee',
              isActive: true,
              profilePhoto: null,
              locationName: null,
              departmentName: null,
              jobTitleName: null,
            ),
    );

    return InkWell(
      onTap: onChanged == null ? null : () => _openPicker(context),
      borderRadius: BorderRadius.circular(8),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          border: Border.all(color: AppTheme.slate300),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          children: [
            UserAvatar(
              name: selected.name,
              photoUrl: selected.profilePhoto,
              radius: 14,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                selected.name,
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Icon(Icons.arrow_drop_down, color: AppTheme.slate500),
          ],
        ),
      ),
    );
  }

  Future<void> _openPicker(BuildContext context) async {
    final picked = await showModalBottomSheet<int>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _AssigneePickerSheet(
        users: users,
        selectedId: selectedId,
      ),
    );
    if (picked != null && picked != selectedId) {
      onChanged?.call(picked);
    }
  }
}

class _AssigneePickerSheet extends StatelessWidget {
  final List<AgencyUser> users;
  final int selectedId;

  const _AssigneePickerSheet({
    required this.users,
    required this.selectedId,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.7,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 12),
            Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 20),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Assign to',
                  style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                itemCount: users.length,
                separatorBuilder: (_, _) => const Divider(
                  height: 1,
                  color: AppTheme.slate100,
                ),
                itemBuilder: (_, i) {
                  final u = users[i];
                  final isSelected = u.id == selectedId;
                  return ListTile(
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 4,
                    ),
                    leading: UserAvatar(
                      name: u.name,
                      photoUrl: u.profilePhoto,
                      radius: 18,
                    ),
                    title: Text(
                      u.name,
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                    subtitle: u.subtitle.isEmpty ? null : Text(u.subtitle),
                    trailing: isSelected
                        ? const Icon(
                            Icons.check_circle,
                            color: AppTheme.brandPrimary,
                          )
                        : null,
                    onTap: () => Navigator.of(context).pop(u.id),
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
