/// Job title reference data — admin Settings → Job Titles CRUD entity.
class AgencyJobTitle {
  final int id;
  final String name;
  final bool isActive;
  final String? createdAt;
  final String? updatedAt;
  final int? usersCount;

  const AgencyJobTitle({
    required this.id,
    required this.name,
    required this.isActive,
    this.createdAt,
    this.updatedAt,
    this.usersCount,
  });

  factory AgencyJobTitle.fromJson(Map<String, dynamic> json) {
    return AgencyJobTitle(
      id: json['id'] as int,
      name: json['name'] as String,
      isActive: json['is_active'] as bool? ?? true,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      usersCount: json['users_count'] as int?,
    );
  }

  Map<String, dynamic> toJsonForCreate() {
    return <String, dynamic>{
      'name': name,
      'is_active': isActive,
    };
  }

  Map<String, dynamic> toJsonForUpdate() {
    return <String, dynamic>{
      'name': name,
      'is_active': isActive,
    };
  }

  bool get isArchived => !isActive;
}
