// Venue Details Model - For venue owner onboarding data
// Corresponds to venue_details table in Supabase

class VenueDetailsModel {
  final String id;
  final String vendorId;

  // Basic venue information
  final String venueName;
  final String addressLine1;
  final String? addressLine2;
  final String city;
  final String state;
  final String zipCode;
  final int capacity;
  final String? description;

  final DateTime createdAt;
  final DateTime updatedAt;

  const VenueDetailsModel({
    required this.id,
    required this.vendorId,
    required this.venueName,
    required this.addressLine1,
    this.addressLine2,
    required this.city,
    required this.state,
    required this.zipCode,
    required this.capacity,
    this.description,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VenueDetailsModel.fromMap(Map<String, dynamic> map) {
    return VenueDetailsModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      venueName: map['venue_name'] ?? '',
      addressLine1: map['address_line1'] ?? '',
      addressLine2: map['address_line2'],
      city: map['city'] ?? '',
      state: map['state'] ?? '',
      zipCode: map['zip_code'] ?? '',
      capacity: map['capacity'] ?? 0,
      description: map['description'],
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
      'venue_name': venueName,
      'address_line1': addressLine1,
      'address_line2': addressLine2,
      'city': city,
      'state': state,
      'zip_code': zipCode,
      'capacity': capacity,
      'description': description,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  VenueDetailsModel copyWith({
    String? id,
    String? vendorId,
    String? venueName,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? zipCode,
    int? capacity,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VenueDetailsModel(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      venueName: venueName ?? this.venueName,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      zipCode: zipCode ?? this.zipCode,
      capacity: capacity ?? this.capacity,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Venue Gallery Image Model
class VenueGalleryModel {
  final String id;
  final String vendorId;
  final String venueId;
  final String imageUrl;
  final String storagePath;
  final int displayOrder;
  final bool isPrimary;
  final DateTime createdAt;

  const VenueGalleryModel({
    required this.id,
    required this.vendorId,
    required this.venueId,
    required this.imageUrl,
    required this.storagePath,
    this.displayOrder = 0,
    this.isPrimary = false,
    required this.createdAt,
  });

  factory VenueGalleryModel.fromMap(Map<String, dynamic> map) {
    return VenueGalleryModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      venueId: map['venue_id'] ?? '',
      imageUrl: map['image_url'] ?? '',
      storagePath: map['storage_path'] ?? '',
      displayOrder: map['display_order'] ?? 0,
      isPrimary: map['is_primary'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'venue_id': venueId,
      'image_url': imageUrl,
      'storage_path': storagePath,
      'display_order': displayOrder,
      'is_primary': isPrimary,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Venue Document Model
class VenueDocumentModel {
  final String id;
  final String vendorId;
  final String venueId;
  final String documentType; // bar_license, fssai, gst, fire_noc, shop_act
  final String documentUrl;
  final String storagePath;
  final String? documentNumber;
  final DateTime? issueDate;
  final DateTime? expiryDate;
  final DateTime createdAt;

  const VenueDocumentModel({
    required this.id,
    required this.vendorId,
    required this.venueId,
    required this.documentType,
    required this.documentUrl,
    required this.storagePath,
    this.documentNumber,
    this.issueDate,
    this.expiryDate,
    required this.createdAt,
  });

  factory VenueDocumentModel.fromMap(Map<String, dynamic> map) {
    return VenueDocumentModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      venueId: map['venue_id'] ?? '',
      documentType: map['document_type'] ?? '',
      documentUrl: map['document_url'] ?? '',
      storagePath: map['storage_path'] ?? '',
      documentNumber: map['document_number'],
      issueDate: map['issue_date'] != null ? DateTime.parse(map['issue_date']) : null,
      expiryDate: map['expiry_date'] != null ? DateTime.parse(map['expiry_date']) : null,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'venue_id': venueId,
      'document_type': documentType,
      'document_url': documentUrl,
      'storage_path': storagePath,
      'document_number': documentNumber,
      'issue_date': issueDate?.toIso8601String().split('T')[0],
      'expiry_date': expiryDate?.toIso8601String().split('T')[0],
      'created_at': createdAt.toIso8601String(),
    };
  }
}

// Venue Zone Model
class VenueZoneModel {
  final String id;
  final String vendorId;
  final String venueId;
  final String zoneName;
  final String? zoneType;
  final int? capacity;
  final String? description;
  final int displayOrder;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VenueZoneModel({
    required this.id,
    required this.vendorId,
    required this.venueId,
    required this.zoneName,
    this.zoneType,
    this.capacity,
    this.description,
    this.displayOrder = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VenueZoneModel.fromMap(Map<String, dynamic> map) {
    return VenueZoneModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      venueId: map['venue_id'] ?? '',
      zoneName: map['zone_name'] ?? '',
      zoneType: map['zone_type'],
      capacity: map['capacity'],
      description: map['description'],
      displayOrder: map['display_order'] ?? 0,
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
      'venue_id': venueId,
      'zone_name': zoneName,
      'zone_type': zoneType,
      'capacity': capacity,
      'description': description,
      'display_order': displayOrder,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

// Venue Bottle Menu Model
class VenueBottleMenuModel {
  final String id;
  final String vendorId;
  final String venueId;
  final String bottleName;
  final String? brand;
  final String? category;
  final String? size;
  final double price;
  final String? description;
  final bool isAvailable;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VenueBottleMenuModel({
    required this.id,
    required this.vendorId,
    required this.venueId,
    required this.bottleName,
    this.brand,
    this.category,
    this.size,
    required this.price,
    this.description,
    this.isAvailable = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VenueBottleMenuModel.fromMap(Map<String, dynamic> map) {
    return VenueBottleMenuModel(
      id: map['id'] ?? '',
      vendorId: map['vendor_id'] ?? '',
      venueId: map['venue_id'] ?? '',
      bottleName: map['bottle_name'] ?? '',
      brand: map['brand'],
      category: map['category'],
      size: map['size'],
      price: (map['price'] ?? 0).toDouble(),
      description: map['description'],
      isAvailable: map['is_available'] ?? true,
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
      'venue_id': venueId,
      'bottle_name': bottleName,
      'brand': brand,
      'category': category,
      'size': size,
      'price': price,
      'description': description,
      'is_available': isAvailable,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}
