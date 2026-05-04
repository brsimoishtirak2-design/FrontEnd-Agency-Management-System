/// One assignment row linking a user to a task.
///
/// Note: `assignedBy` polymorphism — on list endpoints the backend returns
/// just an int user_id, while on detail endpoints it eager-loads the user
/// as {id, name}. This model handles both cases.
class TaskAssignment {
  final int id;
  final int taskId;
  final int userId;
  final String userName; // from eager-loaded `user` relation
  final String? userProfilePhoto;
  final bool isLeader;
  final int assignedById;
  final String? assignedByName; // only present on detail endpoint
  final String? assignedAt;
  final String? startedAt;
  final String? submittedAt;
  final bool isActive;
  final String? removedAt;
  final String? removedReason;

  const TaskAssignment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.userName,
    this.userProfilePhoto,
    required this.isLeader,
    required this.assignedById,
    this.assignedByName,
    this.assignedAt,
    this.startedAt,
    this.submittedAt,
    required this.isActive,
    this.removedAt,
    this.removedReason,
  });

  factory TaskAssignment.fromJson(Map<String, dynamic> json) {
    // assigned_by is polymorphic: int on list, object on detail
    final rawAssignedBy = json['assigned_by'];
    final int assignedById;
    final String? assignedByName;
    if (rawAssignedBy is int) {
      assignedById = rawAssignedBy;
      assignedByName = null;
    } else if (rawAssignedBy is Map<String, dynamic>) {
      assignedById = rawAssignedBy['id'] as int;
      assignedByName = rawAssignedBy['name'] as String?;
    } else {
      assignedById = 0;
      assignedByName = null;
    }

    final user = json['user'] as Map<String, dynamic>?;

    return TaskAssignment(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      userId: json['user_id'] as int,
      userName: user?['name'] as String? ?? '',
      userProfilePhoto: user?['profile_photo'] as String?,
      isLeader: json['is_leader'] as bool? ?? false,
      assignedById: assignedById,
      assignedByName: assignedByName,
      assignedAt: json['assigned_at'] as String?,
      startedAt: json['started_at'] as String?,
      submittedAt: json['submitted_at'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      removedAt: json['removed_at'] as String?,
      removedReason: json['removed_reason'] as String?,
    );
  }
}
