import 'package:intl/intl.dart';

/// One scheduled deliverable on the calendar — either a post or a video for
/// a given client on a given date, assigned to a specific employee.
///
/// Backend response shape (from /api/admin/plans/{id} or /api/plans/...):
/// {
///   "id": int,
///   "monthly_plan_id": int,
///   "client_id": int,
///   "slot_date": "YYYY-MM-DD",
///   "slot_type": "post" | "video",
///   "assigned_user_id": int,
///   "is_locked": bool,
///   "source": "auto" | "manual",
///   "task_id": int|null,
///   "materialized_at": string|null,
///   "client":         { "id": int, "name": string, "logo": string|null } | null,
///   "assigned_user":  { "id": int, "name": string, "profile_photo": string|null } | null,
///   "task":           { "id": int, "status": string, "deadline_date": string, "completed_at": string|null } | null,
/// }
class PlannerSlot {
  final int id;
  final int monthlyPlanId;
  final int clientId;
  final DateTime slotDate;
  final String slotType; // 'post' | 'video'
  final int assignedUserId;
  final bool isLocked;
  final String source; // 'auto' | 'manual'
  final int? taskId;
  final String? materializedAt;

  // Eager-loaded snippets
  final String? clientName;
  final String? clientLogo;
  final String? assignedUserName;
  final String? assignedUserPhoto;

  // Task snapshot (only present once materialized)
  final String? taskStatus;
  final String? taskCompletedAt;

  const PlannerSlot({
    required this.id,
    required this.monthlyPlanId,
    required this.clientId,
    required this.slotDate,
    required this.slotType,
    required this.assignedUserId,
    required this.isLocked,
    required this.source,
    this.taskId,
    this.materializedAt,
    this.clientName,
    this.clientLogo,
    this.assignedUserName,
    this.assignedUserPhoto,
    this.taskStatus,
    this.taskCompletedAt,
  });

  factory PlannerSlot.fromJson(Map<String, dynamic> json) {
    final client = json['client'] as Map<String, dynamic>?;
    final user = json['assigned_user'] as Map<String, dynamic>?;
    final task = json['task'] as Map<String, dynamic>?;

    return PlannerSlot(
      id: json['id'] as int,
      monthlyPlanId: json['monthly_plan_id'] as int,
      clientId: json['client_id'] as int,
      slotDate: DateTime.parse(json['slot_date'] as String),
      slotType: json['slot_type'] as String,
      assignedUserId: json['assigned_user_id'] as int,
      isLocked: json['is_locked'] as bool? ?? false,
      source: json['source'] as String? ?? 'auto',
      taskId: json['task_id'] as int?,
      materializedAt: json['materialized_at'] as String?,
      clientName: client?['name'] as String?,
      clientLogo: client?['logo'] as String?,
      assignedUserName: user?['name'] as String?,
      assignedUserPhoto: user?['profile_photo'] as String?,
      taskStatus: task?['status'] as String?,
      taskCompletedAt: task?['completed_at'] as String?,
    );
  }

  bool get isPost => slotType == 'post';
  bool get isVideo => slotType == 'video';
  bool get isMaterialized => taskId != null;
  bool get isCompleted => taskStatus == 'approved' || taskCompletedAt != null;
  bool get isCancelled => taskStatus == 'cancelled';

  /// Date as 'YYYY-MM-DD' for sending back to the API.
  String get slotDateString => DateFormat('yyyy-MM-dd').format(slotDate);
}
