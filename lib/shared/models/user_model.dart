// Simple user model without code generation

class UserModel {
  final String id;
  final String email;
  final String name;
  final String phone;
  final String? profileImageUrl;
  final String? bio;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;
  final List<String> clubIds;
  final Map<String, dynamic> preferences;

  const UserModel({
    required this.id,
    required this.email,
    required this.name,
    required this.phone,
    this.profileImageUrl,
    this.bio,
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
    this.clubIds = const [],
    this.preferences = const {},
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      email: json['email'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      profileImageUrl: json['profileImageUrl'] as String?,
      bio: json['bio'] as String?,
      createdAt: DateTime.parse(json['createdAt'] as String),
      updatedAt: json['updatedAt'] != null 
          ? DateTime.parse(json['updatedAt'] as String)
          : null,
      isActive: json['isActive'] as bool? ?? true,
      clubIds: List<String>.from(json['clubIds'] as List? ?? []),
      preferences: Map<String, dynamic>.from(json['preferences'] as Map? ?? {}),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'email': email,
      'name': name,
      'phone': phone,
      'profileImageUrl': profileImageUrl,
      'bio': bio,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isActive': isActive,
      'clubIds': clubIds,
      'preferences': preferences,
    };
  }

  UserModel copyWith({
    String? id,
    String? email,
    String? name,
    String? phone,
    String? profileImageUrl,
    String? bio,
    DateTime? createdAt,
    DateTime? updatedAt,
    bool? isActive,
    List<String>? clubIds,
    Map<String, dynamic>? preferences,
  }) {
    return UserModel(
      id: id ?? this.id,
      email: email ?? this.email,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
      bio: bio ?? this.bio,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      isActive: isActive ?? this.isActive,
      clubIds: clubIds ?? this.clubIds,
      preferences: preferences ?? this.preferences,
    );
  }
}

class CreateUserRequest {
  final String email;
  final String name;
  final String phone;
  final String? bio;

  const CreateUserRequest({
    required this.email,
    required this.name,
    required this.phone,
    this.bio,
  });

  Map<String, dynamic> toJson() {
    return {
      'email': email,
      'name': name,
      'phone': phone,
      'bio': bio,
    };
  }
}

class VendorUser {
  final String id;
  final String email;
  final String? phone;
  final String? businessName;
  final String? logoUrl;
  final String? stripeAccountId;
  final bool onboardingCompleted;
  final bool twoFaEnabled;
  final DateTime createdAt;
  final DateTime updatedAt;

  // Role: venue_owner, organizer, promoter, staff
  final String role;

  const VendorUser({
    required this.id,
    required this.email,
    this.phone,
    this.businessName,
    this.logoUrl,
    this.stripeAccountId,
    this.onboardingCompleted = false,
    this.twoFaEnabled = false,
    required this.createdAt,
    required this.updatedAt,
    this.role = 'staff',
  });

  factory VendorUser.fromMap(Map<String, dynamic> map) {
    return VendorUser(
      id: map['id'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'],
      businessName: map['business_name'],
      logoUrl: map['logo_url'],
      stripeAccountId: map['stripe_account_id'],
      onboardingCompleted: map['onboarding_completed'] ?? false,
      twoFaEnabled: map['two_fa_enabled'] ?? false,
      createdAt: map['created_at'] != null
          ? DateTime.parse(map['created_at'])
          : DateTime.now(),
      updatedAt: map['updated_at'] != null
          ? DateTime.parse(map['updated_at'])
          : DateTime.now(),
      role: map['role'] ?? 'staff',
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'email': email,
      'phone': phone,
      'business_name': businessName,
      'logo_url': logoUrl,
      'stripe_account_id': stripeAccountId,
      'onboarding_completed': onboardingCompleted,
      'two_fa_enabled': twoFaEnabled,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'role': role,
    };
  }

  VendorUser copyWith({
    String? id,
    String? email,
    String? phone,
    String? businessName,
    String? logoUrl,
    String? stripeAccountId,
    bool? onboardingCompleted,
    bool? twoFaEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? role,
  }) {
    return VendorUser(
      id: id ?? this.id,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      businessName: businessName ?? this.businessName,
      logoUrl: logoUrl ?? this.logoUrl,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      twoFaEnabled: twoFaEnabled ?? this.twoFaEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      role: role ?? this.role,
    );
  }

  bool get isVenueOwner => role == 'venue_owner';
  bool get isOrganizer => role == 'organizer';
  bool get isPromoter => role == 'promoter';
  bool get isStaff => role == 'staff';

  @override
  String toString() {
    return 'VendorUser(id: $id, email: $email, role: $role, onboardingCompleted: $onboardingCompleted)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VendorUser && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
} 