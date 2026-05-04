import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../utils/initials.dart';

/// Compact circular avatar for a client. Shows the logo when one is
/// present; otherwise renders the client name's initials on a slate
/// background. Falls back to initials if the network image fails to
/// load (e.g., disconnected, broken URL).
class ClientAvatar extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final double radius;

  const ClientAvatar({
    super.key,
    required this.name,
    this.logoUrl,
    this.radius = 18,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: AppTheme.slate100,
      backgroundImage: hasLogo ? NetworkImage(logoUrl!) : null,
      onBackgroundImageError: hasLogo ? (_, _) {} : null,
      child: hasLogo
          ? null
          : Text(
              nameInitials(name),
              style: TextStyle(
                color: AppTheme.slate700,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.72,
              ),
            ),
    );
  }
}
