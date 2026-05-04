import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:skeletonizer/skeletonizer.dart';

import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_job_title.dart';
import '../../../shared/widgets/app_empty_state.dart';
import '../../../shared/widgets/app_enter.dart';
import '../../../shared/widgets/app_error_state.dart';
import '../../../shared/widgets/app_list_panel.dart';
import '../../../shared/widgets/app_list_row.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../data/admin_job_titles_providers.dart';

/// Admin Settings → Job Titles list.
class AdminJobTitlesScreen extends ConsumerStatefulWidget {
  const AdminJobTitlesScreen({super.key});

  @override
  ConsumerState<AdminJobTitlesScreen> createState() =>
      _AdminJobTitlesScreenState();
}

class _AdminJobTitlesScreenState
    extends ConsumerState<AdminJobTitlesScreen> {
  bool _showArchived = false;

  static final List<AgencyJobTitle> _skeletonRows = List.generate(
    5,
    (i) => AgencyJobTitle(
      id: i,
      name: 'Loading title',
      isActive: true,
      usersCount: 0,
    ),
  );

  @override
  Widget build(BuildContext context) {
    final jobsAsync = ref.watch(adminJobTitlesListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Job Titles'),
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
          ref.invalidate(adminJobTitlesListProvider);
          await ref.read(adminJobTitlesListProvider.future);
        },
        child: jobsAsync.when(
          loading: () => Skeletonizer(
            enabled: true,
            child: _JobTitlesPanel(rows: _skeletonRows),
          ),
          error: (error, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              AppErrorState(
                title: 'Could not load job titles',
                message: error.toString(),
                onRetry: () =>
                    ref.invalidate(adminJobTitlesListProvider),
              ),
            ],
          ),
          data: (jobs) {
            final filtered = _showArchived
                ? jobs
                : jobs.where((j) => !j.isArchived).toList();
            if (filtered.isEmpty) {
              return ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  AppEmptyState(
                    icon: Icons.badge_outlined,
                    title: _showArchived
                        ? 'No job titles match'
                        : 'No job titles yet',
                    subtitle: _showArchived
                        ? 'Toggle the eye icon to hide archived items.'
                        : "Tap '+' to add one.",
                  ),
                ],
              );
            }
            return AppEnter(child: _JobTitlesPanel(rows: filtered));
          },
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push(AppRoute.adminCreateJobTitle),
        icon: const Icon(LucideIcons.plus),
        label: const Text('Add Job Title'),
        backgroundColor: AppTheme.brandPrimary,
        foregroundColor: Colors.white,
      ),
    );
  }
}

class _JobTitlesPanel extends StatelessWidget {
  final List<AgencyJobTitle> rows;
  const _JobTitlesPanel({required this.rows});

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
            final job = rows[index];
            final users = job.usersCount ?? 0;
            return AppListRow(
              onTap: () => context.push(
                AppRoute.adminEditJobTitlePath(job.id),
                extra: job,
              ),
              dimmed: job.isArchived,
              title: Text(
                job.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(
                '$users ${users == 1 ? "user" : "users"}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: job.isArchived
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
