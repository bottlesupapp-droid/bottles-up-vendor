// Simple club model without code generation

class ClubModel {
  final String id;
  final String name;
  final String description;
  final String organizerId;
  final String? logoUrl;
  final String? bannerUrl;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String? website;
  final String? phone;
  final String? email;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final List<String> eventIds;
  final int totalEvents;
  final int totalAttendees;
  final Map<String, dynamic> socialLinks;

  const ClubModel({
    required this.id,
    required this.name,
    required this.description,
    required this.organizerId,
    this.logoUrl,
    this.bannerUrl,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    this.website,
    this.phone,
    this.email,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.eventIds = const [],
    this.totalEvents = 0,
    this.totalAttendees = 0,
    this.socialLinks = const {},
  });

  factory ClubModel.fromJson(Map<String, dynamic> json) {
    return ClubModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      organizerId: json['organizerId'] as String,
      logoUrl: json['logoUrl'] as String?,
      bannerUrl: json['bannerUrl'] as String?,
      address: json['address'] as String,
      city: json['city'] as String,
      state: json['state'] as String,
      zipCode: json['zipCode'] as String,
      website: json['website'] as String?,
      phone: json['phone'] as String?,
      email: json['email'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      eventIds: List<String>.from(json['eventIds'] as List? ?? []),
      totalEvents: json['totalEvents'] as int? ?? 0,
      totalAttendees: json['totalAttendees'] as int? ?? 0,
      socialLinks: Map<String, dynamic>.from(json['socialLinks'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'organizerId': organizerId,
      'logoUrl': logoUrl,
      'bannerUrl': bannerUrl,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'website': website,
      'phone': phone,
      'email': email,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'eventIds': eventIds,
      'totalEvents': totalEvents,
      'totalAttendees': totalAttendees,
      'socialLinks': socialLinks,
    };
  }
}

class CreateClubRequest {
  final String name;
  final String description;
  final String address;
  final String city;
  final String state;
  final String zipCode;
  final String? website;
  final String? phone;
  final String? email;

  const CreateClubRequest({
    required this.name,
    required this.description,
    required this.address,
    required this.city,
    required this.state,
    required this.zipCode,
    this.website,
    this.phone,
    this.email,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'website': website,
      'phone': phone,
      'email': email,
    };
  }
} 