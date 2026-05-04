/// Department reference data — admin Settings → Departments CRUD entity.
///
/// Compound uniqueness: (name, location_id) must be unique together.
class AgencyDepartment {
  final int id;
  final String name;
  final int locationId;
  final String? locationName; // eager-loaded
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final int? usersCount;

  const AgencyDepartment({
    required this.id,
    required this.name,
    required this.locationId,
    required this.locationName,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.usersCount,
  });

  factory AgencyDepartment.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>?;
    return AgencyDepartment(
      id: json['id'] as int,
      name: json['name'] as String,
      locationId: json['location_id'] as int,
      locationName: loc?['name'] as String?,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      usersCount: json['users_count'] as int?,
    );
  }

  Map<String, dynamic> toJsonForCreate() {
    return <String, dynamic>{
      'name': name,
      'location_id': locationId,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return <String, dynamic>{
      'name': name,
      'location_id': locationId,
      'is_active': isActive,
    };
  }

  bool get isArchived => !isActive;

  String get displayLabel => '$name · ${locationName ?? '—'}';
}
