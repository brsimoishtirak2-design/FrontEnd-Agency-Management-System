import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/router/app_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../shared/models/user.dart';
import '../../../shared/utils/date_format.dart';
import '../../../shared/widgets/app_section_label.dart';
import '../../../shared/widgets/app_status_pill.dart';
import '../../../shared/widgets/user_avatar.dart';
import '../../auth/data/auth_providers.dart';

/// Self-service profile screen.
///
/// Two render modes:
///   - Standalone (admin pushes to `/profile`): wraps body in its own
///     Scaffold + AppBar.
///   - `embeddedInTab: true` (employee shell's Profile tab): renders the
///     body directly so the parent shell controls the AppBar.
///
/// Personal info is read-only here — tap the card (or the AppBar
/// pencil in standalone mode) to push to `EditProfileScreen`.
/// Email + Assignment are admin-managed and shown read-only.
class ProfileScreen extends ConsumerStatefulWidget {
  final bool embeddedInTab;

  const ProfileScreen({super.key, this.embeddedInTab = false});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _isProcessing = false;

  void _openResetPassword() {
    context.push(AppRoute.selfResetPassword);
  }

  Future<void> _handleLogout() async {
    setState(() => _isProcessing = true);
    try {
      await ref.read(authStateProvider.notifier).logout();
    } finally {
      if (mounted) setState(() => _isProcessing = false);
    }
  }

  void _openEditProfile() {
    context.push(AppRoute.editProfile);
  }

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);
    if (authState is! AuthAuthenticated) {
      const fallback = Center(child: Text('Not signed in.'));
      return widget.embeddedInTab
          ? fallback
          : const Scaffold(body: fallback);
    }
    final user = authState.user;

    final body = SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _HeaderCard(user: user),
          const SizedBox(height: 16),
          _PersonalInfoCard(
            user: user,
            onTap: _isProcessing ? null : _openEditProfile,
          ),
          const SizedBox(height: 16),
          if (user.locationName != null ||
              user.departmentName != null ||
              user.jobTitleName != null)
            _AssignmentCard(user: user),
          if (user.locationName != null ||
              user.departmentName != null ||
              user.jobTitleName != null)
            const SizedBox(height: 16),
          _AccountCard(user: user),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _openResetPassword,
            icon: const Icon(Icons.lock_reset, size: 18),
            label: const Text('Reset password'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppTheme.brandPrimary,
              side: const BorderSide(color: AppTheme.slate200),
            ),
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _isProcessing ? null : _handleLogout,
            icon: const Icon(Icons.logout, size: 18),
            label: const Text('Logout'),
            style: OutlinedButton.styleFrom(
              minimumSize: const Size.fromHeight(48),
              foregroundColor: AppTheme.error,
              side: const BorderSide(color: AppTheme.slate200),
            ),
          ),
        ],
      ),
    );

    if (widget.embeddedInTab) return body;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        actions: [
          IconButton(
            tooltip: 'Edit profile',
            icon: const Icon(Icons.edit_outlined),
            onPressed: _isProcessing ? null : _openEditProfile,
          ),
        ],
      ),
      body: body,
    );
  }
}

// ---------------------------------------------------------------------------
// Header card — avatar + name + role badge + email
// ---------------------------------------------------------------------------

class _HeaderCard extends ConsumerStatefulWidget {
  final User user;
  const _HeaderCard({required this.user});

  @override
  ConsumerState<_HeaderCard> createState() => _HeaderCardState();
}

class _HeaderCardState extends ConsumerState<_HeaderCard> {
  bool _isUploading = false;

  Future<void> _changePhoto() async {
    final action = await _pickAction();
    if (action == null) return;

    if (action == _PhotoAction.remove) {
      await _runPhotoOp(() => ref
          .read(authRepositoryProvider)
          .deleteProfilePhoto());
      return;
    }

    final source = action == _PhotoAction.camera
        ? ImageSource.camera
        : ImageSource.gallery;
    final XFile? picked = await ImagePicker().pickImage(
      source: source,
      maxWidth: 1024,
      maxHeight: 1024,
      imageQuality: 85,
    );
    if (picked == null) return;

    await _runPhotoOp(() => ref
        .read(authRepositoryProvider)
        .uploadProfilePhoto(picked.path));
  }

  Future<void> _runPhotoOp(Future<User> Function() op) async {
    setState(() => _isUploading = true);
    try {
      final updated = await op();
      ref.read(authStateProvider.notifier).replaceUser(updated);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Profile photo updated.'),
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
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }

  Future<_PhotoAction?> _pickAction() async {
    final hasPhoto =
        widget.user.profilePhoto != null && widget.user.profilePhoto!.isNotEmpty;
    return showModalBottomSheet<_PhotoAction>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppTheme.slate300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 12),
            ListTile(
              leading: const Icon(Icons.photo_library_outlined),
              title: const Text('Choose from gallery'),
              onTap: () => Navigator.of(sheetCtx).pop(_PhotoAction.gallery),
            ),
            ListTile(
              leading: const Icon(Icons.photo_camera_outlined),
              title: const Text('Take a photo'),
              onTap: () => Navigator.of(sheetCtx).pop(_PhotoAction.camera),
            ),
            if (hasPhoto)
              ListTile(
                leading: const Icon(Icons.delete_outline,
                    color: AppTheme.error),
                title: const Text('Remove photo',
                    style: TextStyle(color: AppTheme.error)),
                onTap: () => Navigator.of(sheetCtx).pop(_PhotoAction.remove),
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final user = widget.user;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
        child: Column(
          children: [
            Stack(
              children: [
                UserAvatar(
                  name: user.name,
                  photoUrl: user.profilePhoto,
                  radius: 40,
                  backgroundColor: AppTheme.slate100,
                  foregroundColor: AppTheme.brandPrimaryDark,
                ),
                if (_isUploading)
                  const Positioned.fill(
                    child: CircleAvatar(
                      radius: 40,
                      backgroundColor: Colors.black54,
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2.5,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Material(
                    color: AppTheme.brandPrimaryDark,
                    shape: const CircleBorder(
                      side: BorderSide(color: Colors.white, width: 2),
                    ),
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: _isUploading ? null : _changePhoto,
                      child: const SizedBox(
                        width: 30,
                        height: 30,
                        child: Icon(
                          Icons.photo_camera_rounded,
                          size: 16,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              user.name,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 6),
            Text(
              user.email,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.slate500,
                  ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

enum _PhotoAction { gallery, camera, remove }

// ---------------------------------------------------------------------------
// Personal info card — name + phone, tap to push to EditProfileScreen
// ---------------------------------------------------------------------------

class _PersonalInfoCard extends StatelessWidget {
  final User user;
  final VoidCallback? onTap;
  const _PersonalInfoCard({required this.user, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.hardEdge,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 8, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Padding(
                padding: EdgeInsets.only(right: 8, bottom: 12),
                child: AppSectionLabel('Personal info'),
              ),
              _DetailRow(
                icon: Icons.person_outline,
                label: 'Name',
                value: user.name,
                showChevron: true,
              ),
              const SizedBox(height: 12),
              _DetailRow(
                icon: Icons.phone_outlined,
                label: 'Phone',
                value: user.phone,
                placeholder: 'Not set',
                showChevron: true,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Assignment card — read-only, admin-managed
// ---------------------------------------------------------------------------

class _AssignmentCard extends StatelessWidget {
  final User user;
  const _AssignmentCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionLabel('Assignment'),
            const SizedBox(height: 4),
            Text(
              'Managed by admin',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.slate500,
                    fontStyle: FontStyle.italic,
                  ),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.place_outlined,
              label: 'Location',
              value: user.locationName,
              placeholder: '—',
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.account_tree_outlined,
              label: 'Department',
              value: user.departmentName,
              placeholder: '—',
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.badge_outlined,
              label: 'Job title',
              value: user.jobTitleName,
              placeholder: '—',
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Account card — role / status / last login
// ---------------------------------------------------------------------------

class _AccountCard extends StatelessWidget {
  final User user;
  const _AccountCard({required this.user});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const AppSectionLabel('Account'),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.shield_outlined,
              label: 'Role',
              value: user.isAdmin ? 'Admin' : 'Employee',
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.toggle_on_outlined,
              label: 'Status',
              valueWidget: user.isActive
                  ? AppStatusPill.brand('Active')
                  : AppStatusPill.neutral('Inactive'),
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.access_time,
              label: 'Last login',
              value: formatFullDateTime(user.lastLoginAt),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Detail row — icon + label + value (or widget) + optional chevron
// ---------------------------------------------------------------------------

class _DetailRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;
  final String? placeholder;
  final Widget? valueWidget;
  final bool showChevron;

  const _DetailRow({
    required this.icon,
    required this.label,
    this.value,
    this.placeholder,
    this.valueWidget,
    this.showChevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final v = value;
    final isEmpty = v == null || v.isEmpty;
    final displayValue = isEmpty ? (placeholder ?? '—') : v;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Icon(icon, size: 18, color: AppTheme.slate500),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppTheme.slate500,
                    ),
              ),
              const SizedBox(height: 2),
              if (valueWidget != null)
                valueWidget!
              else
                Text(
                  displayValue,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isEmpty ? AppTheme.slate500 : AppTheme.slate900,
                        fontStyle:
                            isEmpty ? FontStyle.italic : FontStyle.normal,
                        fontWeight: FontWeight.w500,
                      ),
                ),
            ],
          ),
        ),
        if (showChevron)
          const Icon(Icons.chevron_right, size: 20, color: AppTheme.slate300),
      ],
    );
  }
}

