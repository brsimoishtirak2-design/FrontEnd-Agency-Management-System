import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_department.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_enter.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_list_panel.dart';
import '../../../shared/widgets/app_list_row.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../data/admin_departments_providers.dart';

/// Admin Settings → Departments list.
class AdminDepartmentsScreen extends ConsumerStatefulWidget {
  const AdminDepartmentsScreen({super.key});

  @override
  ConsumerState<AdminDepartmentsScreen> createState() =>
      _AdminDepartmentsScreenState();
}

class _AdminDepartmentsScreenState
    extends ConsumerState<AdminDepartmentsScreen> {
  bool _showArchived = false;

  static final List<AgencyDepartment> _skeletonRows = List.generate(
    5,
    (i) => AgencyDepartment(
      id: i,
      name: 'Loading department',
      locationId: 0,
      locationName: 'Location',
      isActive: true,
      usersCount: 0,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final deptsAsync = ref.watch(adminDepartmentsListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Departments'),
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
          ref.invalidate(adminDepartmentsListProvider);
          await ref.read(adminDepartmentsListProvider.future);
        },
        child: deptsAsync.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _DepartmentsPanel(rows: _skeletonRows),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState(
                title: 'Could not load departments',
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(adminDepartmentsListProvider),
              ),
            ],
          ),
          data: (depts) {
            final filtered = _showArchived
                ? depts
                : depts.where((d) => !d.isArchived).toList();
            if (filtered.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppEmptyState(
                    icon: Icons.account_tree_outlined,
                    title: _showArchived
                        ? 'No departments match'
                        : 'No departments yet',
                    subtitle: _showArchived
                        ? 'Toggle the eye icon to hide archived items.'
                        : "Tap '+' to add one.",
                  ),
                ],
              );
            }
            return AppEnter(child: _DepartmentsPanel(rows: filtered));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        heroTag: 'admin_departments_fab',
        onPressed: () => context.push(AppRoute.adminCreateDepartment),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Department'),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _DepartmentsPanel extends StatelessWidget {
  final List<AgencyDepartment> rows;
  const _DepartmentsPanel({required this.rows});

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
            final dept = rows[index];
            final users = dept.usersCount ?? 0;
            final loc = dept.locationName ?? '—';
            return AppListRow(
              onTap: () => context.push(
                AppRoute.adminEditDepartmentPath(dept.id),
                extra: dept,
              ),
              dimmed: dept.isArchived,
              title: Text(
                dept.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$loc  ·  $users ${users == 1 ? "user" : "users"}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: dept.isArchived
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
