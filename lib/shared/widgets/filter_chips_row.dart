import 'package:flutter/material.dart';

import '../../core/theme/app_theme.dart';

/// One option for a [FilterChipsRow]. Generic over the value type.
class FilterChipOption<T> {
  /// The value reported via `onSelected` when this chip is picked.
  final T value;

  /// Visible label shown on the chip.
  final String label;

  /// Optional small leading icon (size 14, slot-default coloring).
  final IconData? icon;

  /// Optional accent color for the selected state. Defaults to
  /// [AppTheme.brandPrimary] when null.
  final Color? activeColor;

  /// Optional count badge rendered to the right of the label
  /// (e.g., "Assigned · 3"). Pass null to omit.
  final int? count;

  const FilterChipOption({
    required this.value,
    required this.label,
    this.icon,
    this.activeColor,
    this.count,
  });
}

/// Horizontal scrollable row of M3 [FilterChip]s. Designed to sit in
/// the body, just below an AppBar, above a list. Single-select: tapping
/// a selected chip deselects it.
///
/// Use generics to keep the chip values strongly typed in the parent
/// (`FilterChipsRow<TaskStatus>(...)`, `FilterChipsRow<int>(...)`,
/// etc.). When [selectedValue] is non-null, a trailing "Clear" chip
/// appears that calls `onSelected(null)`.
class FilterChipsRow<T> extends StatelessWidget {
  final List<FilterChipOption<T>> options;
  final T? selectedValue;
  final ValueChanged<T?> onSelected;
  final String? label;
  final EdgeInsetsGeometry padding;

  const FilterChipsRow({
    super.key,
    required this.options,
    required this.selectedValue,
    required this.onSelected,
    this.label,
    this.padding = const EdgeInsets.symmetric(horizontal: 16),
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (label != null) ...[
            Text(
              label!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppTheme.slate500,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            const SizedBox(height: 6),
          ],
          // Left-anchored. On wide screens (desktop) all chips fit at
          // their natural width with no scroll. On narrow viewports
          // (mobile) the SingleChildScrollView handles overflow.
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < options.length; i++) ...[
                  _buildOptionChip(context, options[i]),
                  if (i < options.length - 1 || selectedValue != null)
                    const SizedBox(width: 8),
                ],
                if (selectedValue != null)
                  FilterChip(
                    selected: false,
                    showCheckmark: false,
                    avatar: const Icon(Icons.close, size: 14),
                    label: const Text('Clear'),
                    onSelected: (_) => onSelected(null),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildOptionChip(BuildContext context, FilterChipOption<T> opt) {
    final isSelected = opt.value == selectedValue;
    final accent = opt.activeColor ?? AppTheme.brandPrimary;
    final displayLabel =
        opt.count == null ? opt.label : '${opt.label}  ·  ${opt.count}';

    return FilterChip(
      selected: isSelected,
      label: Text(displayLabel),
      avatar: opt.icon != null ? Icon(opt.icon, size: 14) : null,
      selectedColor: accent.withValues(alpha: 0.15),
      checkmarkColor: accent,
      side: BorderSide(
        color: isSelected ? accent : AppTheme.slate200,
        width: isSelected ? 1.5 : 1,
      ),
      labelStyle: TextStyle(
        color: isSelected ? accent : AppTheme.slate700,
        fontWeight: FontWeight.w600,
        fontSize: 13,
      ),
      onSelected: (selected) =>
          onSelected(selected ? opt.value : null),
    );
  }
}
