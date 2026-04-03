class Club {
  final String id;
  final String name;
  final String location;
  final String? description;
  final double? priceMin;
  final double? priceMax;
  final double? avgRating;
  final int? reviewCount;
  final String? imageUrl;
  final String? phone;
  final String? email;
  final String? websiteUrl;
  final Map<String, dynamic>? openingHours;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;
  final String? categoryId;
  final String? dressCode;
  final String? ageRequirement;

  Club({
    required this.id,
    required this.name,
    required this.location,
    this.description,
    this.priceMin,
    this.priceMax,
    this.avgRating,
    this.reviewCount,
    this.imageUrl,
    this.phone,
    this.email,
    this.websiteUrl,
    this.openingHours,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
    this.categoryId,
    this.dressCode,
    this.ageRequirement,
  });

  factory Club.fromJson(Map<String, dynamic> json) {
    return Club(
      id: json['id'],
      name: json['name'],
      location: json['location'],
      description: json['description'],
      priceMin: json['price_min']?.toDouble(),
      priceMax: json['price_max']?.toDouble(),
      avgRating: json['avg_rating']?.toDouble(),
      reviewCount: json['review_count'],
      imageUrl: json['image_url'],
      phone: json['phone'],
      email: json['email'],
      websiteUrl: json['website_url'],
      openingHours: json['opening_hours'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      categoryId: json['category_id'],
      dressCode: json['dress_code'],
      ageRequirement: json['age_requirement'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'location': location,
      'description': description,
      'price_min': priceMin,
      'price_max': priceMax,
      'avg_rating': avgRating,
      'review_count': reviewCount,
      'image_url': imageUrl,
      'phone': phone,
      'email': email,
      'website_url': websiteUrl,
      'opening_hours': openingHours,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'category_id': categoryId,
      'dress_code': dressCode,
      'age_requirement': ageRequirement,
    };
  }
}

class CreateClubRequest {
  final String name;
  final String location;
  final String? description;
  final double? priceMin;
  final double? priceMax;
  final String? imageUrl;
  final String? phone;
  final String? email;
  final String? websiteUrl;
  final Map<String, dynamic>? openingHours;
  final String? categoryId;
  final String? dressCode;
  final String? ageRequirement;

  CreateClubRequest({
    required this.name,
    required this.location,
    this.description,
    this.priceMin,
    this.priceMax,
    this.imageUrl,
    this.phone,
    this.email,
    this.websiteUrl,
    this.openingHours,
    this.categoryId,
    this.dressCode,
    this.ageRequirement,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'location': location,
      'description': description,
      'price_min': priceMin,
      'price_max': priceMax,
      'image_url': imageUrl,
      'phone': phone,
      'email': email,
      'website_url': websiteUrl,
      'opening_hours': openingHours,
      'category_id': categoryId,
      'dress_code': dressCode,
      'age_requirement': ageRequirement,
    };
  }
}

class UpdateClubRequest {
  final String? name;
  final String? location;
  final String? description;
  final double? priceMin;
  final double? priceMax;
  final String? imageUrl;
  final String? phone;
  final String? email;
  final String? websiteUrl;
  final Map<String, dynamic>? openingHours;
  final bool? isActive;
  final String? categoryId;
  final String? dressCode;
  final String? ageRequirement;

  UpdateClubRequest({
    this.name,
    this.location,
    this.description,
    this.priceMin,
    this.priceMax,
    this.imageUrl,
    this.phone,
    this.email,
    this.websiteUrl,
    this.openingHours,
    this.isActive,
    this.categoryId,
    this.dressCode,
    this.ageRequirement,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (name != null) json['name'] = name;
    if (location != null) json['location'] = location;
    if (description != null) json['description'] = description;
    if (priceMin != null) json['price_min'] = priceMin;
    if (priceMax != null) json['price_max'] = priceMax;
    if (imageUrl != null) json['image_url'] = imageUrl;
    if (phone != null) json['phone'] = phone;
    if (email != null) json['email'] = email;
    if (websiteUrl != null) json['website_url'] = websiteUrl;
    if (openingHours != null) json['opening_hours'] = openingHours;
    if (isActive != null) json['is_active'] = isActive;
    if (categoryId != null) json['category_id'] = categoryId;
    if (dressCode != null) json['dress_code'] = dressCode;
    if (ageRequirement != null) json['age_requirement'] = ageRequirement;
    return json;
  }
}
