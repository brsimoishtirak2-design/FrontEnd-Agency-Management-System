import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/agency_user.dart';
import '../../../../shared/models/planner_slot.dart';
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
    final hasSelected = users.any((u) => u.id == selectedId);
    return DropdownButtonFormField<int>(
      initialValue: hasSelected ? selectedId : null,
      decoration: const InputDecoration(
        border: OutlineInputBorder(),
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      ),
      items: users
          .map((u) => DropdownMenuItem(
                value: u.id,
                child: Text(u.name),
              ))
          .toList(),
      onChanged: onChanged == null ? null : (v) {
        if (v != null) onChanged!(v);
      },
    );
  }
}
