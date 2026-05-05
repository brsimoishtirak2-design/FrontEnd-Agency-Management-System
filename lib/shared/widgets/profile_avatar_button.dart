import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/data/auth_providers.dart';
import 'user_avatar.dart';

/// Small avatar button intended for the AppBar actions slot. Reads
/// the authenticated user from authStateProvider, shows their profile
/// photo (or initials fallback), and pushes to the Profile screen on
/// tap. Already includes its own right-edge padding.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final user =
        authState is AuthAuthenticated ? authState.user : null;

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => context.push(AppRoute.profile),
        behavior: HitTestBehavior.opaque,
        child: UserAvatar(
          name: user?.name ?? '',
          photoUrl: user?.profilePhoto,
          radius: 18,
          backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.15),
          foregroundColor: AppTheme.brandPrimaryDark,
        ),
      ),
    );
  }
}
