import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/subscription_plan.dart';

class SubscriptionService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Get all available subscription plans
  Future<List<SubscriptionPlan>> getAvailablePlans() async {
    try {
      // For now, return the predefined plans
      // In a production app, you'd fetch from database
      return PlanTiers.allPlans;
    } catch (e) {
      throw Exception('Failed to fetch subscription plans: $e');
    }
  }

  /// Get current vendor's subscription
  Future<VendorSubscription?> getCurrentSubscription(String vendorId) async {
    try {
      final response = await _supabase
          .from('vendor_subscriptions')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false)
          .limit(1)
          .maybeSingle();

      if (response == null) return null;

      return VendorSubscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch subscription: $e');
    }
  }

  /// Get subscription plan by ID
  Future<SubscriptionPlan?> getPlanById(String planId) async {
    try {
      // Check predefined plans first
      final predefinedPlan = PlanTiers.allPlans.where((p) => p.id == planId).firstOrNull;
      if (predefinedPlan != null) {
        return predefinedPlan;
      }

      // If not in predefined plans, fetch from database
      final response = await _supabase
          .from('subscription_plans')
          .select()
          .eq('id', planId)
          .maybeSingle();

      if (response == null) return null;

      return SubscriptionPlan.fromJson(response);
    } catch (e) {
      throw Exception('Failed to fetch plan: $e');
    }
  }

  /// Create a new subscription for vendor
  Future<VendorSubscription> createSubscription({
    required String vendorId,
    required String planId,
    String? stripeSubscriptionId,
    String? stripeCustomerId,
  }) async {
    try {
      final now = DateTime.now();
      final periodEnd = now.add(const Duration(days: 30)); // Monthly subscription

      final subscriptionData = {
        'vendor_id': vendorId,
        'plan_id': planId,
        'status': 'active',
        'current_period_start': now.toIso8601String(),
        'current_period_end': periodEnd.toIso8601String(),
        'cancel_at_period_end': false,
        'stripe_subscription_id': stripeSubscriptionId,
        'stripe_customer_id': stripeCustomerId,
      };

      final response = await _supabase
          .from('vendor_subscriptions')
          .insert(subscriptionData)
          .select()
          .single();

      return VendorSubscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to create subscription: $e');
    }
  }

  /// Update subscription status
  Future<VendorSubscription> updateSubscriptionStatus({
    required String subscriptionId,
    required SubscriptionStatus status,
  }) async {
    try {
      final response = await _supabase
          .from('vendor_subscriptions')
          .update({
            'status': status.name,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId)
          .select()
          .single();

      return VendorSubscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to update subscription status: $e');
    }
  }

  /// Cancel subscription at period end
  Future<VendorSubscription> cancelSubscription(String subscriptionId) async {
    try {
      final response = await _supabase
          .from('vendor_subscriptions')
          .update({
            'cancel_at_period_end': true,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId)
          .select()
          .single();

      return VendorSubscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to cancel subscription: $e');
    }
  }

  /// Reactivate cancelled subscription
  Future<VendorSubscription> reactivateSubscription(String subscriptionId) async {
    try {
      final response = await _supabase
          .from('vendor_subscriptions')
          .update({
            'cancel_at_period_end': false,
            'cancel_at': null,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId)
          .select()
          .single();

      return VendorSubscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to reactivate subscription: $e');
    }
  }

  /// Upgrade/Downgrade subscription plan
  Future<VendorSubscription> changePlan({
    required String subscriptionId,
    required String newPlanId,
  }) async {
    try {
      final response = await _supabase
          .from('vendor_subscriptions')
          .update({
            'plan_id': newPlanId,
            'updated_at': DateTime.now().toIso8601String(),
          })
          .eq('id', subscriptionId)
          .select()
          .single();

      return VendorSubscription.fromJson(response);
    } catch (e) {
      throw Exception('Failed to change plan: $e');
    }
  }

  /// Check if vendor can create more events based on their plan
  Future<bool> canCreateEvent(String vendorId) async {
    try {
      final subscription = await getCurrentSubscription(vendorId);

      if (subscription == null || !subscription.isActive) {
        // No active subscription, check if they're on free plan
        final plan = PlanTiers.freePlan;
        final eventCount = await _getEventCountThisMonth(vendorId);
        return eventCount < plan.maxEvents;
      }

      final plan = await getPlanById(subscription.planId);
      if (plan == null) return false;

      // If unlimited events
      if (plan.maxEvents == -1) return true;

      final eventCount = await _getEventCountThisMonth(vendorId);
      return eventCount < plan.maxEvents;
    } catch (e) {
      throw Exception('Failed to check event creation limit: $e');
    }
  }

  /// Get event count for current month
  Future<int> _getEventCountThisMonth(String vendorId) async {
    final now = DateTime.now();
    final startOfMonth = DateTime(now.year, now.month, 1);
    final endOfMonth = DateTime(now.year, now.month + 1, 0);

    final response = await _supabase
        .from('events')
        .select('id')
        .eq('user_id', vendorId)
        .gte('created_at', startOfMonth.toIso8601String())
        .lte('created_at', endOfMonth.toIso8601String());

    return (response as List).length;
  }

  /// Get subscription usage stats
  Future<Map<String, dynamic>> getSubscriptionUsage(String vendorId) async {
    try {
      final subscription = await getCurrentSubscription(vendorId);
      final plan = subscription != null
          ? await getPlanById(subscription.planId)
          : PlanTiers.freePlan;

      if (plan == null) {
        throw Exception('Plan not found');
      }

      final eventCount = await _getEventCountThisMonth(vendorId);

      return {
        'plan_name': plan.name,
        'plan_id': plan.id,
        'events_used': eventCount,
        'events_limit': plan.maxEvents,
        'events_remaining': plan.maxEvents == -1
            ? -1
            : (plan.maxEvents - eventCount).clamp(0, plan.maxEvents),
        'unlimited_events': plan.maxEvents == -1,
        'has_analytics': plan.hasAnalytics,
        'has_custom_branding': plan.hasCustomBranding,
        'team_member_limit': plan.teamMemberLimit,
        'subscription_status': subscription?.status.name ?? 'free',
        'period_end': subscription?.currentPeriodEnd.toIso8601String(),
      };
    } catch (e) {
      throw Exception('Failed to get subscription usage: $e');
    }
  }

  /// Placeholder for Stripe integration
  /// In production, this would create a Stripe Checkout session
  Future<String> createCheckoutSession({
    required String vendorId,
    required String planId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    // TODO: Implement Stripe Checkout Session creation
    // This is a placeholder that returns a mock URL
    throw UnimplementedError(
      'Stripe integration not implemented yet. '
      'You need to integrate Stripe Checkout API here.',
    );
  }

  /// Placeholder for Stripe portal session
  /// This allows vendors to manage their subscription via Stripe's customer portal
  Future<String> createPortalSession({
    required String stripeCustomerId,
    required String returnUrl,
  }) async {
    // TODO: Implement Stripe Customer Portal session creation
    throw UnimplementedError(
      'Stripe Customer Portal not implemented yet. '
      'You need to integrate Stripe Customer Portal API here.',
    );
  }
}
