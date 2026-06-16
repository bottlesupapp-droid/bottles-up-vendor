// Venue (Club) model matching Supabase clubs table

enum VenueStatus {
  pending,
  approved,
  active,
  suspended,
}

class Venue {
  final String id;
  final String ownerId;
  final String name;
  final Map<String, dynamic>? address; // {street, city, state, zip, country}
  final List<String> licenseDocuments;
  final List<String> gallery;
  final Map<String, dynamic>? floorplanData;
  final int? capacity;
  final VenueStatus status;
  final Map<String, dynamic>? socialLinks; // {venue_type, min_age, music_genres, amenities, ...}
  final String? description;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Extracted address fields for convenience
  String? get city => address?['city'] as String?;
  String? get fullAddress {
    if (address == null) return null;
    final parts = <String>[];
    if (address!['street'] != null) parts.add(address!['street']);
    if (address!['city'] != null) parts.add(address!['city']);
    if (address!['state'] != null) parts.add(address!['state']);
    return parts.join(', ');
  }

  const Venue({
    required this.id,
    required this.ownerId,
    required this.name,
    this.address,
    this.licenseDocuments = const [],
    this.gallery = const [],
    this.floorplanData,
    this.capacity,
    this.status = VenueStatus.pending,
    this.socialLinks,
    this.description,
    this.phone,
    this.email,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Venue.fromJson(Map<String, dynamic> json) {
    // Handle potential null values and provide defaults
    final id = json['id']?.toString() ?? '';
    final ownerId = json['owner_id']?.toString() ?? '';
    final name = json['name']?.toString() ?? 'Unnamed Venue';

    // Parse timestamps with fallback
    DateTime parseTimestamp(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.parse(value);
      if (value is DateTime) return value;
      return DateTime.now();
    }

    return Venue(
      id: id,
      ownerId: ownerId,
      name: name,
      address: json['address'] as Map<String, dynamic>?,
      licenseDocuments: json['license_documents'] != null
          ? List<String>.from(json['license_documents'])
          : [],
      gallery: json['gallery'] != null
          ? List<String>.from(json['gallery'])
          : [],
      floorplanData: json['floorplan_data'] as Map<String, dynamic>?,
      capacity: json['capacity'] as int?,
      status: _parseStatus(json['status'] as String?),
      socialLinks: json['social_links'] as Map<String, dynamic>?,
      description: json['description'] as String?,
      phone: (json['phone'] ?? json['contact_number']) as String?,
      email: json['email'] as String?,
      createdAt: parseTimestamp(json['created_at']),
      updatedAt: parseTimestamp(json['updated_at']),
    );
  }

  static VenueStatus _parseStatus(String? status) {
    if (status == null) return VenueStatus.pending;
    try {
      return VenueStatus.values.firstWhere((e) => e.name == status);
    } catch (_) {
      return VenueStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'owner_id': ownerId,
      'name': name,
      'address': address,
      'license_documents': licenseDocuments,
      'gallery': gallery,
      'floorplan_data': floorplanData,
      'capacity': capacity,
      'status': status.name,
      'social_links': socialLinks,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  Venue copyWith({
    String? id,
    String? ownerId,
    String? name,
    Map<String, dynamic>? address,
    List<String>? licenseDocuments,
    List<String>? gallery,
    Map<String, dynamic>? floorplanData,
    int? capacity,
    VenueStatus? status,
    Map<String, dynamic>? socialLinks,
    String? description,
    String? phone,
    String? email,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return Venue(
      id: id ?? this.id,
      ownerId: ownerId ?? this.ownerId,
      name: name ?? this.name,
      address: address ?? this.address,
      licenseDocuments: licenseDocuments ?? this.licenseDocuments,
      gallery: gallery ?? this.gallery,
      floorplanData: floorplanData ?? this.floorplanData,
      capacity: capacity ?? this.capacity,
      status: status ?? this.status,
      socialLinks: socialLinks ?? this.socialLinks,
      description: description ?? this.description,
      phone: phone ?? this.phone,
      email: email ?? this.email,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get isPending => status == VenueStatus.pending;
  bool get isApproved => status == VenueStatus.approved;
  bool get isActive => status == VenueStatus.active;
  bool get isSuspended => status == VenueStatus.suspended;

  @override
  String toString() {
    return 'Venue(id: $id, name: $name, status: ${status.name})';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Venue && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}
