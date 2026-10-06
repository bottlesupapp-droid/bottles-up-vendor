// Onboarding Profiles Models
// Models for organizer, promoter, and staff profile data

// ============================================================================
// ORGANIZER PROFILE
// ============================================================================

class OrganizerProfileModel {
  final String id;
  final String vendorId;

  // Organization info
  final String organizationName;
  final String? description;

  // Social links
  final String instagramHandle;
  final String? facebookPage;
  final String? twitterHandle;
  final String? websiteUrl;

  final DateTime createdAt;
  final DateTime updatedAt;

  const OrganizerProfileModel({
    required this.id,
    required this.vendorId,
    required this.organizationName,
    this.description,
    required this.instagramHandle,
    this.facebookPage,
    this.twitterHandle,
    this.websiteUrl,
    required this.createdAt,
    required this.updatedAt,
  });

  factory OrganizerProfileModel.fromMap(Map<String, dynamic> map) {
    return OrganizerProfileModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      organizationName: map['organization_name'] ?? '',
      description: map['description'],
      instagramHandle: map['instagram_handle'] ?? '',
      facebookPage: map['facebook_page'],
      twitterHandle: map['twitter_handle'],
      websiteUrl: map['website_url'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'organization_name': organizationName,
      'description': description,
      'instagram_handle': instagramHandle,
      'facebook_page': facebookPage,
      'twitter_handle': twitterHandle,
      'website_url': websiteUrl,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  OrganizerProfileModel copyWith({
    String? id,
    String? vendorId,
    String? organizationName,
    String? description,
    String? instagramHandle,
    String? facebookPage,
    String? twitterHandle,
    String? websiteUrl,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return OrganizerProfileModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      organizationName: organizationName ?? this.organizationName,
      description: description ?? this.description,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      facebookPage: facebookPage ?? this.facebookPage,
      twitterHandle: twitterHandle ?? this.twitterHandle,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// ============================================================================
// PROMOTER PROFILE
// ============================================================================

class PromoterProfileModel {
  final String id;
  final String vendorId;

  // Basic info
  final String? phoneNumber;
  final String? profilePhotoUrl;
  final String? profilePhotoPath;

  // Promo code info
  final String? promoCode; // Null until assigned by organizer
  final int totalSales;
  final double totalCommission;

  // Bank details for payout
  final String? bankAccountHolder;
  final String? bankAccountNumber;
  final String? bankIfscCode;
  final String? bankName;

  final DateTime createdAt;
  final DateTime updatedAt;

  const PromoterProfileModel({
    required this.id,
    required this.vendorId,
    this.phoneNumber,
    this.profilePhotoUrl,
    this.profilePhotoPath,
    this.promoCode,
    this.totalSales = 0,
    this.totalCommission = 0.0,
    this.bankAccountHolder,
    this.bankAccountNumber,
    this.bankIfscCode,
    this.bankName,
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromoterProfileModel.fromMap(Map<String, dynamic> map) {
    return PromoterProfileModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      phoneNumber: map['phone_number'],
      profilePhotoUrl: map['profile_photo_url'],
      profilePhotoPath: map['profile_photo_path'],
      promoCode: map['promo_code'],
      totalSales: map['total_sales'] ?? 0,
      totalCommission: (map['total_commission'] ?? 0).toDouble(),
      bankAccountHolder: map['bank_account_holder'],
      bankAccountNumber: map['bank_account_number'],
      bankIfscCode: map['bank_ifsc_code'],
      bankName: map['bank_name'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'phone_number': phoneNumber,
      'profile_photo_url': profilePhotoUrl,
      'profile_photo_path': profilePhotoPath,
      'promo_code': promoCode,
      'total_sales': totalSales,
      'total_commission': totalCommission,
      'bank_account_holder': bankAccountHolder,
      'bank_account_number': bankAccountNumber,
      'bank_ifsc_code': bankIfscCode,
      'bank_name': bankName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  PromoterProfileModel copyWith({
    String? id,
    String? vendorId,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? profilePhotoPath,
    String? promoCode,
    int? totalSales,
    double? totalCommission,
    String? bankAccountHolder,
    String? bankAccountNumber,
    String? bankIfscCode,
    String? bankName,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return PromoterProfileModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      promoCode: promoCode ?? this.promoCode,
      totalSales: totalSales ?? this.totalSales,
      totalCommission: totalCommission ?? this.totalCommission,
      bankAccountHolder: bankAccountHolder ?? this.bankAccountHolder,
      bankAccountNumber: bankAccountNumber ?? this.bankAccountNumber,
      bankIfscCode: bankIfscCode ?? this.bankIfscCode,
      bankName: bankName ?? this.bankName,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasPromoCode => promoCode != null && promoCode!.isNotEmpty;
}

// ============================================================================
// STAFF PROFILE
// ============================================================================

class StaffProfileModel {
  final String id;
  final String vendorId;

  // Basic info
  final String? phoneNumber;
  final String? profilePhotoUrl;
  final String? profilePhotoPath;

  // Roles - at least one required
  final List<String> roles; // door, bottle_service, bartender, server, security, manager

  // ID document
  final String? idDocumentUrl;
  final String? idDocumentPath;
  final String? idDocumentType; // aadhaar, passport, driving_license
  final String? idDocumentNumber;

  // Employment status
  final bool isAvailable;
  final String? currentVenueId;

  final DateTime createdAt;
  final DateTime updatedAt;

  const StaffProfileModel({
    required this.id,
    required this.vendorId,
    this.phoneNumber,
    this.profilePhotoUrl,
    this.profilePhotoPath,
    required this.roles,
    this.idDocumentUrl,
    this.idDocumentPath,
    this.idDocumentType,
    this.idDocumentNumber,
    this.isAvailable = true,
    this.currentVenueId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StaffProfileModel.fromMap(Map<String, dynamic> map) {
    return StaffProfileModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      phoneNumber: map['phone_number'],
      profilePhotoUrl: map['profile_photo_url'],
      profilePhotoPath: map['profile_photo_path'],
      roles: List<String>.from(map['roles'] ?? []),
      idDocumentUrl: map['id_document_url'],
      idDocumentPath: map['id_document_path'],
      idDocumentType: map['id_document_type'],
      idDocumentNumber: map['id_document_number'],
      isAvailable: map['is_available'] ?? true,
      currentVenueId: map['current_venue_id'],
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'phone_number': phoneNumber,
      'profile_photo_url': profilePhotoUrl,
      'profile_photo_path': profilePhotoPath,
      'roles': roles,
      'id_document_url': idDocumentUrl,
      'id_document_path': idDocumentPath,
      'id_document_type': idDocumentType,
      'id_document_number': idDocumentNumber,
      'is_available': isAvailable,
      'current_venue_id': currentVenueId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  StaffProfileModel copyWith({
    String? id,
    String? vendorId,
    String? phoneNumber,
    String? profilePhotoUrl,
    String? profilePhotoPath,
    List<String>? roles,
    String? idDocumentUrl,
    String? idDocumentPath,
    String? idDocumentType,
    String? idDocumentNumber,
    bool? isAvailable,
    String? currentVenueId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StaffProfileModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      profilePhotoUrl: profilePhotoUrl ?? this.profilePhotoUrl,
      profilePhotoPath: profilePhotoPath ?? this.profilePhotoPath,
      roles: roles ?? this.roles,
      idDocumentUrl: idDocumentUrl ?? this.idDocumentUrl,
      idDocumentPath: idDocumentPath ?? this.idDocumentPath,
      idDocumentType: idDocumentType ?? this.idDocumentType,
      idDocumentNumber: idDocumentNumber ?? this.idDocumentNumber,
      isAvailable: isAvailable ?? this.isAvailable,
      currentVenueId: currentVenueId ?? this.currentVenueId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  bool get hasIdDocument => idDocumentUrl != null && idDocumentUrl!.isNotEmpty;
}

// ============================================================================
// PROMOTER EVENT ASSIGNMENT (for tracking which events promoters are promoting)
// ============================================================================

class PromoterEventAssignmentModel {
  final String id;
  final String promoterId;
  final String eventId;
  final String organizerId;

  final String promoCode;
  final double commissionPercentage;
  final int ticketsSold;
  final double commissionEarned;

  final String status; // active, inactive, completed

  final DateTime createdAt;
  final DateTime updatedAt;

  const PromoterEventAssignmentModel({
    required this.id,
    required this.promoterId,
    required this.eventId,
    required this.organizerId,
    required this.promoCode,
    required this.commissionPercentage,
    this.ticketsSold = 0,
    this.commissionEarned = 0.0,
    this.status = 'active',
    required this.createdAt,
    required this.updatedAt,
  });

  factory PromoterEventAssignmentModel.fromMap(Map<String, dynamic> map) {
    return PromoterEventAssignmentModel(
      id: map['id'] ?? '',
      promoterId: map['promoter_id'] ?? '',
      eventId: map['event_id'] ?? '',
      organizerId: map['organizer_id'] ?? '',
      promoCode: map['promo_code'] ?? '',
      commissionPercentage: (map['commission_percentage'] ?? 0).toDouble(),
      ticketsSold: map['tickets_sold'] ?? 0,
      commissionEarned: (map['commission_earned'] ?? 0).toDouble(),
      status: map['status'] ?? 'active',
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'promoter_id': promoterId,
      'event_id': eventId,
      'organizer_id': organizerId,
      'promo_code': promoCode,
      'commission_percentage': commissionPercentage,
      'tickets_sold': ticketsSold,
      'commission_earned': commissionEarned,
      'status': status,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
