import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/monthly_plan.dart';
import '../../../../shared/models/monthly_plan_client.dart';
import '../../../admin/data/admin_clients_providers.dart';
import '../../data/planner_providers.dart';

/// Full-screen sheet listing the per-client commitments for a plan and
/// letting the manager add/edit/remove them.
class PlanClientsEditor extends ConsumerWidget {
  final MonthlyPlan plan;
  const PlanClientsEditor({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Clients in ${plan.displayMonthYear}'),
      ),
      body: Column(
        children: [
          Expanded(
            child: plan.planClients.isEmpty
                ? _EmptyHint()
                : ListView.separated(
                    padding: const EdgeInsets.all(16),
                    itemCount: plan.planClients.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (_, i) => _ClientCommitmentTile(
                      plan: plan,
                      commitment: plan.planClients[i],
                    ),
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: FilledButton.icon(
                onPressed: () => _openAddDialog(context, ref),
                icon: const Icon(Icons.add),
                label: const Text('Add client'),
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openAddDialog(BuildContext context, WidgetRef ref) async {
    final existing = plan.planClients.map((c) => c.clientId).toSet();
    await showDialog<void>(
      context: context,
      builder: (_) => _ClientCommitmentDialog(
        plan: plan,
        excludeClientIds: existing,
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.business, size: 48, color: AppTheme.slate300),
            const SizedBox(height: 12),
            Text(
              'No clients in this plan yet.',
              style: TextStyle(
                fontSize: 14,
                color: AppTheme.slate500,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              'Add clients with their post/video counts, then run Generate.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12, color: AppTheme.slate500),
            ),
          ],
        ),
      ),
    );
  }
}

class _ClientCommitmentTile extends ConsumerWidget {
  final MonthlyPlan plan;
  final MonthlyPlanClient commitment;

  const _ClientCommitmentTile({required this.plan, required this.commitment});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(10),
        side: const BorderSide(color: AppTheme.slate200),
      ),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        title: Text(
          commitment.clientName ?? 'Client #${commitment.clientId}',
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Row(
            children: [
              _CountBadge(label: 'P', count: commitment.postsCount, color: AppTheme.info),
              const SizedBox(width: 6),
              _CountBadge(label: 'V', count: commitment.videosCount, color: AppTheme.warning),
              const SizedBox(width: 8),
              Text(
                '${commitment.totalCount} total',
                style: const TextStyle(fontSize: 12, color: AppTheme.slate500),
              ),
            ],
          ),
        ),
        trailing: PopupMenuButton<String>(
          onSelected: (action) async {
            if (action == 'edit') {
              await showDialog<void>(
                context: context,
                builder: (_) => _ClientCommitmentDialog(
                  plan: plan,
                  initialCommitment: commitment,
                ),
              );
            } else if (action == 'delete') {
              await _delete(context, ref);
            }
          },
          itemBuilder: (_) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit counts')),
            PopupMenuItem(value: 'delete', child: Text('Remove client')),
          ],
        ),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove client?'),
        content: Text(
          'Remove ${commitment.clientName ?? 'this client'} from the plan? '
          'Any unmaterialized slots for them in this month will also be deleted.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: FilledButton.styleFrom(backgroundColor: AppTheme.error),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(plannerRepositoryProvider).removePlanClient(
            planId: plan.id,
            clientId: commitment.clientId,
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

class _CountBadge extends StatelessWidget {
  final String label;
  final int count;
  final Color color;

  const _CountBadge({required this.label, required this.count, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 14,
            height: 14,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 9,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 4),
          Text(
            '$count',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.slate900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ClientCommitmentDialog extends ConsumerStatefulWidget {
  final MonthlyPlan plan;
  final MonthlyPlanClient? initialCommitment;
  final Set<int>? excludeClientIds;

  const _ClientCommitmentDialog({
    required this.plan,
    this.initialCommitment,
    this.excludeClientIds,
  });

  @override
  ConsumerState<_ClientCommitmentDialog> createState() =>
      _ClientCommitmentDialogState();
}

class _ClientCommitmentDialogState
    extends ConsumerState<_ClientCommitmentDialog> {
  int? _clientId;
  late final TextEditingController _postsCtl;
  late final TextEditingController _videosCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _clientId = widget.initialCommitment?.clientId;
    _postsCtl = TextEditingController(
      text: widget.initialCommitment?.postsCount.toString() ?? '0',
    );
    _videosCtl = TextEditingController(
      text: widget.initialCommitment?.videosCount.toString() ?? '0',
    );
  }

  @override
  void dispose() {
    _postsCtl.dispose();
    _videosCtl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final clients = ref.watch(adminClientsListProvider);
    final isEditing = widget.initialCommitment != null;

    return AlertDialog(
      title: Text(isEditing ? 'Edit client counts' : 'Add client to plan'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!isEditing) ...[
              clients.when(
                data: (list) {
                  final excluded = widget.excludeClientIds ?? const <int>{};
                  final available = list
                      .where((c) => !excluded.contains(c.id) && !c.isArchived)
                      .toList();
                  if (available.isEmpty) {
                    return const Text(
                      'All clients are already in the plan.',
                      style: TextStyle(color: AppTheme.slate500),
                    );
                  }
                  return DropdownButtonFormField<int>(
                    initialValue: _clientId,
                    decoration: const InputDecoration(
                      labelText: 'Client',
                      border: OutlineInputBorder(),
                    ),
                    items: available
                        .map((c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ))
                        .toList(),
                    onChanged: (v) => setState(() => _clientId = v),
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Could not load clients: $e'),
              ),
              const SizedBox(height: 16),
            ] else ...[
              Text(
                widget.initialCommitment!.clientName ??
                    'Client #${widget.initialCommitment!.clientId}',
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
            ],
            _NumberField(label: 'Posts per month', controller: _postsCtl),
            const SizedBox(height: 12),
            _NumberField(label: 'Videos per month', controller: _videosCtl),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    );
  }

  Future<void> _save() async {
    final clientId = _clientId ?? widget.initialCommitment?.clientId;
    if (clientId == null) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Pick a client first.')));
      return;
    }
    final posts = int.tryParse(_postsCtl.text) ?? 0;
    final videos = int.tryParse(_videosCtl.text) ?? 0;

    setState(() => _saving = true);
    try {
      await ref.read(plannerRepositoryProvider).upsertPlanClient(
            planId: widget.plan.id,
            clientId: clientId,
            postsCount: posts,
            videosCount: videos,
          );
      ref.invalidate(plannerPlanProvider);
      if (mounted) Navigator.of(context).pop();
    } on ApiException catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.message)));
      }
    }
  }
}

class _NumberField extends StatelessWidget {
  final String label;
  final TextEditingController controller;

  const _NumberField({required this.label, required this.controller});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: TextInputType.number,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}
