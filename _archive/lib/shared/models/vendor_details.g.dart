// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'vendor_details.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

VendorDetails _$VendorDetailsFromJson(Map<String, dynamic> json) =>
    VendorDetails(
      id: json['id'] as String?,
      vendorId: json['vendor_id'] as String,
      businessName: json['business_name'] as String,
      businessType: json['business_type'] as String?,
      businessDescription: json['business_description'] as String?,
      contactPerson: json['contact_person'] as String?,
      phoneNumber: json['phone_number'] as String?,
      email: json['email'] as String?,
      addressLine1: json['address_line_1'] as String?,
      addressLine2: json['address_line_2'] as String?,
      city: json['city'] as String?,
      state: json['state'] as String?,
      postalCode: json['postal_code'] as String?,
      country: json['country'] as String?,
      bankName: json['bank_name'] as String?,
      accountHolderName: json['account_holder_name'] as String?,
      accountNumber: json['account_number'] as String?,
      ifscCode: json['ifsc_code'] as String?,
      branchName: json['branch_name'] as String?,
      gstNumber: json['gst_number'] as String?,
      panNumber: json['pan_number'] as String?,
      businessLicenseNumber: json['business_license_number'] as String?,
      websiteUrl: json['website_url'] as String?,
      instagramHandle: json['instagram_handle'] as String?,
      facebookPage: json['facebook_page'] as String?,
      isVerified: json['is_verified'] as bool? ?? false,
      verificationStatus: json['verification_status'] as String? ?? 'pending',
      verificationNotes: json['verification_notes'] as String?,
      createdAt: json['created_at'] == null
          ? null
          : DateTime.parse(json['created_at'] as String),
      updatedAt: json['updated_at'] == null
          ? null
          : DateTime.parse(json['updated_at'] as String),
    );

Map<String, dynamic> _$VendorDetailsToJson(VendorDetails instance) =>
    <String, dynamic>{
      'id': instance.id,
      'vendor_id': instance.vendorId,
      'business_name': instance.businessName,
      'business_type': instance.businessType,
      'business_description': instance.businessDescription,
      'contact_person': instance.contactPerson,
      'phone_number': instance.phoneNumber,
      'email': instance.email,
      'address_line_1': instance.addressLine1,
      'address_line_2': instance.addressLine2,
      'city': instance.city,
      'state': instance.state,
      'postal_code': instance.postalCode,
      'country': instance.country,
      'bank_name': instance.bankName,
      'account_holder_name': instance.accountHolderName,
      'account_number': instance.accountNumber,
      'ifsc_code': instance.ifscCode,
      'branch_name': instance.branchName,
      'gst_number': instance.gstNumber,
      'pan_number': instance.panNumber,
      'business_license_number': instance.businessLicenseNumber,
      'website_url': instance.websiteUrl,
      'instagram_handle': instance.instagramHandle,
      'facebook_page': instance.facebookPage,
      'is_verified': instance.isVerified,
      'verification_status': instance.verificationStatus,
      'verification_notes': instance.verificationNotes,
      'created_at': instance.createdAt?.toIso8601String(),
      'updated_at': instance.updatedAt?.toIso8601String(),
    };
