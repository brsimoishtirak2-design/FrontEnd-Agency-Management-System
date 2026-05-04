/// Client + branches as needed across the admin Clients tab.
///
/// On /api/admin/clients (list) — no branches; `branches_count` only.
/// On /api/admin/clients/{id} (detail) — branches eager-loaded + creator.
/// On POST/PUT — flat client only (no relations loaded by the backend).
///
/// All write-time fields are nullable so the same model can carry
/// partial form state through to toJsonForCreate / toJsonForUpdate.
class AgencyClient {
  // Identity + core
  final int id;
  final String name;
  final String? companyName;
  final String? industry;
  final String? website;
  final Map<String, dynamic>? socialMedia;
  final String? notes;
  final String? logo;
  final String status; // "active" | "inactive" | "archived"

  // Audit fields (server-set)
  final int? createdBy;
  final String? createdAt;
  final String? updatedAt;

  // Relations / counts (presence depends on endpoint)
  final int? branchesCount; // list endpoint only
  final List<AgencyClientBranch>? branches; // detail endpoint only
  final String? creatorName; // detail endpoint only

  const AgencyClient({
    required this.id,
    required this.name,
    required this.companyName,
    required this.status,
    required this.branches,
    this.industry,
    this.website,
    this.socialMedia,
    this.notes,
    this.logo,
    this.createdBy,
    this.createdAt,
    this.updatedAt,
    this.branchesCount,
    this.creatorName,
  });

  factory AgencyClient.fromJson(Map<String, dynamic> json) {
    final rawBranches = json['branches'] as List?;

    // social_media is stored as a JSON column. Backend returns either
    // null, an empty map, or a populated map. Defensive parse.
    final rawSocial = json['social_media'];
    Map<String, dynamic>? socialMedia;
    if (rawSocial is Map<String, dynamic>) {
      socialMedia = rawSocial;
    } else if (rawSocial is Map) {
      socialMedia = Map<String, dynamic>.from(rawSocial);
    }

    final creator = json['creator'] as Map<String, dynamic>?;

    return AgencyClient(
      id: json['id'] as int,
      name: json['name'] as String,
      companyName: json['company_name'] as String?,
      industry: json['industry'] as String?,
      website: json['website'] as String?,
      socialMedia: socialMedia,
      notes: json['notes'] as String?,
      logo: json['logo'] as String?,
      status: json['status'] as String? ?? 'active',
      createdBy: json['created_by'] as int?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
      branchesCount: json['branches_count'] as int?,
      branches: rawBranches
          ?.map((b) => AgencyClientBranch.fromJson(b as Map<String, dynamic>))
          .toList(),
      creatorName: creator?['name'] as String?,
    );
  }

  /// Serializes writeable fields for POST /api/admin/clients.
  /// Skips id, status (backend defaults to 'active'), timestamps,
  /// branches_count, creator. Skips null/empty values rather than
  /// sending empty strings.
  Map<String, dynamic> toJsonForCreate() {
    final map = <String, dynamic>{'name': name};
    if (companyName != null && companyName!.isNotEmpty) {
      map['company_name'] = companyName;
    }
    if (industry != null && industry!.isNotEmpty) {
      map['industry'] = industry;
    }
    if (website != null && website!.isNotEmpty) {
      map['website'] = website;
    }
    if (socialMedia != null && socialMedia!.isNotEmpty) {
      map['social_media'] = socialMedia;
    }
    if (notes != null && notes!.isNotEmpty) {
      map['notes'] = notes;
    }
    if (logo != null && logo!.isNotEmpty) {
      map['logo'] = logo;
    }
    return map;
  }

  /// Serializes writeable fields for PUT /api/admin/clients/{id}.
  /// All backend rules are 'sometimes' so skip-null is safe. Status
  /// is included (update is the path that lets you change it).
  Map<String, dynamic> toJsonForUpdate() {
    final map = <String, dynamic>{'name': name};
    if (companyName != null) map['company_name'] = companyName;
    if (industry != null) map['industry'] = industry;
    if (website != null) map['website'] = website;
    if (socialMedia != null) map['social_media'] = socialMedia;
    if (notes != null) map['notes'] = notes;
    if (logo != null) map['logo'] = logo;
    map['status'] = status;
    return map;
  }

  bool get isArchived => status == 'archived';
  bool get isActive => status == 'active';

  // --- Curated social channel helpers (return null if unset/empty) ---

  String? get instagramUrl => _socialString('instagram');
  String? get facebookUrl => _socialString('facebook');
  String? get tiktokUrl => _socialString('tiktok');
  String? get websiteFromSocial => _socialString('website');

  String? _socialString(String key) {
    final v = socialMedia?[key];
    if (v is String && v.isNotEmpty) return v;
    return null;
  }
}

/// Branch under a client (e.g., Cafe Aroma — Erbil Main Branch).
class AgencyClientBranch {
  final int id;
  final int clientId;
  final String branchName;
  final int? locationId; // FK; needed to pre-select location dropdown
  final String? locationName; // eager-loaded display name
  final String? address;
  final String? contactPerson;
  final String? contactRole;
  final String? email;
  final String? phone;
  final String? whatsapp;
  final bool isPrimary;
  final String? notes;
  final String? createdAt;
  final String? updatedAt;

  const AgencyClientBranch({
    required this.id,
    required this.clientId,
    required this.branchName,
    required this.locationName,
    required this.isPrimary,
    this.locationId,
    this.address,
    this.contactPerson,
    this.contactRole,
    this.email,
    this.phone,
    this.whatsapp,
    this.notes,
    this.createdAt,
    this.updatedAt,
  });

  factory AgencyClientBranch.fromJson(Map<String, dynamic> json) {
    final loc = json['location'] as Map<String, dynamic>?;
    return AgencyClientBranch(
      id: json['id'] as int,
      clientId: json['client_id'] as int,
      branchName: json['branch_name'] as String,
      locationId: json['location_id'] as int?,
      locationName: loc?['name'] as String?,
      address: json['address'] as String?,
      contactPerson: json['contact_person'] as String?,
      contactRole: json['contact_role'] as String?,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      whatsapp: json['whatsapp'] as String?,
      isPrimary: json['is_primary'] as bool? ?? false,
      notes: json['notes'] as String?,
      createdAt: json['created_at'] as String?,
      updatedAt: json['updated_at'] as String?,
    );
  }

  /// Serializes writeable fields for POST /api/admin/branches.
  /// Includes client_id (required by backend on create only).
  Map<String, dynamic> toJsonForCreate() {
    final map = <String, dynamic>{
      'client_id': clientId,
      'branch_name': branchName,
      'is_primary': isPrimary,
    };
    if (locationId != null) map['location_id'] = locationId;
    if (address != null && address!.isNotEmpty) map['address'] = address;
    if (contactPerson != null && contactPerson!.isNotEmpty) {
      map['contact_person'] = contactPerson;
    }
    if (contactRole != null && contactRole!.isNotEmpty) {
      map['contact_role'] = contactRole;
    }
    if (email != null && email!.isNotEmpty) map['email'] = email;
    if (phone != null && phone!.isNotEmpty) map['phone'] = phone;
    if (whatsapp != null && whatsapp!.isNotEmpty) map['whatsapp'] = whatsapp;
    if (notes != null && notes!.isNotEmpty) map['notes'] = notes;
    return map;
  }

  /// Serializes writeable fields for PUT /api/admin/branches/{id}.
  /// Excludes client_id — backend doesn't allow moving branches between
  /// clients via update.
  Map<String, dynamic> toJsonForUpdate() {
    final map = <String, dynamic>{
      'branch_name': branchName,
      'is_primary': isPrimary,
    };
    if (locationId != null) map['location_id'] = locationId;
    if (address != null) map['address'] = address;
    if (contactPerson != null) map['contact_person'] = contactPerson;
    if (contactRole != null) map['contact_role'] = contactRole;
    if (email != null) map['email'] = email;
    if (phone != null) map['phone'] = phone;
    if (whatsapp != null) map['whatsapp'] = whatsapp;
    if (notes != null) map['notes'] = notes;
    return map;
  }

  /// Display in dropdown: "Erbil Main Branch · Erbil" or "Erbil Main Branch".
  String get displayLabel {
    if (locationName != null && locationName!.isNotEmpty) {
      return '$branchName · $locationName';
    }
    return branchName;
  }
}
