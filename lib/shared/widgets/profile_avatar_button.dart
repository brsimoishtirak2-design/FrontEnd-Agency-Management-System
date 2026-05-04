import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../../features/auth/data/auth_providers.dart';
import '../models/user.dart';

/// Small avatar button intended for the AppBar actions slot. Reads
/// the authenticated user from authStateProvider, renders a circle
/// with the user's initials, and pushes to the Profile screen on tap.
///
/// Already includes its own right-edge padding so the circle isn't
/// flush against the screen edge.
class ProfileAvatarButton extends ConsumerWidget {
  const ProfileAvatarButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authState = ref.watch(authStateProvider);
    final initials =
        authState is AuthAuthenticated ? authState.user.initials : '';

    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: GestureDetector(
        onTap: () => context.push(AppRoute.profile),
        behavior: HitTestBehavior.opaque,
        child: CircleAvatar(
          radius: 18,
          backgroundColor: AppTheme.brandPrimary.withValues(alpha: 0.15),
          child: Text(
            initials,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: AppTheme.brandPrimaryDark,
            ),
          ),
        ),
      ),
    );
  }
}
