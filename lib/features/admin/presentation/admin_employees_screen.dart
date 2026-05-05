import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_user.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_enter.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_list_panel.dart';
import '../../../shared/widgets/app_list_row.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../data/admin_users_providers.dart';

/// Admin Employees tab — shows ALL users (admins + employees), with a
/// toggle for inactive accounts.
///
/// Embedded inside [AdminShellScreen]'s IndexedStack on tab index 2;
/// uses a transparent Scaffold so the shell's app bar shows through.
class AdminEmployeesScreen extends ConsumerStatefulWidget {
  const AdminEmployeesScreen({super.key});

  @override
  ConsumerState<AdminEmployeesScreen> createState() =>
      _AdminEmployeesScreenState();
}

class _AdminEmployeesScreenState
    extends ConsumerState<AdminEmployeesScreen> {
  bool _showInactive = false;

  static final List<AgencyUser> _skeletonRows = List.generate(
    5,
    (i) => const AgencyUser(
      id: 0,
      name: 'Loading name',
      email: 'loading@example.com',
      phone: null,
      role: 'employee',
      isActive: true,
      profilePhoto: null,
      locationName: 'Location',
      departmentName: null,
      jobTitleName: 'Title',
    ),
  );

  @override
  Widget build(BuildContext context) {
    final usersAsync = ref.watch(adminAllUsersProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: RefreshIndicator(
        color: AppTheme.brandPrimary,
        onRefresh: () async {
          ref.invalidate(adminAllUsersProvider);
          await ref.read(adminAllUsersProvider.future);
        },
        child: usersAsync.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _EmployeesScroll(
              users: _skeletonRows,
              showInactive: false,
              onToggleInactive: (_) {},
            ),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState(
                title: 'Could not load employees',
                message: error.toString(),
                onRetry: () => ref.invalidate(adminAllUsersProvider),
              ),
            ],
          ),
          data: (users) {
            final filtered = (_showInactive
                    ? users
                    : users.where((u) => u.isActive).toList())
              ..sort((a, b) =>
                  a.name.toLowerCase().compareTo(b.name.toLowerCase()));
            if (filtered.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  _FilterRow(
                    count: 0,
                    showInactive: _showInactive,
                    onToggle: (v) =>
                        setState(() => _showInactive = v),
                  ),
                  const AppEmptyState(
                    icon: Icons.people_outline,
                    title: 'No employees',
                    subtitle: "Tap '+ Add Employee' to create one.",
                  ),
                ],
              );
            }
            return AppEnter(
              child: _EmployeesScroll(
                users: filtered,
                showInactive: _showInactive,
                onToggleInactive: (v) =>
                    setState(() => _showInactive = v),
              ),
            );
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.adminCreateEmployee),
        icon: const Icon(LucideIcons.userPlus),
        label: const Text('Add Employee'),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _EmployeesScroll extends StatelessWidget {
  final List<AgencyUser> users;
  final bool showInactive;
  final ValueChanged<bool> onToggleInactive;

  const _EmployeesScroll({
    required this.users,
    required this.showInactive,
    required this.onToggleInactive,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      child: Column(
        children: [
          _FilterRow(
            count: users.length,
            showInactive: showInactive,
            onToggle: onToggleInactive,
          ),
          AppListPanel(
            margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: users.length,
              separatorBuilder: (_, _) => const Divider(
                height: 1,
                thickness: 1,
                color: AppTheme.slate100,
                indent: 60,
              ),
              itemBuilder: (context, index) {
                final user = users[index];
                return AppListRow(
                  onTap: () => context.push(
                    AppRoute.adminEmployeeDetailPath(user.id),
                  ),
                  dimmed: !user.isActive,
                  leading: UserAvatar(
                    name: user.name,
                    photoUrl: user.profilePhoto,
                    radius: 18,
                  ),
                  title: Text(
                    user.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    user.subtitle.isEmpty ? user.email : user.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: !user.isActive
                      ? AppStatusPill.neutral('Inactive')
                      : (user.isAdmin
                          ? AppStatusPill.brand('Admin')
                          : const Icon(
                              LucideIcons.chevronRight,
                              color: AppTheme.slate300,
                            )),
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
  final bool showInactive;
  final ValueChanged<bool> onToggle;

  const _FilterRow({
    required this.count,
    required this.showInactive,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 8, 8),
      child: Row(
        children: [
          Text(
            '$count ${count == 1 ? "user" : "users"}',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppTheme.slate500,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const Spacer(),
          IconButton(
            tooltip: showInactive ? 'Hide inactive' : 'Show inactive',
            icon: Icon(
              showInactive
                  ? LucideIcons.eyeOff
                  : LucideIcons.eye,
              size: 20,
              color: AppTheme.slate700,
            ),
            onPressed: () => onToggle(!showInactive),
          ),
        ],
      ),
    );
  }
}
