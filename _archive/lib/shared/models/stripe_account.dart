enum StripeAccountStatus {
  pending,
  restricted,
  enabled,
  disabled,
}

enum PayoutSchedule {
  daily,
  weekly,
  monthly,
  manual,
}

class StripeAccount {
  final String id;
  final String vendorId;
  final String? stripeAccountId;
  final StripeAccountStatus status;
  final bool chargesEnabled;
  final bool payoutsEnabled;
  final bool detailsSubmitted;
  final List<String> requirementsCurrentlyDue;
  final List<String> requirementsEventuallyDue;
  final List<String> requirementsPastDue;
  final String? accountType; // standard, express, custom
  final String? country;
  final String? currency;
  final String? email;
  final String? businessName;
  final String? businessUrl;
  final PayoutSchedule payoutSchedule;
  final int? payoutDelayDays;
  final DateTime? onboardingCompletedAt;
  final DateTime? lastPayoutAt;
  final double totalPayouts;
  final double pendingBalance;
  final double availableBalance;
  final DateTime createdAt;
  final DateTime updatedAt;

  const StripeAccount({
    required this.id,
    required this.vendorId,
    this.stripeAccountId,
    required this.status,
    this.chargesEnabled = false,
    this.payoutsEnabled = false,
    this.detailsSubmitted = false,
    this.requirementsCurrentlyDue = const [],
    this.requirementsEventuallyDue = const [],
    this.requirementsPastDue = const [],
    this.accountType,
    this.country,
    this.currency,
    this.email,
    this.businessName,
    this.businessUrl,
    this.payoutSchedule = PayoutSchedule.weekly,
    this.payoutDelayDays,
    this.onboardingCompletedAt,
    this.lastPayoutAt,
    this.totalPayouts = 0,
    this.pendingBalance = 0,
    this.availableBalance = 0,
    required this.createdAt,
    required this.updatedAt,
  });

  factory StripeAccount.fromJson(Map<String, dynamic> json) {
    return StripeAccount(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      stripeAccountId: json['stripe_account_id'] as String?,
      status: _parseStatus(json['status'] as String),
      chargesEnabled: json['charges_enabled'] as bool? ?? false,
      payoutsEnabled: json['payouts_enabled'] as bool? ?? false,
      detailsSubmitted: json['details_submitted'] as bool? ?? false,
      requirementsCurrentlyDue: json['requirements_currently_due'] != null
          ? List<String>.from(json['requirements_currently_due'])
          : [],
      requirementsEventuallyDue: json['requirements_eventually_due'] != null
          ? List<String>.from(json['requirements_eventually_due'])
          : [],
      requirementsPastDue: json['requirements_past_due'] != null
          ? List<String>.from(json['requirements_past_due'])
          : [],
      accountType: json['account_type'] as String?,
      country: json['country'] as String?,
      currency: json['currency'] as String?,
      email: json['email'] as String?,
      businessName: json['business_name'] as String?,
      businessUrl: json['business_url'] as String?,
      payoutSchedule: _parsePayoutSchedule(json['payout_schedule'] as String?),
      payoutDelayDays: json['payout_delay_days'] as int?,
      onboardingCompletedAt: json['onboarding_completed_at'] != null
          ? DateTime.parse(json['onboarding_completed_at'] as String)
          : null,
      lastPayoutAt: json['last_payout_at'] != null
          ? DateTime.parse(json['last_payout_at'] as String)
          : null,
      totalPayouts: (json['total_payouts'] as num?)?.toDouble() ?? 0,
      pendingBalance: (json['pending_balance'] as num?)?.toDouble() ?? 0,
      availableBalance: (json['available_balance'] as num?)?.toDouble() ?? 0,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static StripeAccountStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'pending':
        return StripeAccountStatus.pending;
      case 'restricted':
        return StripeAccountStatus.restricted;
      case 'enabled':
        return StripeAccountStatus.enabled;
      case 'disabled':
        return StripeAccountStatus.disabled;
      default:
        return StripeAccountStatus.pending;
    }
  }

  static PayoutSchedule _parsePayoutSchedule(String? schedule) {
    if (schedule == null) return PayoutSchedule.weekly;
    switch (schedule.toLowerCase()) {
      case 'daily':
        return PayoutSchedule.daily;
      case 'weekly':
        return PayoutSchedule.weekly;
      case 'monthly':
        return PayoutSchedule.monthly;
      case 'manual':
        return PayoutSchedule.manual;
      default:
        return PayoutSchedule.weekly;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'stripe_account_id': stripeAccountId,
      'status': status.name,
      'charges_enabled': chargesEnabled,
      'payouts_enabled': payoutsEnabled,
      'details_submitted': detailsSubmitted,
      'requirements_currently_due': requirementsCurrentlyDue,
      'requirements_eventually_due': requirementsEventuallyDue,
      'requirements_past_due': requirementsPastDue,
      'account_type': accountType,
      'country': country,
      'currency': currency,
      'email': email,
      'business_name': businessName,
      'business_url': businessUrl,
      'payout_schedule': payoutSchedule.name,
      'payout_delay_days': payoutDelayDays,
      'onboarding_completed_at': onboardingCompletedAt?.toIso8601String(),
      'last_payout_at': lastPayoutAt?.toIso8601String(),
      'total_payouts': totalPayouts,
      'pending_balance': pendingBalance,
      'available_balance': availableBalance,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isFullyOnboarded =>
      detailsSubmitted &&
      chargesEnabled &&
      payoutsEnabled &&
      requirementsCurrentlyDue.isEmpty &&
      requirementsPastDue.isEmpty;

  bool get hasRequirements =>
      requirementsCurrentlyDue.isNotEmpty ||
      requirementsPastDue.isNotEmpty ||
      requirementsEventuallyDue.isNotEmpty;

  bool get canAcceptPayments => chargesEnabled && status == StripeAccountStatus.enabled;

  bool get canReceivePayouts => payoutsEnabled && status == StripeAccountStatus.enabled;

  StripeAccount copyWith({
    String? id,
    String? vendorId,
    String? stripeAccountId,
    StripeAccountStatus? status,
    bool? chargesEnabled,
    bool? payoutsEnabled,
    bool? detailsSubmitted,
    List<String>? requirementsCurrentlyDue,
    List<String>? requirementsEventuallyDue,
    List<String>? requirementsPastDue,
    String? accountType,
    String? country,
    String? currency,
    String? email,
    String? businessName,
    String? businessUrl,
    PayoutSchedule? payoutSchedule,
    int? payoutDelayDays,
    DateTime? onboardingCompletedAt,
    DateTime? lastPayoutAt,
    double? totalPayouts,
    double? pendingBalance,
    double? availableBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return StripeAccount(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      stripeAccountId: stripeAccountId ?? this.stripeAccountId,
      status: status ?? this.status,
      chargesEnabled: chargesEnabled ?? this.chargesEnabled,
      payoutsEnabled: payoutsEnabled ?? this.payoutsEnabled,
      detailsSubmitted: detailsSubmitted ?? this.detailsSubmitted,
      requirementsCurrentlyDue: requirementsCurrentlyDue ?? this.requirementsCurrentlyDue,
      requirementsEventuallyDue: requirementsEventuallyDue ?? this.requirementsEventuallyDue,
      requirementsPastDue: requirementsPastDue ?? this.requirementsPastDue,
      accountType: accountType ?? this.accountType,
      country: country ?? this.country,
      currency: currency ?? this.currency,
      email: email ?? this.email,
      businessName: businessName ?? this.businessName,
      businessUrl: businessUrl ?? this.businessUrl,
      payoutSchedule: payoutSchedule ?? this.payoutSchedule,
      payoutDelayDays: payoutDelayDays ?? this.payoutDelayDays,
      onboardingCompletedAt: onboardingCompletedAt ?? this.onboardingCompletedAt,
      lastPayoutAt: lastPayoutAt ?? this.lastPayoutAt,
      totalPayouts: totalPayouts ?? this.totalPayouts,
      pendingBalance: pendingBalance ?? this.pendingBalance,
      availableBalance: availableBalance ?? this.availableBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class PayoutRecord {
  final String id;
  final String vendorId;
  final String? stripePayoutId;
  final double amount;
  final String currency;
  final String status; // pending, paid, failed, canceled
  final DateTime? arrivalDate;
  final String? bankAccount;
  final String? failureMessage;
  final DateTime createdAt;

  const PayoutRecord({
    required this.id,
    required this.vendorId,
    this.stripePayoutId,
    required this.amount,
    this.currency = 'usd',
    required this.status,
    this.arrivalDate,
    this.bankAccount,
    this.failureMessage,
    required this.createdAt,
  });

  factory PayoutRecord.fromJson(Map<String, dynamic> json) {
    return PayoutRecord(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      stripePayoutId: json['stripe_payout_id'] as String?,
      amount: (json['amount'] as num).toDouble(),
      currency: json['currency'] as String? ?? 'usd',
      status: json['status'] as String,
      arrivalDate: json['arrival_date'] != null
          ? DateTime.parse(json['arrival_date'] as String)
          : null,
      bankAccount: json['bank_account'] as String?,
      failureMessage: json['failure_message'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'stripe_payout_id': stripePayoutId,
      'amount': amount,
      'currency': currency,
      'status': status,
      'arrival_date': arrivalDate?.toIso8601String(),
      'bank_account': bankAccount,
      'failure_message': failureMessage,
      'created_at': createdAt.toIso8601String(),
    };
  }

  bool get isPaid => status == 'paid';
  bool get isPending => status == 'pending';
  bool get isFailed => status == 'failed';
}
