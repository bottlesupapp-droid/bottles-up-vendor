import 'package:json_annotation/json_annotation.dart';

part 'vendor_details.g.dart';

@JsonSerializable()
class VendorDetails {
  final String? id;
  final String vendorId;
  final String businessName;
  final String? businessType;
  final String? businessDescription;
  final String? contactPerson;
  final String? phoneNumber;
  final String? email;
  final String? addressLine1;
  final String? addressLine2;
  final String? city;
  final String? state;
  final String? postalCode;
  final String? country;
  final String? bankName;
  final String? accountHolderName;
  final String? accountNumber;
  final String? ifscCode;
  final String? branchName;
  final String? gstNumber;
  final String? panNumber;
  final String? businessLicenseNumber;
  final String? websiteUrl;
  final String? instagramHandle;
  final String? facebookPage;
  final bool isVerified;
  final String verificationStatus;
  final String? verificationNotes;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  VendorDetails({
    this.id,
    required this.vendorId,
    required this.businessName,
    this.businessType,
    this.businessDescription,
    this.contactPerson,
    this.phoneNumber,
    this.email,
    this.addressLine1,
    this.addressLine2,
    this.city,
    this.state,
    this.postalCode,
    this.country,
    this.bankName,
    this.accountHolderName,
    this.accountNumber,
    this.ifscCode,
    this.branchName,
    this.gstNumber,
    this.panNumber,
    this.businessLicenseNumber,
    this.websiteUrl,
    this.instagramHandle,
    this.facebookPage,
    this.isVerified = false,
    this.verificationStatus = 'pending',
    this.verificationNotes,
    this.createdAt,
    this.updatedAt,
  });

  factory VendorDetails.fromJson(Map<String, dynamic> json) =>
      _$VendorDetailsFromJson(json);

  Map<String, dynamic> toJson() => _$VendorDetailsToJson(this);

  VendorDetails copyWith({
    String? id,
    String? vendorId,
    String? businessName,
    String? businessType,
    String? businessDescription,
    String? contactPerson,
    String? phoneNumber,
    String? email,
    String? addressLine1,
    String? addressLine2,
    String? city,
    String? state,
    String? postalCode,
    String? country,
    String? bankName,
    String? accountHolderName,
    String? accountNumber,
    String? ifscCode,
    String? branchName,
    String? gstNumber,
    String? panNumber,
    String? businessLicenseNumber,
    String? websiteUrl,
    String? instagramHandle,
    String? facebookPage,
    bool? isVerified,
    String? verificationStatus,
    String? verificationNotes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorDetails(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      businessName: businessName ?? this.businessName,
      businessType: businessType ?? this.businessType,
      businessDescription: businessDescription ?? this.businessDescription,
      contactPerson: contactPerson ?? this.contactPerson,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
      city: city ?? this.city,
      state: state ?? this.state,
      postalCode: postalCode ?? this.postalCode,
      country: country ?? this.country,
      bankName: bankName ?? this.bankName,
      accountHolderName: accountHolderName ?? this.accountHolderName,
      accountNumber: accountNumber ?? this.accountNumber,
      ifscCode: ifscCode ?? this.ifscCode,
      branchName: branchName ?? this.branchName,
      gstNumber: gstNumber ?? this.gstNumber,
      panNumber: panNumber ?? this.panNumber,
      businessLicenseNumber: businessLicenseNumber ?? this.businessLicenseNumber,
      websiteUrl: websiteUrl ?? this.websiteUrl,
      instagramHandle: instagramHandle ?? this.instagramHandle,
      facebookPage: facebookPage ?? this.facebookPage,
      isVerified: isVerified ?? this.isVerified,
      verificationStatus: verificationStatus ?? this.verificationStatus,
      verificationNotes: verificationNotes ?? this.verificationNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'VendorDetails(id: $id, vendorId: $vendorId, businessName: $businessName, businessType: $businessType, businessDescription: $businessDescription, contactPerson: $contactPerson, phoneNumber: $phoneNumber, email: $email, addressLine1: $addressLine1, addressLine2: $addressLine2, city: $city, state: $state, postalCode: $postalCode, country: $country, bankName: $bankName, accountHolderName: $accountHolderName, accountNumber: $accountNumber, ifscCode: $ifscCode, branchName: $branchName, gstNumber: $gstNumber, panNumber: $panNumber, businessLicenseNumber: $businessLicenseNumber, websiteUrl: $websiteUrl, instagramHandle: $instagramHandle, facebookPage: $facebookPage, isVerified: $isVerified, verificationStatus: $verificationStatus, verificationNotes: $verificationNotes, createdAt: $createdAt, updatedAt: $updatedAt)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VendorDetails &&
        other.id == id &&
        other.vendorId == vendorId &&
        other.businessName == businessName &&
        other.businessType == businessType &&
        other.businessDescription == businessDescription &&
        other.contactPerson == contactPerson &&
        other.phoneNumber == phoneNumber &&
        other.email == email &&
        other.addressLine1 == addressLine1 &&
        other.addressLine2 == addressLine2 &&
        other.city == city &&
        other.state == state &&
        other.postalCode == postalCode &&
        other.country == country &&
        other.bankName == bankName &&
        other.accountHolderName == accountHolderName &&
        other.accountNumber == accountNumber &&
        other.ifscCode == ifscCode &&
        other.branchName == branchName &&
        other.gstNumber == gstNumber &&
        other.panNumber == panNumber &&
        other.businessLicenseNumber == businessLicenseNumber &&
        other.websiteUrl == websiteUrl &&
        other.instagramHandle == instagramHandle &&
        other.facebookPage == facebookPage &&
        other.isVerified == isVerified &&
        other.verificationStatus == verificationStatus &&
        other.verificationNotes == verificationNotes &&
        other.createdAt == createdAt &&
        other.updatedAt == updatedAt;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        vendorId.hashCode ^
        businessName.hashCode ^
        businessType.hashCode ^
        businessDescription.hashCode ^
        contactPerson.hashCode ^
        phoneNumber.hashCode ^
        email.hashCode ^
        addressLine1.hashCode ^
        addressLine2.hashCode ^
        city.hashCode ^
        state.hashCode ^
        postalCode.hashCode ^
        country.hashCode ^
        bankName.hashCode ^
        accountHolderName.hashCode ^
        accountNumber.hashCode ^
        ifscCode.hashCode ^
        branchName.hashCode ^
        gstNumber.hashCode ^
        panNumber.hashCode ^
        businessLicenseNumber.hashCode ^
        websiteUrl.hashCode ^
        instagramHandle.hashCode ^
        facebookPage.hashCode ^
        isVerified.hashCode ^
        verificationStatus.hashCode ^
        verificationNotes.hashCode ^
        createdAt.hashCode ^
        updatedAt.hashCode;
  }
}
