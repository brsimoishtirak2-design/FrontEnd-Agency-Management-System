import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small status pill — tinted background + same-hue text + rounded.
///
/// Modeled on Stripe / Linear / Vercel status indicators. No border;
/// the tinted background is enough chrome.
///
/// Variants:
///   - brand   — green tint (Active, Admin, Primary, etc.)
///   - neutral — slate tint (Inactive, Archived, Employee, "(You)")
///   - warning — amber tint
///   - danger  — red tint
class AppStatusPill extends StatelessWidget {
  final String label;
  final Color background;
  final Color foreground;

  const AppStatusPill({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  factory AppStatusPill.brand(String label) => AppStatusPill(
        label: label,
        background: AppTheme.brandPrimary.withValues(alpha: 0.15),
        foreground: AppTheme.brandPrimaryDark,
      );

  factory AppStatusPill.neutral(String label) => AppStatusPill(
        label: label,
        background: AppTheme.slate100,
        foreground: AppTheme.slate700,
      );

  factory AppStatusPill.warning(String label) => AppStatusPill(
        label: label,
        background: AppTheme.warning.withValues(alpha: 0.15),
        foreground: AppTheme.warning,
      );

  factory AppStatusPill.danger(String label) => AppStatusPill(
        label: label,
        background: AppTheme.error.withValues(alpha: 0.15),
        foreground: AppTheme.error,
      );

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: foreground,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          height: 1.2,
        ),
      ),
    );
  }
}
