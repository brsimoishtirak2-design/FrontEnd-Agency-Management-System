import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// White, hairline-bordered panel that wraps a list of [AppListRow]s.
///
/// This is the "list-as-one-panel" pattern (Stripe / Vercel / Linear
/// settings) — the entire list is one rounded card; rows are flat
/// inside with hairline dividers between them. Reads unambiguously
/// as "a group of items" without per-item card chrome.
///
/// Wrap inside `SingleChildScrollView` + a `ListView.separated` with
/// `shrinkWrap: true` + `physics: NeverScrollableScrollPhysics()` so
/// the outer scrollable handles pull-to-refresh.
class AppListPanel extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry margin;

  const AppListPanel({
    super.key,
    required this.child,
    this.margin = const EdgeInsets.all(16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: margin,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.slate100, width: 1),
        ),
        clipBehavior: Clip.antiAlias,
        child: child,
      ),
    );
  }
}
