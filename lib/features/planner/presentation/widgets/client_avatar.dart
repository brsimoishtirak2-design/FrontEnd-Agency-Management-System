import 'package:flutter/material.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/utils/initials.dart';

/// Round client avatar — shows the client logo when available, otherwise
/// renders the client's two-letter initials inside a circle.
class ClientAvatar extends StatelessWidget {
  final String name;
  final String? logoUrl;
  final double size;

  const ClientAvatar({
    super.key,
    required this.name,
    this.logoUrl,
    this.size = 36,
  });

  @override
  Widget build(BuildContext context) {
    final hasLogo = logoUrl != null && logoUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.brandPrimary.withValues(alpha: 0.12),
        image: hasLogo
            ? DecorationImage(
                image: NetworkImage(logoUrl!),
                fit: BoxFit.cover,
              )
            : null,
      ),
      alignment: Alignment.center,
      child: hasLogo
          ? null
          : Text(
              nameInitials(name),
              style: TextStyle(
                fontSize: size * 0.38,
                fontWeight: FontWeight.w800,
                color: AppTheme.brandPrimaryDark,
              ),
            ),
    );
  }
}
