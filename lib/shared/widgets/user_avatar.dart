import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';
import '../utils/initials.dart';

/// Compact circular avatar for a user. Shows the profile photo when one
/// is set; otherwise renders the user's initials on a slate background.
/// Falls back to initials if the network image fails to load.
///
/// Used everywhere we surface a person — chat bubbles, assignees lists,
/// admin employees screens, and the self-profile header. Keeps a single
/// look for "this is who that is" across the whole app.
class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final Color? backgroundColor;
  final Color? foregroundColor;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 18,
    this.backgroundColor,
    this.foregroundColor,
  });

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    return CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppTheme.slate100,
      backgroundImage: hasPhoto ? NetworkImage(photoUrl!) : null,
      onBackgroundImageError: hasPhoto ? (_, _) {} : null,
      child: hasPhoto
          ? null
          : Text(
              nameInitials(name),
              style: TextStyle(
                color: foregroundColor ?? AppTheme.slate700,
                fontWeight: FontWeight.w700,
                fontSize: radius * 0.72,
              ),
            ),
    );
  }
}
