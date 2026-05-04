import '../utils/initials.dart';

/// User as seen by admin features (assignee picker, employee management).
///
/// Backend response shape (from /api/admin/users):
/// {
///   "id": int,
///   "name": string,
///   "email": string,
///   "email_verified_at": string|null,
///   "phone": string|null,
///   "role": "admin" | "employee",
///   "location_id": int|null,
///   "department_id": int|null,
///   "job_title_id": int|null,
///   "is_active": bool,
///   "must_change_password": bool,
///   "profile_photo": string|null,
///   "last_login_at": string|null,
///   "created_by": int|null,
///   "created_at": string,
///   "updated_at": string,
///   "location":   { "id": int, "name": string } | null,
///   "department": { "id": int, "name": string } | null,
///   "job_title":  { "id": int, "name": string } | null,
///   "creator":    { "id": int, "name": string } | null   (detail only)
/// }
///
/// Lighter-weight than the auth-side `User` model — purpose-built for
/// admin lists where we want to display "Sara · Designer · Erbil" style.
class AgencyUser {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;
  final String? profilePhoto;

  // Eager-loaded relations (any may be null if user has no assignment)
  final String? locationName;
  final String? departmentName;
  final String? jobTitleName;

  // FK ids — needed for the form's dropdown pre-select
  final int? locationId;
  final int? departmentId;
  final int? jobTitleId;

  // Audit / state fields
  final bool mustChangePassword;
  final String? lastLoginAt;
  final int? createdBy;
  final String? createdAt;
  final String? updatedAt;
  final String? emailVerifiedAt;

  // Detail-only relation
  final String? creatorName;

  const AgencyUser({
    required this.id,
    required this.name,
    required this.email,
    required this.phone,
    required this.role,
    required this.isActive,
    required this.profilePhoto,
    required this.locationName,
    required this.departmentName,
    required this.jobTitleName,
    this.locationId,
    this.departmentId,
    this.jobTitleId,
    this.mustChangePassword = false,
    this.lastLoginAt,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.emailVerifiedAt,
    this.creatorName,
  });

  factory AgencyUser.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>?;
    final dept = json['department'] as Map<String, dynamic>?;
    final job = json['job_title'] as Map<String, dynamic>?;
    final creator = json['creator'] as Map<String, dynamic>?;

    return AgencyUser(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String? ?? 'employee',
      isActive: json['is_active'] as bool? ?? true,
      profilePhoto: json['profile_photo'] as String?,
      locationName: loc?['name'] as String?,
      departmentName: dept?['name'] as String?,
      jobTitleName: job?['name'] as String?,
      locationId: json['location_id'] as int?,
      departmentId: json['department_id'] as int?,
      jobTitleId: json['job_title_id'] as int?,
      mustChangePassword: json['must_change_password'] as bool? ?? false,
      lastLoginAt: json['last_login_at'] as String?,
      createdBy: json['created_by'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      emailVerifiedAt: json['email_verified_at'] as String?,
      creatorName: creator?['name'] as String?,
    );
  }

  /// Serializes writeable fields for POST /api/admin/users.
  /// Caller supplies `password` separately (the model never carries it).
  /// `must_change_password` is intentionally omitted — backend defaults
  /// to true so newly-created users are forced to change at first login.
  Map<String, dynamic> toJsonForCreate({required String password}) {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'password': password,
      'role': role,
      'is_active': isActive,
    };
    if (phone != null && phone!.isNotEmpty) map['phone'] = phone;
    if (locationId != null) map['location_id'] = locationId;
    if (departmentId != null) map['department_id'] = departmentId;
    if (jobTitleId != null) map['job_title_id'] = jobTitleId;
    return map;
  }

  /// Serializes writeable fields for PUT /api/admin/users/{id}.
  /// Excludes password (use the dedicated reset endpoint instead).
  /// All backend rules are 'sometimes' — skip-null is safe.
  Map<String, dynamic> toJsonForUpdate() {
    final map = <String, dynamic>{
      'name': name,
      'email': email,
      'role': role,
      'is_active': isActive,
    };
    if (phone != null) map['phone'] = phone;
    if (locationId != null) map['location_id'] = locationId;
    if (departmentId != null) map['department_id'] = departmentId;
    if (jobTitleId != null) map['job_title_id'] = jobTitleId;
    return map;
  }

  /// Friendly subtitle for the assignee picker:
  /// "Designer · Erbil" or "Designer" or "" depending on what's loaded.
  String get subtitle {
    final parts = <String>[
      if (jobTitleName != null && jobTitleName!.isNotEmpty) jobTitleName!,
      if (locationName != null && locationName!.isNotEmpty) locationName!,
    ];
    return parts.join(' · ');
  }

  /// Initials for avatar fallback.
  String get initials => nameInitials(name);

  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';
}
