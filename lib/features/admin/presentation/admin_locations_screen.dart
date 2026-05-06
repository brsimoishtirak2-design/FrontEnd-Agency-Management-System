import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_location.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_enter.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_list_panel.dart';
import '../../../shared/widgets/app_list_row.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../data/admin_locations_providers.dart';

/// Admin Settings → Locations list. Pushed onto the navigation stack
/// from the Settings landing card; renders its own AppBar and FAB
/// (not embedded in the shell tab bar).
class AdminLocationsScreen extends ConsumerStatefulWidget {
  const AdminLocationsScreen({super.key});

  @override
  ConsumerState<AdminLocationsScreen> createState() =>
      _AdminLocationsScreenState();
}

class _AdminLocationsScreenState extends ConsumerState<AdminLocationsScreen> {
  bool _showArchived = false;

  static final List<AgencyLocation> _skeletonRows = List.generate(
    5,
    (i) => AgencyLocation(
      id: i,
      name: 'Loading location',
      isActive: true,
      usersCount: 0,
      departmentsCount: 0,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final locsAsync = ref.watch(adminLocationsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Locations'),
        actions: [
          IconButton(
            tooltip:
                _showArchived ? 'Hide archived' : 'Show archived',
            icon: Icon(
              _showArchived
                  ? LucideIcons.eyeOff
                  : LucideIcons.eye,
            ),
            onPressed: () =>
                setState(() => _showArchived = !_showArchived),
          ),
        ],
      ),
      body: RefreshIndicator(
        color: AppTheme.brandPrimary,
        onRefresh: () async {
          ref.invalidate(adminLocationsListProvider);
          await ref.read(adminLocationsListProvider.future);
        },
        child: locsAsync.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _LocationsPanel(rows: _skeletonRows),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState(
                title: 'Could not load locations',
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(adminLocationsListProvider),
              ),
            ],
          ),
          data: (locations) {
            final filtered = _showArchived
                ? locations
                : locations.where((l) => !l.isArchived).toList();
            if (filtered.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppEmptyState(
                    icon: Icons.place_outlined,
                    title: _showArchived
                        ? 'No locations match'
                        : 'No locations yet',
                    subtitle: _showArchived
                        ? 'Toggle the eye icon to hide archived items.'
                        : "Tap '+' to add one.",
                  ),
                ],
              );
            }
            return AppEnter(child: _LocationsPanel(rows: filtered));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_locations_fab',
        onPressed: () => context.push(AppRoute.adminCreateLocation),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Location'),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _LocationsPanel extends StatelessWidget {
  final List<AgencyLocation> rows;
  const _LocationsPanel({required this.rows});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: AppListPanel(
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: rows.length,
          separatorBuilder: (_, _) => const Divider(
            height: 1,
            thickness: 1,
            color: AppTheme.slate100,
          ),
          itemBuilder: (context, index) {
            final location = rows[index];
            final users = location.usersCount ?? 0;
            final depts = location.departmentsCount ?? 0;
            return AppListRow(
              onTap: () => context.push(
                AppRoute.adminEditLocationPath(location.id),
                extra: location,
              ),
              dimmed: location.isArchived,
              title: Text(
                location.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$users ${users == 1 ? "user" : "users"}  ·  '
                '$depts ${depts == 1 ? "department" : "departments"}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: location.isArchived
                  ? AppStatusPill.neutral('Archived')
                  : const Icon(
                      LucideIcons.chevronRight,
                      color: AppTheme.slate300,
                    ),
            );
          },
        ),
      ),
    );
  }
}
