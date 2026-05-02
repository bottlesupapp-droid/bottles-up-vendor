enum SubscriptionStatus {
  active,
  trialing,
  pastDue,
  canceled,
  unpaid,
  incomplete,
  incompleteExpired,
}

class SubscriptionPlan {
  final String id;
  final String name;
  final String description;
  final double price;
  final String billingPeriod; // monthly, yearly
  final int maxEvents;
  final int maxTicketsPerEvent;
  final bool hasAnalytics;
  final bool hasCustomBranding;
  final bool hasPrioritySupport;
  final bool hasAdvancedReporting;
  final int teamMemberLimit;
  final List<String> features;
  final bool isActive;
  final bool isPopular;
  final String? stripeProductId;
  final String? stripePriceId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const SubscriptionPlan({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.billingPeriod,
    required this.maxEvents,
    required this.maxTicketsPerEvent,
    required this.hasAnalytics,
    required this.hasCustomBranding,
    required this.hasPrioritySupport,
    required this.hasAdvancedReporting,
    required this.teamMemberLimit,
    this.features = const [],
    required this.isActive,
    required this.isPopular,
    this.stripeProductId,
    this.stripePriceId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String,
      price: (json['price'] as num).toDouble(),
      billingPeriod: json['billing_period'] as String,
      maxEvents: json['max_events'] as int,
      maxTicketsPerEvent: json['max_tickets_per_event'] as int,
      hasAnalytics: json['has_analytics'] as bool,
      hasCustomBranding: json['has_custom_branding'] as bool,
      hasPrioritySupport: json['has_priority_support'] as bool,
      hasAdvancedReporting: json['has_advanced_reporting'] as bool,
      teamMemberLimit: json['team_member_limit'] as int,
      features: json['features'] != null ? List<String>.from(json['features']) : [],
      isActive: json['is_active'] as bool,
      isPopular: json['is_popular'] as bool? ?? false,
      stripeProductId: json['stripe_product_id'] as String?,
      stripePriceId: json['stripe_price_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'price': price,
      'billing_period': billingPeriod,
      'max_events': maxEvents,
      'max_tickets_per_event': maxTicketsPerEvent,
      'has_analytics': hasAnalytics,
      'has_custom_branding': hasCustomBranding,
      'has_priority_support': hasPrioritySupport,
      'has_advanced_reporting': hasAdvancedReporting,
      'team_member_limit': teamMemberLimit,
      'features': features,
      'is_active': isActive,
      'is_popular': isPopular,
      'stripe_product_id': stripeProductId,
      'stripe_price_id': stripePriceId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class VendorSubscription {
  final String id;
  final String vendorId;
  final String planId;
  final SubscriptionStatus status;
  final DateTime currentPeriodStart;
  final DateTime currentPeriodEnd;
  final DateTime? cancelledAt;
  final DateTime? cancelAt;
  final bool cancelAtPeriodEnd;
  final String? stripeSubscriptionId;
  final String? stripeCustomerId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const VendorSubscription({
    required this.id,
    required this.vendorId,
    required this.planId,
    required this.status,
    required this.currentPeriodStart,
    required this.currentPeriodEnd,
    this.cancelledAt,
    this.cancelAt,
    this.cancelAtPeriodEnd = false,
    this.stripeSubscriptionId,
    this.stripeCustomerId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory VendorSubscription.fromJson(Map<String, dynamic> json) {
    return VendorSubscription(
      id: json['id'] as String,
      vendorId: json['vendor_id'] as String,
      planId: json['plan_id'] as String,
      status: _parseStatus(json['status'] as String),
      currentPeriodStart: DateTime.parse(json['current_period_start'] as String),
      currentPeriodEnd: DateTime.parse(json['current_period_end'] as String),
      cancelledAt: json['cancelled_at'] != null ? DateTime.parse(json['cancelled_at'] as String) : null,
      cancelAt: json['cancel_at'] != null ? DateTime.parse(json['cancel_at'] as String) : null,
      cancelAtPeriodEnd: json['cancel_at_period_end'] as bool? ?? false,
      stripeSubscriptionId: json['stripe_subscription_id'] as String?,
      stripeCustomerId: json['stripe_customer_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static SubscriptionStatus _parseStatus(String status) {
    switch (status.toLowerCase()) {
      case 'active':
        return SubscriptionStatus.active;
      case 'trialing':
        return SubscriptionStatus.trialing;
      case 'past_due':
        return SubscriptionStatus.pastDue;
      case 'canceled':
        return SubscriptionStatus.canceled;
      case 'unpaid':
        return SubscriptionStatus.unpaid;
      case 'incomplete':
        return SubscriptionStatus.incomplete;
      case 'incomplete_expired':
        return SubscriptionStatus.incompleteExpired;
      default:
        return SubscriptionStatus.active;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'vendor_id': vendorId,
      'plan_id': planId,
      'status': status.name,
      'current_period_start': currentPeriodStart.toIso8601String(),
      'current_period_end': currentPeriodEnd.toIso8601String(),
      'cancelled_at': cancelledAt?.toIso8601String(),
      'cancel_at': cancelAt?.toIso8601String(),
      'cancel_at_period_end': cancelAtPeriodEnd,
      'stripe_subscription_id': stripeSubscriptionId,
      'stripe_customer_id': stripeCustomerId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  bool get isActive => status == SubscriptionStatus.active || status == SubscriptionStatus.trialing;
  bool get isCanceled => status == SubscriptionStatus.canceled;
  bool get isPastDue => status == SubscriptionStatus.pastDue;

  VendorSubscription copyWith({
    String? id,
    String? vendorId,
    String? planId,
    SubscriptionStatus? status,
    DateTime? currentPeriodStart,
    DateTime? currentPeriodEnd,
    DateTime? cancelledAt,
    DateTime? cancelAt,
    bool? cancelAtPeriodEnd,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return VendorSubscription(
      id: id ?? this.id,
      vendorId: vendorId ?? this.vendorId,
      planId: planId ?? this.planId,
      status: status ?? this.status,
      currentPeriodStart: currentPeriodStart ?? this.currentPeriodStart,
      currentPeriodEnd: currentPeriodEnd ?? this.currentPeriodEnd,
      cancelledAt: cancelledAt ?? this.cancelledAt,
      cancelAt: cancelAt ?? this.cancelAt,
      cancelAtPeriodEnd: cancelAtPeriodEnd ?? this.cancelAtPeriodEnd,
      stripeSubscriptionId: stripeSubscriptionId ?? this.stripeSubscriptionId,
      stripeCustomerId: stripeCustomerId ?? this.stripeCustomerId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

// Predefined plan tiers
class PlanTiers {
  static const String free = 'free';
  static const String starter = 'starter';
  static const String professional = 'professional';
  static const String enterprise = 'enterprise';

  static SubscriptionPlan get freePlan => SubscriptionPlan(
        id: free,
        name: 'Free',
        description: 'Perfect for getting started',
        price: 0,
        billingPeriod: 'monthly',
        maxEvents: 3,
        maxTicketsPerEvent: 50,
        hasAnalytics: false,
        hasCustomBranding: false,
        hasPrioritySupport: false,
        hasAdvancedReporting: false,
        teamMemberLimit: 1,
        features: const [
          'Up to 3 events per month',
          'Max 50 tickets per event',
          'Basic analytics',
          'Email support',
        ],
        isActive: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static SubscriptionPlan get starterPlan => SubscriptionPlan(
        id: starter,
        name: 'Starter',
        description: 'Great for small event organizers',
        price: 29.99,
        billingPeriod: 'monthly',
        maxEvents: 10,
        maxTicketsPerEvent: 200,
        hasAnalytics: true,
        hasCustomBranding: false,
        hasPrioritySupport: false,
        hasAdvancedReporting: false,
        teamMemberLimit: 3,
        features: const [
          'Up to 10 events per month',
          'Max 200 tickets per event',
          'Advanced analytics',
          'Custom ticket tiers',
          '3 team members',
          'Email support',
        ],
        isActive: true,
        isPopular: true,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static SubscriptionPlan get professionalPlan => SubscriptionPlan(
        id: professional,
        name: 'Professional',
        description: 'For growing event businesses',
        price: 79.99,
        billingPeriod: 'monthly',
        maxEvents: 50,
        maxTicketsPerEvent: 1000,
        hasAnalytics: true,
        hasCustomBranding: true,
        hasPrioritySupport: true,
        hasAdvancedReporting: true,
        teamMemberLimit: 10,
        features: const [
          'Up to 50 events per month',
          'Max 1000 tickets per event',
          'Advanced analytics & reporting',
          'Custom branding',
          'Priority support',
          '10 team members',
          'API access',
          'White-label options',
        ],
        isActive: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static SubscriptionPlan get enterprisePlan => SubscriptionPlan(
        id: enterprise,
        name: 'Enterprise',
        description: 'For large-scale operations',
        price: 199.99,
        billingPeriod: 'monthly',
        maxEvents: -1, // unlimited
        maxTicketsPerEvent: -1, // unlimited
        hasAnalytics: true,
        hasCustomBranding: true,
        hasPrioritySupport: true,
        hasAdvancedReporting: true,
        teamMemberLimit: -1, // unlimited
        features: const [
          'Unlimited events',
          'Unlimited tickets',
          'Advanced analytics & reporting',
          'Full custom branding',
          'Dedicated support',
          'Unlimited team members',
          'API access',
          'White-label options',
          'Custom integrations',
          'SLA guarantee',
        ],
        isActive: true,
        isPopular: false,
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

  static List<SubscriptionPlan> get allPlans => [
        freePlan,
        starterPlan,
        professionalPlan,
        enterprisePlan,
      ];
}
