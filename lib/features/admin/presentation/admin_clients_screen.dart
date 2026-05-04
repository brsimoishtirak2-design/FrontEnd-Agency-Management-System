import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_client.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_enter.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_list_panel.dart';
import '../../../shared/widgets/app_list_row.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../data/admin_clients_providers.dart';

/// Admin Clients tab — shows ALL clients across the agency.
class AdminClientsScreen extends ConsumerStatefulWidget {
  const AdminClientsScreen({super.key});

  @override
  ConsumerState<AdminClientsScreen> createState() =>
      _AdminClientsScreenState();
}

class _AdminClientsScreenState extends ConsumerState<AdminClientsScreen> {
  bool _showArchived = false;

  static final List<AgencyClient> _skeletonRows = List.generate(
    5,
    (i) => const AgencyClient(
      id: 0,
      name: 'Loading client',
      companyName: 'Company name',
      status: 'active',
      branches: null,
      branchesCount: 0,
      industry: 'Industry',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final clientsAsync = ref.watch(adminClientsListProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppTheme.brandPrimary,
        onRefresh: () async {
          ref.invalidate(adminClientsListProvider);
          await ref.read(adminClientsListProvider.future);
        },
        child: clientsAsync.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _ClientsScroll(
              clients: _skeletonRows,
              showArchived: false,
              onToggleArchived: (_) {},
            ),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState(
                title: 'Could not load clients',
                message: error.toString(),
                onRetry: () => ref.invalidate(adminClientsListProvider),
              ),
            ],
          ),
          data: (clients) {
            final filtered = _showArchived
                ? clients
                : clients.where((c) => !c.isArchived).toList();
            if (filtered.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _FilterRow(
                    count: 0,
                    showArchived: _showArchived,
                    onToggle: (v) =>
                        setState(() => _showArchived = v),
                  ),
                  AppEmptyState(
                    icon: Icons.business_outlined,
                    title: _showArchived
                        ? 'No clients match'
                        : 'No clients yet',
                    subtitle: _showArchived
                        ? 'Toggle the eye icon to hide archived items.'
                        : "Tap '+ New Client' to add one.",
                  ),
                ],
              );
            }
            return AppEnter(
              child: _ClientsScroll(
                clients: filtered,
                showArchived: _showArchived,
                onToggleArchived: (v) =>
                    setState(() => _showArchived = v),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.adminCreateClient),
        icon: const Icon(LucideIcons.plus),
        label: const Text('New Client'),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _ClientsScroll extends StatelessWidget {
  final List<AgencyClient> clients;
  final bool showArchived;
  final ValueChanged<bool> onToggleArchived;

  const _ClientsScroll({
    required this.clients,
    required this.showArchived,
    required this.onToggleArchived,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _FilterRow(
            count: clients.length,
            showArchived: showArchived,
            onToggle: onToggleArchived,
          ),
          AppListPanel(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: clients.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.slate100,
              ),
              itemBuilder: (context, index) {
                final client = clients[index];
                final branchesCount = client.branchesCount ?? 0;
                final subtitleParts = <String>[
                  if (client.companyName != null &&
                      client.companyName!.isNotEmpty)
                    client.companyName!,
                  '$branchesCount '
                      '${branchesCount == 1 ? "branch" : "branches"}',
                  if (client.industry != null &&
                      client.industry!.isNotEmpty)
                    client.industry!,
                ];
                return AppListRow(
                  onTap: () => context.push(
                    AppRoute.adminClientDetailPath(client.id),
                  ),
                  dimmed: client.isArchived,
                  title: Text(
                    client.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    subtitleParts.join('  ·  '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: client.isArchived
                      ? AppStatusPill.neutral('Archived')
                      : const Icon(
                          LucideIcons.chevronRight,
                          color: AppTheme.slate300,
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

class _FilterRow extends StatelessWidget {
  final int count;
  final bool showArchived;
  final ValueChanged<bool> onToggle;

  const _FilterRow({
    required this.count,
    required this.showArchived,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? "client" : "clients"}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(
              showArchived
                  ? LucideIcons.eyeOff
                  : LucideIcons.eye,
              size: 20,
              color: AppTheme.slate700,
            ),
            onPressed: () => onToggle(!showArchived),
          ),
        ],
      ),
    );
  }
}
