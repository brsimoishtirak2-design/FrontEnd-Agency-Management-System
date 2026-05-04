import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Small muted label used above form/section groups.
///
/// Pass the label as-is — sentence case is the recommended convention
/// (matches Linear/Notion). The widget renders it without case
/// transformation.
class AppSectionLabel extends StatelessWidget {
  final String label;
  const AppSectionLabel(this.label, {super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: AppTheme.slate500,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.1,
          ),
    );
  }
}
