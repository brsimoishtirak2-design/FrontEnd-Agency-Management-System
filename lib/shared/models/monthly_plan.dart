import 'package:intl/intl.dart';

import 'monthly_plan_client.dart';
import 'planner_slot.dart';

/// A monthly content plan: identifies a (year, month), the per-client
/// commitments for that month, and every scheduled slot.
///
/// Backend response (from /api/admin/plans/{id} or /api/plans/{year}/{month}):
/// {
///   "id": int,
///   "year": int,
///   "month": int,
///   "status": "draft" | "confirmed",
///   "created_by": int|null,
///   "confirmed_at": string|null,
///   "last_confirmed_at": string|null,
///   "creator": { "id": int, "name": string } | null,
///   "plan_clients": [ MonthlyPlanClient, ... ],
///   "slots": [ PlannerSlot, ... ],
/// }
class MonthlyPlan {
  final int id;
  final int year;
  final int month;
  final String status; // 'draft' | 'confirmed'
  final int? createdBy;
  final String? confirmedAt;
  final String? lastConfirmedAt;
  final String? creatorName;

  final List<MonthlyPlanClient> planClients;
  final List<PlannerSlot> slots;

  const MonthlyPlan({
    required this.id,
    required this.year,
    required this.month,
    required this.status,
    required this.planClients,
    required this.slots,
    this.createdBy,
    this.confirmedAt,
    this.lastConfirmedAt,
    this.creatorName,
  });

  factory MonthlyPlan.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    final rawPlanClients = json['plan_clients'] as List? ?? const [];
    final rawSlots = json['slots'] as List? ?? const [];

    return MonthlyPlan(
      id: json['id'] as int,
      year: json['year'] as int,
      month: json['month'] as int,
      status: json['status'] as String? ?? 'draft',
      createdBy: json['created_by'] as int?,
      confirmedAt: json['confirmed_at'] as String?,
      lastConfirmedAt: json['last_confirmed_at'] as String?,
      creatorName: creator?['name'] as String?,
      planClients: rawPlanClients
          .map((c) => MonthlyPlanClient.fromJson(c as Map<String, dynamic>))
          .toList(),
      slots: rawSlots
          .map((s) => PlannerSlot.fromJson(s as Map<String, dynamic>))
          .toList(),
    );
  }

  bool get isDraft => status == 'draft';
  bool get isConfirmed => status == 'confirmed';

  /// "May 2026"
  String get displayMonthYear =>
      DateFormat('MMMM yyyy').format(DateTime(year, month, 1));

  /// "May" — for compact headers when the year is shown elsewhere.
  String get displayMonth =>
      DateFormat('MMMM').format(DateTime(year, month, 1));

  int get totalCommitments =>
      planClients.fold<int>(0, (sum, c) => sum + c.totalCount);

  int get totalPlacedSlots => slots.length;

  int get totalMaterialized =>
      slots.where((s) => s.isMaterialized).length;
}
