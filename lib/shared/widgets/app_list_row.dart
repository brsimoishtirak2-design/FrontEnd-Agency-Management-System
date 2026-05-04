import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Cardless list row — Linear/Notion/Stripe pattern. Replaces the
/// "every row is a Card" approach that creates visual noise on long
/// lists.
///
/// Pair with `ListView.separated` + a 1px [Divider] (color
/// `AppTheme.slate100`) for hairline-divider list groups, OR drop
/// rows directly into a Column for simpler grouping.
///
/// Set [dimmed] to fade the row (used for archived/inactive rows).
class AppListRow extends StatelessWidget {
  final Widget? leading;
  final Widget title;
  final Widget? subtitle;
  final Widget? meta; // optional third line for chips/pills
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool dimmed;
  final EdgeInsetsGeometry padding;

  const AppListRow({
    super.key,
    required this.title,
    this.leading,
    this.subtitle,
    this.meta,
    this.trailing,
    this.onTap,
    this.dimmed = false,
    this.padding = const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
  });

  @override
  Widget build(BuildContext context) {
    final row = InkWell(
      onTap: onTap,
      child: Padding(
        padding: padding,
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            if (leading != null) ...[
              leading!,
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  DefaultTextStyle.merge(
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: AppTheme.slate900,
                        ),
                    child: title,
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    DefaultTextStyle.merge(
                      style:
                          Theme.of(context).textTheme.bodySmall?.copyWith(
                                color: AppTheme.slate500,
                              ),
                      child: subtitle!,
                    ),
                  ],
                  if (meta != null) ...[
                    const SizedBox(height: 8),
                    meta!,
                  ],
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: 12),
              trailing!,
            ],
          ],
        ),
      ),
    );

    return Opacity(
      opacity: dimmed ? 0.55 : 1.0,
      child: row,
    );
  }
}
