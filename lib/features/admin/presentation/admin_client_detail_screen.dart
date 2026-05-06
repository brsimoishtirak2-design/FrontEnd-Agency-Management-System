import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_client.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../data/admin_clients_providers.dart';

/// Admin client detail screen. Shows the full client profile +
/// branches. Edit / archive / reactivate are wired; branch CRUD
/// remains stubbed.
class AdminClientDetailScreen extends ConsumerStatefulWidget {
  final int clientId;

  const AdminClientDetailScreen({super.key, required this.clientId});

  @override
  ConsumerState<AdminClientDetailScreen> createState() =>
      _AdminClientDetailScreenState();
}

class _AdminClientDetailScreenState
    extends ConsumerState<AdminClientDetailScreen> {
  bool _isProcessing = false;

  Future<void> _handleArchive(AgencyClient client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Archive client?'),
        content: Text(
          'Archiving "${client.name}" will:\n'
          '• Hide it from new task creation\n'
          '• Keep all existing task history\n'
          '• You can reactivate later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Archive'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(adminClientsRepositoryProvider)
          .archiveClient(client.id);
      ref.invalidate(adminClientsListProvider);
      ref.invalidate(adminClientWithBranchesProvider(client.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client "${client.name}" archived.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not archive: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReactivate(AgencyClient client) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Reactivate client?'),
        content: Text(
          '"${client.name}" will be active again and available '
          'for new tasks.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.brandPrimary,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Reactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(adminClientsRepositoryProvider)
          .reactivateClient(client.id);
      ref.invalidate(adminClientsListProvider);
      ref.invalidate(adminClientWithBranchesProvider(client.id));
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Client "${client.name}" reactivated.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(e.message),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not reactivate: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final clientAsync =
        ref.watch(adminClientWithBranchesProvider(widget.clientId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Client'),
        actions: clientAsync.maybeWhen(
          data: (client) => [
            IconButton(
              tooltip: 'Edit',
              icon: const Icon(Icons.edit_outlined),
              onPressed: _isProcessing
                  ? null
                  : () => context.push(
                        AppRoute.adminEditClientPath(client.id),
                        extra: client,
                      ),
            ),
            IconButton(
              tooltip: client.isArchived ? 'Reactivate' : 'Archive',
              icon: Icon(
                client.isArchived
                    ? Icons.restore
                    : Icons.archive_outlined,
              ),
              onPressed: _isProcessing
                  ? null
                  : () => client.isArchived
                      ? _handleReactivate(client)
                      : _handleArchive(client),
            ),
          ],
          orElse: () => const [SizedBox.shrink()],
        ),
      ),
      body: clientAsync.when(
        loading: () => const _LoadingView(),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () => ref
              .invalidate(adminClientWithBranchesProvider(widget.clientId)),
        ),
        data: (client) => _Body(client: client),
      ),
      floatingActionButton: clientAsync.maybeWhen(
        data: (client) => client.isArchived
            ? null
            : FloatingActionButton.extended(
                heroTag: 'admin_client_detail_fab',
                onPressed: () => context.push(
                  AppRoute.adminAddBranchToClientPath(client.id),
                ),
                icon: const Icon(Icons.add),
                label: const Text('Add branch'),
                backgroundColor: AppTheme.brandPrimary,
                foregroundColor: Colors.white,
              ),
        orElse: () => null,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — sections
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  final AgencyClient client;
  const _Body({required this.client});

  bool get _hasIdentity =>
      (client.companyName != null && client.companyName!.isNotEmpty) ||
      (client.industry != null && client.industry!.isNotEmpty);
  bool get _hasWebPresence =>
      (client.website != null && client.website!.isNotEmpty) ||
      (client.notes != null && client.notes!.isNotEmpty);
  bool get _hasSocialMedia =>
      client.instagramUrl != null ||
      client.facebookUrl != null ||
      client.tiktokUrl != null;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 96),
      children: [
        _HeaderCard(client: client),
        if (_hasIdentity) ...[
          const SizedBox(height: 12),
          _IdentityCard(client: client),
        ],
        if (_hasWebPresence) ...[
          const SizedBox(height: 12),
          _WebPresenceCard(client: client),
        ],
        if (_hasSocialMedia) ...[
          const SizedBox(height: 12),
          _SocialMediaCard(client: client),
        ],
        const SizedBox(height: 12),
        _BranchesCard(client: client),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Header card
// ---------------------------------------------------------------------------

class _HeaderCard extends StatelessWidget {
  final AgencyClient client;
  const _HeaderCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final branchCount =
        client.branches?.length ?? client.branchesCount ?? 0;
    final hasLogo = client.logo != null && client.logo!.isNotEmpty;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (hasLogo) ...[
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: AppTheme.slate100,
                    backgroundImage: NetworkImage(client.logo!),
                    onBackgroundImageError: (_, _) {},
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: Text(
                    client.name,
                    style:
                        Theme.of(context).textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                  ),
                ),
                const SizedBox(width: 8),
                client.isArchived
                    ? AppStatusPill.neutral('Archived')
                    : AppStatusPill.brand('Active'),
              ],
            ),
            if (client.companyName != null &&
                client.companyName!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                client.companyName!,
                style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      color: AppTheme.slate700,
                    ),
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 6,
              children: [
                _IconText(
                  icon: Icons.business_outlined,
                  text:
                      '$branchCount ${branchCount == 1 ? "branch" : "branches"}',
                ),
                if (client.industry != null &&
                    client.industry!.isNotEmpty)
                  _IconText(
                    icon: Icons.category_outlined,
                    text: client.industry!,
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Identity card
// ---------------------------------------------------------------------------

class _IdentityCard extends StatelessWidget {
  final AgencyClient client;
  const _IdentityCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Identity'),
            const SizedBox(height: 10),
            if (client.companyName != null &&
                client.companyName!.isNotEmpty)
              _LabeledRow(
                label: 'Company',
                value: Text(client.companyName!),
              ),
            if (client.industry != null && client.industry!.isNotEmpty)
              _LabeledRow(
                label: 'Industry',
                value: Text(client.industry!),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Web presence card
// ---------------------------------------------------------------------------

class _WebPresenceCard extends StatelessWidget {
  final AgencyClient client;
  const _WebPresenceCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Web presence'),
            const SizedBox(height: 10),
            if (client.website != null && client.website!.isNotEmpty)
              _LabeledRow(
                label: 'Website',
                value: InkWell(
                  onTap: () =>
                      _snack(context, 'URL launching — coming soon'),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Flexible(
                        child: Text(
                          client.website!,
                          style: TextStyle(
                            color: Colors.blue.shade700,
                            decoration: TextDecoration.underline,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.open_in_new,
                        size: 14,
                        color: Colors.blue.shade700,
                      ),
                    ],
                  ),
                ),
              ),
            if (client.notes != null && client.notes!.isNotEmpty)
              _LabeledRow(
                label: 'Notes',
                value: Text(client.notes!),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Social media card
// ---------------------------------------------------------------------------

class _SocialMediaCard extends StatelessWidget {
  final AgencyClient client;
  const _SocialMediaCard({required this.client});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Social media'),
            const SizedBox(height: 10),
            if (client.instagramUrl != null)
              _SocialRow(
                icon: Icons.camera_alt_outlined,
                value: client.instagramUrl!,
              ),
            if (client.facebookUrl != null)
              _SocialRow(
                icon: Icons.thumb_up_outlined,
                value: client.facebookUrl!,
              ),
            if (client.tiktokUrl != null)
              _SocialRow(
                icon: Icons.music_note_outlined,
                value: client.tiktokUrl!,
              ),
          ],
        ),
      ),
    );
  }
}

class _SocialRow extends StatelessWidget {
  final IconData icon;
  final String value;
  const _SocialRow({required this.icon, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppTheme.slate500),
          const SizedBox(width: 12),
          Expanded(child: Text(value)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Branches card
// ---------------------------------------------------------------------------

class _BranchesCard extends StatelessWidget {
  final AgencyClient client;
  const _BranchesCard({required this.client});

  @override
  Widget build(BuildContext context) {
    final branches = client.branches ?? const <AgencyClientBranch>[];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                AppSectionLabel('Branches'),
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppTheme.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    '${branches.length}',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate700,
                          fontWeight: FontWeight.w700,
                        ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 10),
            if (branches.isEmpty)
              Text(
                "No branches yet. Tap '+ Add branch' to add one.",
                style: TextStyle(
                  color: AppTheme.slate500,
                  fontStyle: FontStyle.italic,
                ),
              )
            else
              ...branches.map((b) => _BranchRow(branch: b)),
          ],
        ),
      ),
    );
  }
}

class _BranchRow extends StatelessWidget {
  final AgencyClientBranch branch;
  const _BranchRow({required this.branch});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push(
        AppRoute.adminEditBranchPath(branch.clientId, branch.id),
        extra: branch,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: AppTheme.slate100,
              child: Icon(
                Icons.business_outlined,
                size: 16,
                color: AppTheme.slate500,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    branch.branchName,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    branch.locationName ?? '—',
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: AppTheme.slate500,
                        ),
                  ),
                ],
              ),
            ),
            if (branch.isPrimary) ...[
              const SizedBox(width: 8),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: AppTheme.brandPrimary,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: const Text(
                  'Primary',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared primitives
// ---------------------------------------------------------------------------

class _LabeledRow extends StatelessWidget {
  final String label;
  final Widget value;
  const _LabeledRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 100,
            child: Text(
              label,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w600,
                  ),
            ),
          ),
          Expanded(child: value),
        ],
      ),
    );
  }
}

class _IconText extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconText({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: AppTheme.slate500),
        const SizedBox(width: 6),
        Text(
          text,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppTheme.slate500,
              ),
        ),
      ],
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 28,
        height: 28,
        child: CircularProgressIndicator(
          strokeWidth: 2.5,
          color: AppTheme.brandPrimary,
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorView({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(24),
      children: [
        const SizedBox(height: 60),
        Icon(Icons.cloud_off, size: 56, color: AppTheme.error),
        const SizedBox(height: 16),
        Text(
          'Could not load client',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
        const SizedBox(height: 6),
        Text(
          message,
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppTheme.slate500,
              ),
        ),
        const SizedBox(height: 24),
        ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// File-private snackbar helper
// ---------------------------------------------------------------------------

void _snack(BuildContext context, String message) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(message),
      behavior: SnackBarBehavior.floating,
    ),
  );
}
