import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/agency_user.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../../auth/data/auth_providers.dart';
import '../data/admin_users_providers.dart';

/// Admin employee detail screen. Shows the user profile + admin
/// actions: reset password, deactivate / reactivate. Edit screen
/// lands later — for now the edit pencil shows a snackbar.
class AdminEmployeeDetailScreen extends ConsumerStatefulWidget {
  final int userId;

  const AdminEmployeeDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminEmployeeDetailScreen> createState() =>
      _AdminEmployeeDetailScreenState();
}

class _AdminEmployeeDetailScreenState
    extends ConsumerState<AdminEmployeeDetailScreen> {
  bool _isProcessing = false;

  Future<void> _openResetPasswordSheet(AgencyUser user) async {
    final newPassword = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _ResetPasswordSheet(userName: user.name),
    );

    if (newPassword == null || newPassword.isEmpty) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(adminUsersRepositoryProvider)
          .resetPassword(user.id, newPassword);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Password reset for ${user.name}.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 5),
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      String displayMessage = e.message;
      if (e.isValidationError && e.validationErrors != null) {
        final firstErrors = e.validationErrors!.entries
            .map((entry) => '${entry.key}: ${entry.value.first}')
            .take(3)
            .join('\n');
        displayMessage = firstErrors;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(displayMessage),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not reset password: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleDeactivate(AgencyUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Deactivate ${user.name}?'),
        content: const Text(
          'This will:\n'
          '• Log them out of all devices\n'
          '• Hide them from new task assignment\n'
          '• Preserve all task history\n'
          'You can reactivate later.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancel'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: AppTheme.error),
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Deactivate'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(adminUsersRepositoryProvider)
          .deactivateUser(user.id);
      ref.invalidate(adminAllUsersProvider);
      ref.invalidate(adminUserDetailProvider(user.id));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Deactivated ${user.name}.'),
          backgroundColor: AppTheme.success,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } on ApiException catch (e) {
      if (!mounted) return;
      final msg = (e.statusCode == 403 &&
              e.code == 'self_deactivate_blocked')
          ? 'You cannot deactivate your own account.'
          : e.message;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(msg),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not deactivate: $e'),
          backgroundColor: AppTheme.error,
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  Future<void> _handleReactivate(AgencyUser user) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Reactivate ${user.name}?'),
        content: Text(
          '${user.name} will be active again and available for task '
          'assignment. They will use their existing password to log in '
          '(use Reset Password if they forgot it).',
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
    if (!mounted) return;

    setState(() => _isProcessing = true);
    try {
      await ref
          .read(adminUsersRepositoryProvider)
          .reactivateUser(user.id);
      ref.invalidate(adminAllUsersProvider);
      ref.invalidate(adminUserDetailProvider(user.id));

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Reactivated ${user.name}.'),
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
    final userAsync = ref.watch(adminUserDetailProvider(widget.userId));
    final authState = ref.watch(authStateProvider);
    final selfId =
        (authState is AuthAuthenticated) ? authState.user.id : null;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Employee'),
        actions: userAsync.maybeWhen(
          data: (user) {
            final isSelf = selfId != null && selfId == user.id;
            return [
              IconButton(
                tooltip: 'Edit',
                icon: const Icon(Icons.edit_outlined),
                onPressed: _isProcessing
                    ? null
                    : () => context.push(
                          AppRoute.adminEditEmployeePath(user.id),
                          extra: user,
                        ),
              ),
              IconButton(
                tooltip: 'Reset password',
                icon: const Icon(Icons.lock_reset),
                onPressed: _isProcessing
                    ? null
                    : () => _openResetPasswordSheet(user),
              ),
              if (!isSelf)
                IconButton(
                  tooltip: user.isActive ? 'Deactivate' : 'Reactivate',
                  icon: Icon(
                    user.isActive
                        ? Icons.person_off_outlined
                        : Icons.restore,
                  ),
                  onPressed: _isProcessing
                      ? null
                      : () => user.isActive
                          ? _handleDeactivate(user)
                          : _handleReactivate(user),
                ),
            ];
          },
          orElse: () => const [SizedBox.shrink()],
        ),
      ),
      body: userAsync.when(
        loading: () => const _LoadingView(),
        error: (error, _) => _ErrorView(
          message: error.toString(),
          onRetry: () =>
              ref.invalidate(adminUserDetailProvider(widget.userId)),
        ),
        data: (user) => _Body(
          user: user,
          isSelf: selfId != null && selfId == user.id,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Body — sections
// ---------------------------------------------------------------------------

class _Body extends StatelessWidget {
  final AgencyUser user;
  final bool isSelf;
  const _Body({required this.user, required this.isSelf});

  bool get _hasAssignment =>
      (user.locationName != null && user.locationName!.isNotEmpty) ||
      (user.departmentName != null && user.departmentName!.isNotEmpty) ||
      (user.jobTitleName != null && user.jobTitleName!.isNotEmpty);

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        _HeaderCard(user: user, isSelf: isSelf),
        const SizedBox(height: 12),
        _ContactCard(user: user),
        if (_hasAssignment) ...[
          const SizedBox(height: 12),
          _AssignmentCard(user: user),
        ],
        const SizedBox(height: 12),
        _AccountCard(user: user),
      ],
    );
  }
}

class _HeaderCard extends StatelessWidget {
  final AgencyUser user;
  final bool isSelf;
  const _HeaderCard({required this.user, required this.isSelf});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: AppTheme.slate100,
              child: Text(
                user.initials,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      color: AppTheme.slate700,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 4,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        user.name,
                        style: Theme.of(context)
                            .textTheme
                            .titleLarge
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      user.isAdmin
                          ? AppStatusPill.brand('Admin')
                          : AppStatusPill.neutral('Employee'),
                      if (!user.isActive)
                        AppStatusPill.neutral('Inactive'),
                      if (isSelf) AppStatusPill.neutral('(You)'),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    user.email,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.slate500,
                        ),
                  ),
                  if (user.subtitle.isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      user.subtitle,
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                            color: AppTheme.slate700,
                          ),
                    ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactCard extends StatelessWidget {
  final AgencyUser user;
  const _ContactCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Contact'),
            const SizedBox(height: 10),
            _IconRow(
              icon: Icons.email_outlined,
              text: user.email,
            ),
            _IconRow(
              icon: Icons.phone_outlined,
              text: (user.phone == null || user.phone!.isEmpty)
                  ? '—'
                  : user.phone!,
            ),
          ],
        ),
      ),
    );
  }
}

class _AssignmentCard extends StatelessWidget {
  final AgencyUser user;
  const _AssignmentCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Assignment'),
            const SizedBox(height: 10),
            _IconRow(
              icon: Icons.place_outlined,
              text: user.locationName ?? '—',
            ),
            _IconRow(
              icon: Icons.account_tree_outlined,
              text: user.departmentName ?? '—',
            ),
            _IconRow(
              icon: Icons.badge_outlined,
              text: user.jobTitleName ?? '—',
            ),
          ],
        ),
      ),
    );
  }
}

class _AccountCard extends StatelessWidget {
  final AgencyUser user;
  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    final lastLogin = formatFullDateTime(user.lastLoginAt);
    final mustChange = user.mustChangePassword ? 'Yes' : 'No';

    String? createdByText;
    if (user.creatorName != null) {
      final created = formatDayDate(user.createdAt);
      createdByText = created != null
          ? '${user.creatorName} ($created)'
          : user.creatorName;
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AppSectionLabel('Account'),
            const SizedBox(height: 10),
            _LabeledRow(
              label: 'Status',
              value: Align(
                alignment: Alignment.centerLeft,
                child: user.isActive
                    ? AppStatusPill.brand('Active')
                    : AppStatusPill.neutral('Inactive'),
              ),
            ),
            _LabeledRow(
              label: 'Last login',
              value: Text(lastLogin),
            ),
            _LabeledRow(
              label: 'Must change pw',
              value: Text(mustChange),
            ),
            if (createdByText != null)
              _LabeledRow(
                label: 'Created by',
                value: Text(createdByText),
              ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Reset password bottom sheet
// ---------------------------------------------------------------------------

class _ResetPasswordSheet extends StatefulWidget {
  final String userName;
  const _ResetPasswordSheet({required this.userName});

  @override
  State<_ResetPasswordSheet> createState() => _ResetPasswordSheetState();
}

class _ResetPasswordSheetState extends State<_ResetPasswordSheet> {
  final _formKey = GlobalKey<FormState>();
  final _controller = TextEditingController();
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;
    Navigator.of(context).pop(_controller.text);
  }

  @override
  Widget build(BuildContext context) {
    final viewInsets = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInsets),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppTheme.slate300,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Reset password',
                style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 6),
              Text(
                'Set a new password for ${widget.userName}. They will '
                'be logged out of all devices and required to change '
                'it on next login.',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.slate500,
                    ),
              ),
              const SizedBox(height: 16),
              Form(
                key: _formKey,
                child: TextFormField(
                  controller: _controller,
                  obscureText: _obscure,
                  autofocus: true,
                  decoration: InputDecoration(
                    hintText: 'At least 8 characters',
                    prefixIcon: const Icon(Icons.lock_outline, size: 18),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _obscure
                            ? Icons.visibility_outlined
                            : Icons.visibility_off_outlined,
                        size: 18,
                      ),
                      onPressed: () =>
                          setState(() => _obscure = !_obscure),
                    ),
                  ),
                  validator: (v) {
                    final text = v ?? '';
                    if (text.isEmpty) return 'New password is required.';
                    if (text.length < 8) {
                      return 'Must be at least 8 characters.';
                    }
                    return null;
                  },
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () =>
                          Navigator.of(context).pop(),
                      style: OutlinedButton.styleFrom(
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _submit,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppTheme.error,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(46),
                      ),
                      child: const Text('Reset Password'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared primitives
// ---------------------------------------------------------------------------

class _IconRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _IconRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 16, color: AppTheme.slate500),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppTheme.slate700,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

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
            width: 110,
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
          'Could not load employee',
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

