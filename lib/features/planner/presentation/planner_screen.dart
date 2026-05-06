import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/monthly_plan.dart';
import '../../../shared/models/planner_slot.dart';
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
import 'widgets/slot_chip.dart';
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

class _PlanContent extends ConsumerStatefulWidget {
  final MonthlyPlan plan;
  final bool isAdmin;
  final int? currentUserId;

  const _PlanContent({
    required this.plan,
    required this.isAdmin,
    required this.currentUserId,
  });

  @override
  ConsumerState<_PlanContent> createState() => _PlanContentState();
}

class _PlanContentState extends ConsumerState<_PlanContent> {
  DateTime? _expandedDate;
  bool _isDraggingFromPanel = false;

  void _expandDay(DateTime date) {
    setState(() => _expandedDate = date);
  }

  void _closeExpander() {
    setState(() {
      _expandedDate = null;
      _isDraggingFromPanel = false;
    });
  }

  void _onPanelDragStateChange(bool dragging) {
    setState(() => _isDraggingFromPanel = dragging);
  }

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final filterClientId = ref.watch(plannerClientFilterProvider);
    final filteredSlots = filterClientId == null
        ? plan.slots
        : plan.slots.where((s) => s.clientId == filterClientId).toList();

    // Day expander state — when set, the panel renders above the bottom of
    // the calendar and shares the same widget tree so drag-and-drop from a
    // chip in the panel onto a calendar cell stays alive.
    final expandedSlots = _expandedDate == null
        ? const <PlannerSlot>[]
        : filteredSlots
            .where((s) =>
                s.slotDate.year == _expandedDate!.year &&
                s.slotDate.month == _expandedDate!.month &&
                s.slotDate.day == _expandedDate!.day)
            .toList();

    return Column(
      children: [
        ClientFilterStrip(plan: plan),
        const Divider(height: 1, thickness: 1, color: AppTheme.slate200),
        Expanded(
          child: Stack(
            children: [
              Positioned.fill(
                child: SingleChildScrollView(
                  child: MonthCalendarGrid(
                    year: plan.year,
                    month: plan.month,
                    slots: filteredSlots,
                    highlightUserId: widget.currentUserId,
                    onSlotTap: (slot) async {
                      if (!widget.isAdmin) return;
                      await showModalBottomSheet<bool>(
                        context: context,
                        isScrollControlled: true,
                        backgroundColor: Colors.white,
                        shape: const RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.vertical(top: Radius.circular(20)),
                        ),
                        builder: (_) =>
                            SlotEditSheet(slot: slot, planId: plan.id),
                      );
                    },
                    onSlotMoved: !widget.isAdmin
                        ? null
                        : (slot, newDate) {
                            _moveSlot(
                              context,
                              ref,
                              plan.id,
                              slot,
                              newDate,
                            );
                            // Close the expander after a successful drop.
                            if (_expandedDate != null) _closeExpander();
                          },
                    onOverflowTap: (date, _) => _expandDay(date),
                  ),
                ),
              ),
              if (_expandedDate != null)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _isDraggingFromPanel,
                    child: Opacity(
                      opacity: _isDraggingFromPanel ? 0.0 : 1.0,
                      child: Stack(
                        children: [
                          // Backdrop — light blur + darken the calendar so the
                          // dialog stands out. Tap dismisses.
                          Positioned.fill(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: _closeExpander,
                              child: BackdropFilter(
                                filter: ImageFilter.blur(
                                  sigmaX: 6,
                                  sigmaY: 6,
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          ),
                          // The dialog itself.
                          Center(
                            child: ConstrainedBox(
                              constraints:
                                  const BoxConstraints(maxWidth: 760),
                              child: Padding(
                                padding: const EdgeInsets.all(24),
                                child: _DayExpanderPanel(
                                  date: _expandedDate!,
                                  slots: expandedSlots,
                                  planId: plan.id,
                                  isAdmin: widget.isAdmin,
                                  onClose: _closeExpander,
                                  onDragStateChange:
                                      _onPanelDragStateChange,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: _BottomActions(plan: plan, isAdmin: widget.isAdmin),
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
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // On narrow phones, the Generate button collapses to icon-only so
          // the primary CTA always stays fully visible.
          final isNarrow = constraints.maxWidth < 420;

          final secondaries = [
            IconButton(
              tooltip: 'Manage clients',
              onPressed: _busy ? null : _openClients,
              icon: const Icon(Icons.business),
              visualDensity: VisualDensity.compact,
            ),
            IconButton(
              tooltip: 'Export PDF',
              onPressed: _busy ? null : _exportPdf,
              icon: const Icon(Icons.picture_as_pdf_outlined),
              visualDensity: VisualDensity.compact,
            ),
          ];

          if (!widget.plan.isDraft && !widget.plan.isConfirmed) {
            return Row(children: secondaries);
          }

          final generateBtn = isNarrow
              ? IconButton(
                  tooltip: 'Generate',
                  onPressed:
                      _busy ? null : () => _runGenerate(rebalance: false),
                  icon: const Icon(Icons.auto_awesome),
                  visualDensity: VisualDensity.compact,
                )
              : OutlinedButton.icon(
                  onPressed:
                      _busy ? null : () => _runGenerate(rebalance: false),
                  icon: const Icon(Icons.auto_awesome, size: 18),
                  label: const Text('Generate'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                  ),
                );

          final confirmBtn = FilledButton.icon(
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
                : Icon(
                    widget.plan.isDraft ? Icons.check : Icons.update,
                    size: 18,
                  ),
            label: Text(widget.plan.isDraft ? 'Confirm' : 'Apply'),
            style: FilledButton.styleFrom(
              padding: const EdgeInsets.symmetric(
                horizontal: 14,
                vertical: 10,
              ),
            ),
          );

          return Row(
            children: [
              ...secondaries,
              const Spacer(),
              generateBtn,
              const SizedBox(width: 6),
              confirmBtn,
            ],
          );
        },
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

/// Inline panel that overlays the bottom of the calendar to show every
/// slot for one day. Lives inside the calendar's widget tree (not a modal
/// route), so a [LongPressDraggable] chip inside the panel can be dragged
/// directly onto a calendar cell behind it — both share the same Overlay.
class _DayExpanderPanel extends ConsumerWidget {
  final DateTime date;
  final List<PlannerSlot> slots;
  final int planId;
  final bool isAdmin;
  final VoidCallback onClose;
  final ValueChanged<bool>? onDragStateChange;

  const _DayExpanderPanel({
    required this.date,
    required this.slots,
    required this.planId,
    required this.isAdmin,
    required this.onClose,
    this.onDragStateChange,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final dayLabel =
        '${_weekday(date)}, ${_monthName(date.month)} ${date.day}';
    final maxHeight = MediaQuery.of(context).size.height * 0.6;

    return Material(
      elevation: 16,
      shadowColor: Colors.black.withValues(alpha: 0.25),
      color: Colors.white,
      borderRadius: BorderRadius.circular(20),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        top: false,
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: maxHeight),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(24, 16, 12, 20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Row(
                        children: [
                          Text(
                            dayLabel,
                            style: const TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: AppTheme.slate100,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Text(
                              '${slots.length} slot${slots.length == 1 ? '' : 's'}',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppTheme.slate700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      icon: const Icon(Icons.close, size: 22),
                      onPressed: onClose,
                    ),
                  ],
                ),
                if (isAdmin)
                  Padding(
                    padding: const EdgeInsets.only(right: 12, top: 4, bottom: 12),
                    child: Text(
                      'Hold a chip and drag onto a date in the calendar above to move it.',
                      style: const TextStyle(
                        fontSize: 13,
                        color: AppTheme.slate500,
                      ),
                    ),
                  )
                else
                  const SizedBox(height: 8),
                Flexible(
                  child: Padding(
                    padding: const EdgeInsets.only(right: 12),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: const EdgeInsets.only(bottom: 4),
                      itemCount: slots.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final s = slots[i];
                        final chip = SlotChip(
                          slot: s,
                          onTap: !isAdmin
                              ? null
                              : () async {
                                  await showModalBottomSheet<bool>(
                                    context: context,
                                    isScrollControlled: true,
                                    backgroundColor: Colors.white,
                                    shape: const RoundedRectangleBorder(
                                      borderRadius: BorderRadius.vertical(
                                        top: Radius.circular(20),
                                      ),
                                    ),
                                    builder: (_) => SlotEditSheet(
                                      slot: s,
                                      planId: planId,
                                    ),
                                  );
                                },
                        );
                        if (!isAdmin) return chip;
                        return LongPressDraggable<PlannerSlot>(
                          data: s,
                          delay: const Duration(milliseconds: 200),
                          onDragStarted: () =>
                              onDragStateChange?.call(true),
                          onDragEnd: (_) =>
                              onDragStateChange?.call(false),
                          feedback: Material(
                            color: Colors.transparent,
                            child: ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 240),
                              child: Container(
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(8),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withValues(alpha: 0.18),
                                      blurRadius: 8,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: SlotChip(slot: s),
                              ),
                            ),
                          ),
                          childWhenDragging: const SizedBox.shrink(),
                          child: chip,
                        );
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  static const _weekdayShort = [
    'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun',
  ];
  String _weekday(DateTime d) => _weekdayShort[d.weekday - 1];

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
    'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
  ];
  String _monthName(int m) => _months[m - 1];
}
