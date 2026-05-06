import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/agency_client.dart';
import '../../../../shared/models/monthly_plan.dart';
import '../../../../shared/models/monthly_plan_client.dart';
import '../../../admin/data/admin_clients_providers.dart';
import '../../data/planner_providers.dart';
import 'client_avatar.dart';

/// Full-screen sheet listing the per-client commitments for a plan and
/// letting the manager add/edit/remove them.
///
/// Watches [plannerPlanProvider] so newly-added commitments appear
/// immediately without needing to pop and re-open the screen.
class PlanClientsEditor extends ConsumerWidget {
  final MonthlyPlan initialPlan;
  const PlanClientsEditor({super.key, required this.initialPlan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live plan from the provider takes precedence over the snapshot we
    // were constructed with, so the list refreshes after every save.
    final live = ref.watch(plannerPlanProvider).valueOrNull;
    final plan = live ?? initialPlan;

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
                onPressed: () => _openPicker(context, ref, plan),
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

  Future<void> _openPicker(
    BuildContext context,
    WidgetRef ref,
    MonthlyPlan plan,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ClientPickerSheet(plan: plan),
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
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        leading: ClientAvatar(
          name: commitment.clientName ?? 'Client',
          logoUrl: commitment.clientLogo,
          size: 40,
        ),
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
                builder: (_) => _CountsDialog(
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

/// ---------------------------------------------------------------------------
/// Picker sheet — browse / search the agency's clients and pick one to add.
/// ---------------------------------------------------------------------------

class _ClientPickerSheet extends ConsumerStatefulWidget {
  final MonthlyPlan plan;
  const _ClientPickerSheet({required this.plan});

  @override
  ConsumerState<_ClientPickerSheet> createState() => _ClientPickerSheetState();
}

class _ClientPickerSheetState extends ConsumerState<_ClientPickerSheet> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // Refetch the live plan so the exclude-set reflects what's been added
    // since the picker was opened (avoids a stale snapshot).
    final livePlan = ref.watch(plannerPlanProvider).valueOrNull ?? widget.plan;
    final excluded = livePlan.planClients.map((c) => c.clientId).toSet();
    final clients = ref.watch(adminClientsListProvider);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Column(
          children: [
            const SizedBox(height: 8),
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
                  'Add client to plan',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: TextField(
                onChanged: (v) => setState(() => _query = v),
                autofocus: false,
                decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search, size: 20),
                  hintText: 'Search clients',
                  filled: true,
                  fillColor: AppTheme.slate50,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.slate200),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppTheme.slate200),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: clients.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(child: Text('Could not load clients: $e')),
                data: (list) {
                  final filtered = _filter(list, excluded);
                  if (filtered.isEmpty) {
                    return _emptyState(_query.isNotEmpty);
                  }
                  return ListView.separated(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    itemCount: filtered.length,
                    separatorBuilder: (_, _) =>
                        const Divider(height: 1, color: AppTheme.slate100),
                    itemBuilder: (_, i) {
                      final c = filtered[i];
                      return ListTile(
                        contentPadding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        leading: ClientAvatar(
                          name: c.name,
                          logoUrl: c.logo,
                          size: 40,
                        ),
                        title: Text(
                          c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600),
                        ),
                        subtitle: c.companyName != null && c.companyName!.isNotEmpty
                            ? Text(c.companyName!)
                            : null,
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => _onPick(c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  List<AgencyClient> _filter(List<AgencyClient> all, Set<int> excluded) {
    final term = _query.trim().toLowerCase();
    return all.where((c) {
      if (excluded.contains(c.id)) return false;
      if (c.isArchived) return false;
      if (term.isEmpty) return true;
      return c.name.toLowerCase().contains(term) ||
          (c.companyName?.toLowerCase().contains(term) ?? false);
    }).toList();
  }

  Widget _emptyState(bool isSearching) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              isSearching ? Icons.search_off : Icons.business_outlined,
              size: 40,
              color: AppTheme.slate300,
            ),
            const SizedBox(height: 8),
            Text(
              isSearching
                  ? 'No clients match "$_query".'
                  : 'All clients are already in the plan.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppTheme.slate500),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _onPick(AgencyClient client) async {
    Navigator.of(context).pop();
    await showDialog<void>(
      context: context,
      builder: (_) => _CountsDialog(
        plan: widget.plan,
        pickedClient: client,
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Counts dialog — used both for adding a freshly-picked client and for
/// editing an existing commitment.
/// ---------------------------------------------------------------------------

class _CountsDialog extends ConsumerStatefulWidget {
  final MonthlyPlan plan;
  final MonthlyPlanClient? initialCommitment;
  final AgencyClient? pickedClient;

  const _CountsDialog({
    required this.plan,
    this.initialCommitment,
    this.pickedClient,
  });

  @override
  ConsumerState<_CountsDialog> createState() => _CountsDialogState();
}

class _CountsDialogState extends ConsumerState<_CountsDialog> {
  late final TextEditingController _postsCtl;
  late final TextEditingController _videosCtl;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
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
    final isEditing = widget.initialCommitment != null;
    final clientName = isEditing
        ? widget.initialCommitment!.clientName ??
            'Client #${widget.initialCommitment!.clientId}'
        : widget.pickedClient!.name;
    final clientLogo = isEditing
        ? widget.initialCommitment!.clientLogo
        : widget.pickedClient!.logo;

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  ClientAvatar(name: clientName, logoUrl: clientLogo, size: 44),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          clientName,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          widget.plan.displayMonthYear,
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppTheme.slate500,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _NumberField(label: 'Posts per month', controller: _postsCtl),
              const SizedBox(height: 12),
              _NumberField(label: 'Videos per month', controller: _videosCtl),
              const SizedBox(height: 20),
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: _saving ? null : () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Saving…' : 'Save'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    final clientId = widget.initialCommitment?.clientId ??
        widget.pickedClient?.id;
    if (clientId == null) return;

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
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
      ),
    );
  }
}
