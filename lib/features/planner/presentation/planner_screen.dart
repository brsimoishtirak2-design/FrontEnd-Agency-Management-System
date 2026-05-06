import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/monthly_plan.dart';
import '../../../shared/models/user.dart';
import '../../admin/data/admin_tasks_providers.dart';
import '../../auth/data/auth_providers.dart';
import '../../tasks/data/tasks_providers.dart';
import '../data/planner_providers.dart';
import '../data/planner_repository.dart';
import 'pdf_export.dart';
import 'widgets/client_filter_strip.dart';
import 'widgets/month_calendar_grid.dart';
import 'widgets/plan_clients_editor.dart';
import 'widgets/slot_edit_sheet.dart';

/// The Schedule tab. Same screen for admin + employee — admin actions are
/// hidden when the current user isn't an admin.
class PlannerScreen extends ConsumerWidget {
  const PlannerScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(plannerSelectedMonthProvider);
    final planAsync = ref.watch(plannerPlanProvider);
    final auth = ref.watch(authStateProvider);
    final isAdmin = auth is AuthAuthenticated && auth.user.isAdmin;
    final currentUserId =
        auth is AuthAuthenticated ? auth.user.id : null;

    return Scaffold(
      body: Column(
        children: [
          _MonthHeader(),
          Expanded(
            child: planAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => _ErrorState(message: e.toString()),
              data: (plan) {
                if (plan == null) {
                  return _NoPlanState(
                    canCreate: isAdmin,
                    year: selected.year,
                    month: selected.month,
                  );
                }
                return _PlanContent(
                  plan: plan,
                  isAdmin: isAdmin,
                  currentUserId: isAdmin ? null : currentUserId,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _MonthHeader extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(plannerSelectedMonthProvider);
    final plan = ref.watch(plannerPlanProvider).valueOrNull;
    final monthLabel = MonthlyPlan(
      id: 0,
      year: selected.year,
      month: selected.month,
      status: 'draft',
      planClients: const [],
      slots: const [],
    ).displayMonthYear;

    return Material(
      color: Colors.white,
      elevation: 1,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            IconButton(
              icon: const Icon(Icons.chevron_left),
              tooltip: 'Previous month',
              onPressed: () {
                ref.read(plannerSelectedMonthProvider.notifier).state =
                    selected.previous();
                ref.read(plannerClientFilterProvider.notifier).state = null;
              },
            ),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      monthLabel,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    if (plan != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: _PlanStatusBadge(plan: plan),
                      ),
                  ],
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.chevron_right),
              tooltip: 'Next month',
              onPressed: () {
                ref.read(plannerSelectedMonthProvider.notifier).state =
                    selected.next();
                ref.read(plannerClientFilterProvider.notifier).state = null;
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanStatusBadge extends StatelessWidget {
  final MonthlyPlan plan;
  const _PlanStatusBadge({required this.plan});

  @override
  Widget build(BuildContext context) {
    final isDraft = plan.isDraft;
    final color = isDraft ? AppTheme.warning : AppTheme.success;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        isDraft
            ? 'Draft · ${plan.totalCommitments} planned · ${plan.totalPlacedSlots} placed'
            : 'Confirmed · ${plan.totalMaterialized} live tasks',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _NoPlanState extends ConsumerWidget {
  final bool canCreate;
  final int year;
  final int month;

  const _NoPlanState({
    required this.canCreate,
    required this.year,
    required this.month,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.calendar_month, size: 56, color: AppTheme.slate300),
            const SizedBox(height: 16),
            const Text(
              'No plan for this month yet.',
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppTheme.slate700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              canCreate
                  ? 'Create a plan to start scheduling posts and videos.'
                  : 'No content has been scheduled yet.',
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 13, color: AppTheme.slate500),
            ),
            if (canCreate) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                icon: const Icon(Icons.add),
                label: const Text('Create plan'),
                onPressed: () => _create(context, ref),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, WidgetRef ref) async {
    try {
      await ref.read(plannerRepositoryProvider).createPlan(
            year: year,
            month: month,
          );
      ref.invalidate(plannerPlanProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, size: 48, color: AppTheme.error),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.error),
            ),
          ],
        ),
      ),
    );
  }
}

class _PlanContent extends ConsumerWidget {
  final MonthlyPlan plan;
  final bool isAdmin;
  final int? currentUserId;

  const _PlanContent({
    required this.plan,
    required this.isAdmin,
    required this.currentUserId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final filterClientId = ref.watch(plannerClientFilterProvider);
    final filteredSlots = filterClientId == null
        ? plan.slots
        : plan.slots.where((s) => s.clientId == filterClientId).toList();

    return Column(
      children: [
        ClientFilterStrip(plan: plan),
        const Divider(height: 1, thickness: 1, color: AppTheme.slate200),
        Expanded(
          child: SingleChildScrollView(
            child: MonthCalendarGrid(
              year: plan.year,
              month: plan.month,
              slots: filteredSlots,
              highlightUserId: currentUserId,
              onSlotTap: (slot) async {
                if (!isAdmin) return;
                await showModalBottomSheet<bool>(
                  context: context,
                  isScrollControlled: true,
                  shape: const RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.vertical(top: Radius.circular(20)),
                  ),
                  builder: (_) =>
                      SlotEditSheet(slot: slot, planId: plan.id),
                );
              },
              onSlotMoved: !isAdmin
                  ? null
                  : (slot, newDate) => _moveSlot(context, ref, plan.id, slot, newDate),
            ),
          ),
        ),
        SafeArea(
          top: false,
          child: _BottomActions(plan: plan, isAdmin: isAdmin),
        ),
      ],
    );
  }

  Future<void> _moveSlot(
    BuildContext context,
    WidgetRef ref,
    int planId,
    dynamic slot,
    DateTime newDate,
  ) async {
    final dateStr =
        '${newDate.year.toString().padLeft(4, '0')}-${newDate.month.toString().padLeft(2, '0')}-${newDate.day.toString().padLeft(2, '0')}';
    try {
      await ref.read(plannerRepositoryProvider).updateSlot(
            planId: planId,
            slotId: slot.id as int,
            slotDate: dateStr,
            isLocked: true,
          );
      ref.invalidate(plannerPlanProvider);
    } on ApiException catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _BottomActions extends ConsumerStatefulWidget {
  final MonthlyPlan plan;
  final bool isAdmin;

  const _BottomActions({required this.plan, required this.isAdmin});

  @override
  ConsumerState<_BottomActions> createState() => _BottomActionsState();
}

class _BottomActionsState extends ConsumerState<_BottomActions> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    if (!widget.isAdmin) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _busy ? null : _exportPdf,
                icon: const Icon(Icons.picture_as_pdf_outlined),
                label: const Text('Export PDF'),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
              ),
            ),
          ],
        ),
      );
    }

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: AppTheme.slate200, width: 1)),
      ),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      child: Row(
        children: [
          IconButton(
            tooltip: 'Manage clients',
            onPressed: _busy ? null : _openClients,
            icon: const Icon(Icons.business),
          ),
          IconButton(
            tooltip: 'Export PDF',
            onPressed: _busy ? null : _exportPdf,
            icon: const Icon(Icons.picture_as_pdf_outlined),
          ),
          const Spacer(),
          if (widget.plan.isDraft || widget.plan.isConfirmed) ...[
            OutlinedButton.icon(
              onPressed: _busy ? null : () => _runGenerate(rebalance: false),
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Generate'),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: _busy ? null : _confirm,
              icon: _busy
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(widget.plan.isDraft ? Icons.check : Icons.update),
              label: Text(widget.plan.isDraft ? 'Confirm' : 'Confirm changes'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _openClients() async {
    await Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => PlanClientsEditor(initialPlan: widget.plan),
      ),
    );
  }

  Future<void> _runGenerate({required bool rebalance}) async {
    if (widget.plan.planClients.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Add at least one client first.')),
      );
      return;
    }

    setState(() => _busy = true);
    try {
      final repo = ref.read(plannerRepositoryProvider);
      final PlannerGenerateResult result = rebalance
          ? await repo.rebalance(widget.plan.id)
          : await repo.generate(widget.plan.id);
      ref.invalidate(plannerPlanProvider);
      if (!mounted) return;
      _showResult(result);
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showResult(PlannerGenerateResult result) {
    final color = result.conflicts.isEmpty ? AppTheme.success : AppTheme.warning;
    final headline = result.conflicts.isEmpty
        ? 'Placed ${result.placed} slots cleanly.'
        : 'Placed ${result.placed} slots, ${result.conflicts.length} conflicts.';

    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: Row(
          children: [
            Icon(
              result.conflicts.isEmpty ? Icons.check_circle : Icons.warning,
              color: color,
            ),
            const SizedBox(width: 8),
            const Text('Auto-placer ran'),
          ],
        ),
        content: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(headline,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              if (result.conflicts.isNotEmpty) ...[
                const SizedBox(height: 12),
                ...result.conflicts.map(
                  (c) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text('• $c',
                        style: const TextStyle(fontSize: 12)),
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirm() async {
    final isFirst = widget.plan.isDraft;
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(isFirst ? 'Confirm plan?' : 'Confirm changes?'),
        content: Text(
          isFirst
              ? 'This will create real tasks for every slot and notify each assignee. You can still edit individual slots afterwards.'
              : 'This will create tasks for any new slots and apply edits to existing tasks. Affected employees get one notification each.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(isFirst ? 'Confirm' : 'Apply changes'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() => _busy = true);
    try {
      final result =
          await ref.read(plannerRepositoryProvider).confirm(widget.plan.id);
      ref.invalidate(plannerPlanProvider);
      // The new tasks should appear in everyone's Tasks tab immediately.
      ref.invalidate(adminAllTasksProvider);
      ref.invalidate(myTasksProvider);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(result.isFirstConfirm
            ? 'Plan confirmed — ${result.newTaskCount} tasks created.'
            : 'Changes applied — ${result.newTaskCount} new, ${result.changedSlotCount} edited.'),
      ));
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _exportPdf() async {
    setState(() => _busy = true);
    try {
      await PlannerPdfExport.exportAndShare(widget.plan);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Export failed: $e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }
}
