/// Attachment on a task (or task comment). Hand-written model.
///
/// Backend canonical shape:
/// {
///   "id": int,
///   "task_id": int,
///   "uploaded_by": int,
///   "purpose": "brief" | "submission" | "comment",
///   "file_name": string,
///   "file_path": string (server-side, not used by mobile),
///   "file_size": int (bytes),
///   "mime_type": string,
///   "comment_id": int|null,
///   "created_at": string,
///   "updated_at": string,
///   "download_url": string (absolute URL — use directly, no need to build),
///   "uploader": { "id": int, "name": string },
///   "comment": null | object  (present on list, absent on create)
/// }
class Attachment {
  final int id;
  final int taskId;
  final int uploadedBy;
  final String purpose; // "brief" | "submission" | "comment"
  final String fileName;
  final int fileSize; // bytes
  final String mimeType;
  final int? commentId;
  final String createdAt;
  final String downloadUrl;

  // Eager-loaded uploader
  final String uploaderName;

  const Attachment({
    required this.id,
    required this.taskId,
    required this.uploadedBy,
    required this.purpose,
    required this.fileName,
    required this.fileSize,
    required this.mimeType,
    required this.commentId,
    required this.createdAt,
    required this.downloadUrl,
    required this.uploaderName,
  });

  factory Attachment.fromJson(Map<String, dynamic> json) {
    final uploader = json['uploader'] as Map<String, dynamic>?;
    return Attachment(
      id: json['id'] as int,
      taskId: json['task_id'] as int,
      uploadedBy: json['uploaded_by'] as int,
      purpose: json['purpose'] as String,
      fileName: json['file_name'] as String,
      fileSize: json['file_size'] as int,
      mimeType: json['mime_type'] as String,
      commentId: json['comment_id'] as int?,
      createdAt: json['created_at'] as String,
      downloadUrl: json['download_url'] as String,
      uploaderName: uploader?['name'] as String? ?? 'Unknown',
    );
  }

  // --- Convenience getters ---

  bool get isBrief => purpose == 'brief';
  bool get isSubmission => purpose == 'submission';
  bool get isCommentAttachment => purpose == 'comment';

  /// True if this is an image type our app can preview directly.
  bool get isImage =>
      mimeType.startsWith('image/') ||
      ['jpg', 'jpeg', 'png', 'webp'].contains(_ext);

  bool get isPdf => mimeType == 'application/pdf' || _ext == 'pdf';

  bool get isVideo =>
      mimeType.startsWith('video/') || ['mp4', 'mov'].contains(_ext);

  String get _ext {
    final dot = fileName.lastIndexOf('.');
    if (dot < 0 || dot == fileName.length - 1) return '';
    return fileName.substring(dot + 1).toLowerCase();
  }

  /// Human-readable file size: "12 KB", "3.4 MB", etc.
  String get displaySize {
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    if (fileSize < 1024 * 1024 * 1024) {
      return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(fileSize / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  /// Material icon to render for this file type.
  /// (We import the IconData on the UI side — this returns a string key.)
  String get iconKey {
    if (isImage) return 'image';
    if (isPdf) return 'pdf';
    if (isVideo) return 'video';
    if (['xlsx', 'xls', 'csv'].contains(_ext)) return 'spreadsheet';
    if (['docx', 'doc'].contains(_ext)) return 'document';
    if (['zip', 'rar', '7z'].contains(_ext)) return 'archive';
    return 'file';
  }
}
