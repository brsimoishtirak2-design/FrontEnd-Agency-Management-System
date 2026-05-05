/// One row from the notifications inbox. Hand-written model.
///
/// Backend canonical shape (GET /api/notifications):
/// {
///   "id": int,
///   "user_id": int,
///   "type": string,           // see ApiNotificationType for the set
///   "title": string,
///   "body": string,
///   "task_id": int|null,
///   "comment_id": int|null,
///   "is_read": bool,
///   "read_at": string|null,
///   "sent_via_push": bool,
///   "created_at": string,
///   "task": { "id": int, "title": string, "status": string } | null
/// }
class AppNotification {
  final int id;
  final String type;
  final String title;
  final String body;
  final int? taskId;
  final int? commentId;
  final bool isRead;
  final String? readAt;
  final String createdAt;

  // Eager-loaded task summary (may be null when the task was deleted)
  final String? taskTitle;
  final String? taskStatus;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.taskId,
    required this.commentId,
    required this.isRead,
    required this.readAt,
    required this.createdAt,
    required this.taskTitle,
    required this.taskStatus,
  });

  factory AppNotification.fromJson(Map<String, dynamic> json) {
    final task = json['task'] as Map<String, dynamic>?;
    return AppNotification(
      id: json['id'] as int,
      type: json['type'] as String,
      title: json['title'] as String,
      body: json['body'] as String,
      taskId: json['task_id'] as int?,
      commentId: json['comment_id'] as int?,
      isRead: (json['is_read'] as bool?) ?? false,
      readAt: json['read_at'] as String?,
      createdAt: json['created_at'] as String,
      taskTitle: task?['title'] as String?,
      taskStatus: task?['status'] as String?,
    );
  }

  AppNotification copyWith({bool? isRead, String? readAt}) =>
      AppNotification(
        id: id,
        type: type,
        title: title,
        body: body,
        taskId: taskId,
        commentId: commentId,
        isRead: isRead ?? this.isRead,
        readAt: readAt ?? this.readAt,
        createdAt: createdAt,
        taskTitle: taskTitle,
        taskStatus: taskStatus,
      );

  /// True for chat-style notifications that should land in /tasks/{id}/comments
  /// rather than the task detail.
  bool get opensComments => type == 'comment_posted';
}
