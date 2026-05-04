import '../utils/initials.dart';

/// User model — matches the backend's User payload shape.
///
/// Hand-written (no freezed) due to build_runner/path_provider AOT collision in
/// late-2025 Flutter. Convert to freezed once build_runner 3.x lands with
/// dart build support.
class User {
  final int id;
  final String name;
  final String email;
  final String? phone;
  final String role;
  final bool isActive;
  final bool mustChangePassword;
  final String? profilePhoto;
  final int? locationId;
  final int? departmentId;
  final int? jobTitleId;
  final String? lastLoginAt;

  // Eager-loaded relation names from /login + /me (null on endpoints
  // that don't load them).
  final String? locationName;
  final String? departmentName;
  final String? jobTitleName;

  const User({
    required this.id,
    required this.name,
    required this.email,
    this.phone,
    required this.role,
    required this.isActive,
    required this.mustChangePassword,
    this.profilePhoto,
    this.locationId,
    this.departmentId,
    this.jobTitleId,
    this.lastLoginAt,
    this.locationName,
    this.departmentName,
    this.jobTitleName,
  });

  factory User.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>?;
    final dept = json['department'] as Map<String, dynamic>?;
    final job = json['job_title'] as Map<String, dynamic>?;

    return User(
      id: json['id'] as int,
      name: json['name'] as String,
      email: json['email'] as String,
      phone: json['phone'] as String?,
      role: json['role'] as String,
      isActive: json['is_active'] as bool,
      mustChangePassword: json['must_change_password'] as bool,
      profilePhoto: json['profile_photo'] as String?,
      locationId: json['location_id'] as int?,
      departmentId: json['department_id'] as int?,
      jobTitleId: json['job_title_id'] as int?,
      lastLoginAt: json['last_login_at'] as String?,
      locationName: loc?['name'] as String?,
      departmentName: dept?['name'] as String?,
      jobTitleName: job?['name'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'phone': phone,
        'role': role,
        'is_active': isActive,
        'must_change_password': mustChangePassword,
        'profile_photo': profilePhoto,
        'location_id': locationId,
        'department_id': departmentId,
        'job_title_id': jobTitleId,
        'last_login_at': lastLoginAt,
        'location_name': locationName,
        'department_name': departmentName,
        'job_title_name': jobTitleName,
      };

  /// Returns a copy with optional field overrides.
  User copyWith({
    int? id,
    String? name,
    String? email,
    String? phone,
    String? role,
    bool? isActive,
    bool? mustChangePassword,
    String? profilePhoto,
    int? locationId,
    int? departmentId,
    int? jobTitleId,
    String? lastLoginAt,
    String? locationName,
    String? departmentName,
    String? jobTitleName,
  }) {
    return User(
      id: id ?? this.id,
      name: name ?? this.name,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      role: role ?? this.role,
      isActive: isActive ?? this.isActive,
      mustChangePassword: mustChangePassword ?? this.mustChangePassword,
      profilePhoto: profilePhoto ?? this.profilePhoto,
      locationId: locationId ?? this.locationId,
      departmentId: departmentId ?? this.departmentId,
      jobTitleId: jobTitleId ?? this.jobTitleId,
      lastLoginAt: lastLoginAt ?? this.lastLoginAt,
      locationName: locationName ?? this.locationName,
      departmentName: departmentName ?? this.departmentName,
      jobTitleName: jobTitleName ?? this.jobTitleName,
    );
  }

  @override
  String toString() =>
      'User(id: $id, name: $name, email: $email, role: $role, isActive: $isActive)';
}

/// Convenience extension for role checks + display helpers.
extension UserRoleX on User {
  bool get isAdmin => role == 'admin';
  bool get isEmployee => role == 'employee';

  /// Initials for avatar fallback. 2 letters when possible.
  String get initials => nameInitials(name);
}
