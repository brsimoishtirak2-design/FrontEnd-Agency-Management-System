/// Location reference data. Used both as branch-form dropdown source
/// and as the admin Settings → Locations CRUD entity.
class AgencyLocation {
  final int id;
  final String name;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final int? usersCount;
  final int? departmentsCount;

  const AgencyLocation({
    required this.id,
    required this.name,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.usersCount,
    this.departmentsCount,
  });

  factory AgencyLocation.fromJson(Map<String, dynamic> json) {
    return AgencyLocation(
      id: json['id'] as int,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      usersCount: json['users_count'] as int?,
      departmentsCount: json['departments_count'] as int?,
    );
  }

  /// Serializes writeable fields for POST /api/admin/locations.
  Map<String, dynamic> toJsonForCreate() {
    return <String, dynamic>{
      'name': name,
      'is_active': isActive,
    };
  }

  /// Serializes writeable fields for PUT /api/admin/locations/{id}.
  /// All backend rules are 'sometimes' — same payload as create works.
  Map<String, dynamic> toJsonForUpdate() {
    return <String, dynamic>{
      'name': name,
      'is_active': isActive,
    };
  }

  /// Mirrors the Client API for consistency (archived = inactive).
  bool get isArchived => !isActive;
}
