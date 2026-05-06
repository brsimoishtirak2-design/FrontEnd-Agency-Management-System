import '../../../core/api/api_client.dart';
import '../../../core/api/api_exception.dart';
import '../../../shared/models/monthly_plan.dart';
import '../../../shared/models/monthly_plan_client.dart';
import '../../../shared/models/planner_slot.dart';

/// Repository for the Content Planner module.
///
/// Admin endpoints (POST/PATCH/DELETE) require admin role; the read endpoints
/// (currentPlan, planForMonth) are accessible to any authed user.
class PlannerRepository {
  final ApiClient _api;

  PlannerRepository(this._api);

  // -------- Read (any authed user) --------

  /// GET /api/plans/current
  Future<MonthlyPlan?> currentPlan() async {
    final response =
        await _api.get<Map<String, dynamic>>('/plans/current');
    return _planOrNull(response.data);
  }

  /// GET /api/plans/{year}/{month}
  Future<MonthlyPlan?> planForMonth(int year, int month) async {
    final response =
        await _api.get<Map<String, dynamic>>('/plans/$year/$month');
    return _planOrNull(response.data);
  }

  // -------- Admin: plan CRUD --------

  /// GET /api/admin/plans (paginated)
  Future<List<MonthlyPlanSummary>> listPlans() async {
    final response = await _api.get<Map<String, dynamic>>('/admin/plans');
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final raw = (body['data'] ?? const <dynamic>[]) as List;
    return raw
        .map((p) => MonthlyPlanSummary.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  /// POST /api/admin/plans
  Future<MonthlyPlan> createPlan({required int year, required int month}) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/plans',
      data: {'year': year, 'month': month},
    );
    return _planFromBody(response.data);
  }

  /// GET /api/admin/plans/{id}
  Future<MonthlyPlan> getPlan(int id) async {
    final response =
        await _api.get<Map<String, dynamic>>('/admin/plans/$id');
    return _planFromBody(response.data);
  }

  /// DELETE /api/admin/plans/{id}
  Future<void> deletePlan(int id) async {
    await _api.delete<Map<String, dynamic>>('/admin/plans/$id');
  }

  /// POST /api/admin/plans/{id}/generate
  Future<PlannerGenerateResult> generate(int planId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/plans/$planId/generate',
    );
    return _generateResultFromBody(response.data);
  }

  /// POST /api/admin/plans/{id}/rebalance — alias of generate.
  Future<PlannerGenerateResult> rebalance(int planId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/plans/$planId/rebalance',
    );
    return _generateResultFromBody(response.data);
  }

  /// POST /api/admin/plans/{id}/confirm
  Future<PlannerConfirmResult> confirm(int planId) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/plans/$planId/confirm',
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    return PlannerConfirmResult(
      plan: _planFromBody(body),
      isFirstConfirm: body['first_confirm'] as bool? ?? false,
      newTaskCount: body['new_tasks'] as int? ?? 0,
      changedSlotCount: body['changed_slots'] as int? ?? 0,
    );
  }

  // -------- Admin: per-client commitments --------

  /// POST /api/admin/plans/{id}/clients
  Future<MonthlyPlanClient> upsertPlanClient({
    required int planId,
    required int clientId,
    required int postsCount,
    required int videosCount,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/plans/$planId/clients',
      data: {
        'client_id': clientId,
        'posts_count': postsCount,
        'videos_count': videosCount,
      },
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final inner = (body['data'] ?? body) as Map<String, dynamic>;
    return MonthlyPlanClient.fromJson(inner);
  }

  /// DELETE /api/admin/plans/{planId}/clients/{clientId}
  Future<void> removePlanClient({
    required int planId,
    required int clientId,
  }) async {
    await _api.delete<Map<String, dynamic>>(
      '/admin/plans/$planId/clients/$clientId',
    );
  }

  // -------- Admin: manual slot manipulation --------

  /// POST /api/admin/plans/{id}/slots
  Future<PlannerSlot> createSlot({
    required int planId,
    required int clientId,
    required String slotDate, // 'YYYY-MM-DD'
    required String slotType, // 'post' | 'video'
    required int assignedUserId,
  }) async {
    final response = await _api.post<Map<String, dynamic>>(
      '/admin/plans/$planId/slots',
      data: {
        'client_id': clientId,
        'slot_date': slotDate,
        'slot_type': slotType,
        'assigned_user_id': assignedUserId,
      },
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final inner = (body['data'] ?? body) as Map<String, dynamic>;
    return PlannerSlot.fromJson(inner);
  }

  /// PATCH /api/admin/plans/{planId}/slots/{slotId}
  Future<PlannerSlot> updateSlot({
    required int planId,
    required int slotId,
    String? slotDate,
    String? slotType,
    int? assignedUserId,
    bool? isLocked,
  }) async {
    final data = <String, dynamic>{};
    if (slotDate != null) data['slot_date'] = slotDate;
    if (slotType != null) data['slot_type'] = slotType;
    if (assignedUserId != null) data['assigned_user_id'] = assignedUserId;
    if (isLocked != null) data['is_locked'] = isLocked;

    final response = await _api.raw.patch<Map<String, dynamic>>(
      '/admin/plans/$planId/slots/$slotId',
      data: data,
    );
    final body = response.data;
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final inner = (body['data'] ?? body) as Map<String, dynamic>;
    return PlannerSlot.fromJson(inner);
  }

  /// DELETE /api/admin/plans/{planId}/slots/{slotId}
  Future<void> deleteSlot({
    required int planId,
    required int slotId,
  }) async {
    await _api.delete<Map<String, dynamic>>(
      '/admin/plans/$planId/slots/$slotId',
    );
  }

  // -------- Helpers --------

  MonthlyPlan? _planOrNull(Map<String, dynamic>? body) {
    if (body == null) return null;
    final inner = body['data'];
    if (inner == null) return null;
    return MonthlyPlan.fromJson(inner as Map<String, dynamic>);
  }

  MonthlyPlan _planFromBody(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final inner = (body['data'] ?? body) as Map<String, dynamic>;
    return MonthlyPlan.fromJson(inner);
  }

  PlannerGenerateResult _generateResultFromBody(Map<String, dynamic>? body) {
    if (body == null) {
      throw const ApiException(message: 'Empty response from server.');
    }
    final plan = _planFromBody(body);
    final result = body['result'] as Map<String, dynamic>?;
    return PlannerGenerateResult(
      plan: plan,
      success: result?['success'] as bool? ?? true,
      placed: result?['placed'] as int? ?? 0,
      conflicts: ((result?['conflicts'] as List?) ?? const [])
          .map((e) => e.toString())
          .toList(),
    );
  }
}

/// Lightweight summary returned by GET /admin/plans (no slots).
class MonthlyPlanSummary {
  final int id;
  final int year;
  final int month;
  final String status;
  final int planClientsCount;
  final int slotsCount;
  final String? creatorName;

  const MonthlyPlanSummary({
    required this.id,
    required this.year,
    required this.month,
    required this.status,
    required this.planClientsCount,
    required this.slotsCount,
    this.creatorName,
  });

  factory MonthlyPlanSummary.fromJson(Map<String, dynamic> json) {
    final creator = json['creator'] as Map<String, dynamic>?;
    return MonthlyPlanSummary(
      id: json['id'] as int,
      year: json['year'] as int,
      month: json['month'] as int,
      status: json['status'] as String? ?? 'draft',
      planClientsCount: json['plan_clients_count'] as int? ?? 0,
      slotsCount: json['slots_count'] as int? ?? 0,
      creatorName: creator?['name'] as String?,
    );
  }
}

class PlannerGenerateResult {
  final MonthlyPlan plan;
  final bool success;
  final int placed;
  final List<String> conflicts;

  const PlannerGenerateResult({
    required this.plan,
    required this.success,
    required this.placed,
    required this.conflicts,
  });
}

class PlannerConfirmResult {
  final MonthlyPlan plan;
  final bool isFirstConfirm;
  final int newTaskCount;
  final int changedSlotCount;

  const PlannerConfirmResult({
    required this.plan,
    required this.isFirstConfirm,
    required this.newTaskCount,
    required this.changedSlotCount,
  });
}
