import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// Compact placeholder shown in place of a `DropdownButtonFormField`
/// while its data is loading. Same height (56px) as a regular field
/// so the surrounding layout doesn't jump when the dropdown resolves.
class AppDropdownLoading extends StatelessWidget {
  const AppDropdownLoading({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: const Center(
        child: SizedBox(
          width: 18,
          height: 18,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: AppTheme.brandPrimary,
          ),
        ),
      ),
    );
  }
}

/// Empty state shown when a dropdown has no pickable options. The
/// caller passes the message ("No active locations. Add one first.").
class AppDropdownEmpty extends StatelessWidget {
  final String message;
  const AppDropdownEmpty({super.key, required this.message});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.slate100),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        message,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppTheme.slate500,
              fontStyle: FontStyle.italic,
            ),
      ),
    );
  }
}

/// Error state shown in place of a dropdown with a Retry button
/// that delegates back to the caller (typically `ref.invalidate(...)`).
class AppDropdownError extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const AppDropdownError({
    super.key,
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border.all(color: AppTheme.error.withValues(alpha: 0.5)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, size: 18, color: AppTheme.error),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppTheme.error,
                  ),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
