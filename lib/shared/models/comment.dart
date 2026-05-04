/// Comment on a task. Hand-written (no codegen).
///
/// Backend response shape (canonical, from list endpoint):
/// {
///   "id": int,
///   "task_id": int,
///   "user_id": int,
///   "body": string,
///   "is_internal": bool,
///   "edited_at": string|null,
///   "deleted_at": string|null,
///   "created_at": string,
///   "updated_at": string,
///   "user": { "id": int, "name": string, "profile_photo": string|null }
/// }
///
/// The create response uses {"data": {...}} wrapper and omits edited_at /
/// deleted_at — Dart returns null for missing keys, so the parser handles
/// both shapes identically.
class Comment {
  final int id;
  final int taskId;
  final int userId;
  final String body;
  final bool isInternal;
  final String? editedAt;
  final String? deletedAt;
  final String createdAt;
  final String updatedAt;

  // --- Eager-loaded user relation ---
  final String userName;
  final String? userProfilePhoto;

  const Comment({
    required this.id,
    required this.taskId,
    required this.userId,
    required this.body,
    required this.isInternal,
    this.editedAt,
    this.deletedAt,
    required this.createdAt,
    required this.updatedAt,
    required this.userName,
    this.userProfilePhoto,
  });

  factory Comment.fromJson(Map<String, dynamic> json) {
    final user = json['user'] as Map<String, dynamic>?;

    return Comment(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      userId: json['user_id'] as int,
      body: json['body'] as String,
      isInternal: json['is_internal'] as bool? ?? false,
      editedAt: json['edited_at'] as String?,
      deletedAt: json['deleted_at'] as String?,
      createdAt: json['created_at'] as String,
      updatedAt: json['updated_at'] as String,
      userName: user?['name'] as String? ?? 'Unknown',
      userProfilePhoto: user?['profile_photo'] as String?,
    );
  }

  /// True if this comment was edited after creation.
  bool get isEdited => editedAt != null;

  /// True if this comment is soft-deleted on the backend (we generally won't
  /// see these in employee listings, but kept for completeness).
  bool get isDeleted => deletedAt != null;

  /// True if the given user authored this comment.
  bool isAuthor(int? userId) => userId != null && this.userId == userId;
}
