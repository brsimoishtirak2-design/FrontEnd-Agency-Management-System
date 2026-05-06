import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_theme.dart';
import '../../../../shared/models/monthly_plan.dart';
import '../../data/planner_providers.dart';

/// Horizontal chip row at the top of the planner: "All" + one chip per client
/// in the plan. Tapping a chip filters the calendar to just that client.
class ClientFilterStrip extends ConsumerWidget {
  final MonthlyPlan plan;

  const ClientFilterStrip({super.key, required this.plan});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedId = ref.watch(plannerClientFilterProvider);

    return SizedBox(
      height: 44,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        children: [
          _Chip(
            label: 'All clients',
            selected: selectedId == null,
            onTap: () => ref.read(plannerClientFilterProvider.notifier).state = null,
          ),
          ...plan.planClients.map((c) {
            return Padding(
              padding: const EdgeInsets.only(left: 6),
              child: _Chip(
                label: c.clientName ?? 'Client #${c.clientId}',
                selected: selectedId == c.clientId,
                onTap: () => ref.read(plannerClientFilterProvider.notifier).state =
                    c.clientId,
                trailing: '${c.totalCount}',
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  final String? trailing;

  const _Chip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: selected ? AppTheme.brandPrimary : Colors.white,
            border: Border.all(
              color: selected ? AppTheme.brandPrimary : AppTheme.slate200,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : AppTheme.slate800,
                ),
              ),
              if (trailing != null) ...[
                const SizedBox(width: 6),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                  decoration: BoxDecoration(
                    color: selected
                        ? Colors.white.withValues(alpha: 0.25)
                        : AppTheme.slate100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: selected ? Colors.white : AppTheme.slate700,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
