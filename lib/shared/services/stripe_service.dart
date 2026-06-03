import 'package:supabase_flutter/supabase_flutter.dart';

/// Service for handling Stripe payments via Supabase Edge Functions
class StripeService {
  final SupabaseClient _supabase = Supabase.instance.client;

  /// Create a Stripe checkout session for subscription
  ///
  /// Calls the `create-checkout-session` edge function
  /// Returns the checkout session URL for redirect
  Future<String> createCheckoutSession({
    required String vendorId,
    required String planId,
    required String successUrl,
    required String cancelUrl,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-checkout-session',
        body: {
          'vendor_id': vendorId,
          'plan_id': planId,
          'success_url': successUrl,
          'cancel_url': cancelUrl,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create checkout session: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return data['url'] as String;
    } catch (e) {
      throw Exception('Stripe checkout failed: $e');
    }
  }

  /// Create a Stripe customer portal session
  ///
  /// Calls the `create-portal-session` edge function
  /// Returns the portal URL for redirect
  Future<String> createPortalSession({
    required String stripeCustomerId,
    required String returnUrl,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-portal-session',
        body: {
          'customer_id': stripeCustomerId,
          'return_url': returnUrl,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create portal session: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return data['url'] as String;
    } catch (e) {
      throw Exception('Stripe portal failed: $e');
    }
  }

  /// Create a Stripe Connect account for vendor payouts
  ///
  /// Calls the `create-connect-account` edge function
  /// Returns the account onboarding URL
  Future<Map<String, dynamic>> createConnectAccount({
    required String vendorId,
    required String email,
    required String businessName,
    required String returnUrl,
    required String refreshUrl,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-connect-account',
        body: {
          'vendor_id': vendorId,
          'email': email,
          'business_name': businessName,
          'return_url': returnUrl,
          'refresh_url': refreshUrl,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create Connect account: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return {
        'account_id': data['account_id'] as String,
        'onboarding_url': data['url'] as String,
      };
    } catch (e) {
      throw Exception('Stripe Connect setup failed: $e');
    }
  }

  /// Get Stripe Connect account dashboard link
  ///
  /// Calls the `create-connect-login-link` edge function
  /// Returns the dashboard URL
  Future<String> createConnectDashboardLink({
    required String accountId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-connect-login-link',
        body: {
          'account_id': accountId,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create dashboard link: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return data['url'] as String;
    } catch (e) {
      throw Exception('Dashboard link failed: $e');
    }
  }

  /// Request a payout from Stripe
  ///
  /// Calls the `create-payout` edge function
  Future<Map<String, dynamic>> createPayout({
    required String vendorId,
    required String accountId,
    required double amount,
    String currency = 'usd',
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'create-payout',
        body: {
          'vendor_id': vendorId,
          'account_id': accountId,
          'amount': (amount * 100).toInt(), // Convert to cents
          'currency': currency,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to create payout: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return {
        'payout_id': data['payout_id'] as String,
        'amount': data['amount'] as int,
        'status': data['status'] as String,
        'arrival_date': data['arrival_date'] as int,
      };
    } catch (e) {
      throw Exception('Payout request failed: $e');
    }
  }

  /// Get balance available for payout
  ///
  /// Calls the `get-balance` edge function
  Future<Map<String, dynamic>> getBalance({
    required String accountId,
  }) async {
    try {
      final response = await _supabase.functions.invoke(
        'get-balance',
        body: {
          'account_id': accountId,
        },
      );

      if (response.status != 200) {
        throw Exception('Failed to get balance: ${response.data}');
      }

      final data = response.data as Map<String, dynamic>;

      if (data['error'] != null) {
        throw Exception(data['error']);
      }

      return {
        'available': (data['available'] as int) / 100, // Convert from cents
        'pending': (data['pending'] as int) / 100,
        'currency': data['currency'] as String,
      };
    } catch (e) {
      throw Exception('Balance fetch failed: $e');
    }
  }

  /// Verify webhook signature (for backend use)
  /// This would typically be called from a backend endpoint
  bool verifyWebhookSignature({
    required String payload,
    required String signature,
    required String webhookSecret,
  }) {
    // This is just a placeholder - actual verification happens in the edge function
    // The edge function will verify the webhook and update the database
    return true;
  }
}
