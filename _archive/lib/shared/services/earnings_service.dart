import 'package:supabase_flutter/supabase_flutter.dart';
import 'stripe_service.dart';

class EarningsService {
  final SupabaseClient _supabase = Supabase.instance.client;
  final StripeService _stripeService = StripeService();

  /// Get vendor's Stripe account information
  Future<Map<String, dynamic>?> getStripeAccount(String vendorId) async {
    try {
      final response = await _supabase
          .from('stripe_accounts')
          .select()
          .eq('vendor_id', vendorId)
          .maybeSingle();

      return response;
    } catch (e) {
      throw Exception('Failed to fetch Stripe account: $e');
    }
  }

  /// Get total earnings from all events
  Future<Map<String, dynamic>> getTotalEarnings(String vendorId) async {
    try {
      // Get all bookings for vendor's events
      final response = await _supabase.rpc(
        'get_vendor_earnings',
        params: {'p_vendor_id': vendorId},
      );

      if (response == null) {
        return {
          'total_revenue': 0.0,
          'total_paid': 0.0,
          'pending_amount': 0.0,
          'total_bookings': 0,
          'total_events': 0,
        };
      }

      return {
        'total_revenue': (response['total_revenue'] ?? 0).toDouble(),
        'total_paid': (response['total_paid'] ?? 0).toDouble(),
        'pending_amount': (response['pending_amount'] ?? 0).toDouble(),
        'total_bookings': response['total_bookings'] ?? 0,
        'total_events': response['total_events'] ?? 0,
      };
    } catch (e) {
      // If RPC doesn't exist, calculate manually
      return await _calculateEarningsManually(vendorId);
    }
  }

  /// Manual calculation if RPC function doesn't exist
  Future<Map<String, dynamic>> _calculateEarningsManually(String vendorId) async {
    try {
      // Get all events for vendor
      final events = await _supabase
          .from('events')
          .select('id')
          .eq('user_id', vendorId);

      if (events.isEmpty) {
        return {
          'total_revenue': 0.0,
          'total_paid': 0.0,
          'pending_amount': 0.0,
          'total_bookings': 0,
          'total_events': 0,
        };
      }

      final eventIds = (events as List).map((e) => e['id']).toList();

      // Get all bookings for these events
      final bookings = await _supabase
          .from('events_bookings')
          .select('total_amount, paid_amount, status')
          .inFilter('event_id', eventIds);

      double totalRevenue = 0.0;
      double totalPaid = 0.0;
      int totalBookings = 0;

      for (final booking in bookings as List) {
        final total = (booking['total_amount'] ?? 0).toDouble();
        final paid = (booking['paid_amount'] ?? 0).toDouble();

        totalRevenue += total;
        totalPaid += paid;
        totalBookings++;
      }

      return {
        'total_revenue': totalRevenue,
        'total_paid': totalPaid,
        'pending_amount': totalRevenue - totalPaid,
        'total_bookings': totalBookings,
        'total_events': events.length,
      };
    } catch (e) {
      throw Exception('Failed to calculate earnings: $e');
    }
  }

  /// Get earnings by event
  Future<List<Map<String, dynamic>>> getEarningsByEvent(String vendorId) async {
    try {
      final response = await _supabase.rpc(
        'get_earnings_by_event',
        params: {'p_vendor_id': vendorId},
      );

      return List<Map<String, dynamic>>.from(response ?? []);
    } catch (e) {
      // Manual calculation if RPC doesn't exist
      return await _calculateEarningsByEventManually(vendorId);
    }
  }

  Future<List<Map<String, dynamic>>> _calculateEarningsByEventManually(
    String vendorId,
  ) async {
    try {
      final events = await _supabase
          .from('events')
          .select('id, name, event_date')
          .eq('user_id', vendorId)
          .order('event_date', ascending: false);

      final List<Map<String, dynamic>> earnings = [];

      for (final event in events as List) {
        final bookings = await _supabase
            .from('events_bookings')
            .select('total_amount, paid_amount')
            .eq('event_id', event['id']);

        double revenue = 0.0;
        double paid = 0.0;

        for (final booking in bookings as List) {
          revenue += (booking['total_amount'] ?? 0).toDouble();
          paid += (booking['paid_amount'] ?? 0).toDouble();
        }

        earnings.add({
          'event_id': event['id'],
          'event_name': event['name'],
          'event_date': event['event_date'],
          'revenue': revenue,
          'paid': paid,
          'pending': revenue - paid,
          'bookings_count': bookings.length,
        });
      }

      return earnings;
    } catch (e) {
      throw Exception('Failed to calculate event earnings: $e');
    }
  }

  /// Get Stripe balance (available and pending)
  Future<Map<String, dynamic>> getStripeBalance(String accountId) async {
    try {
      return await _stripeService.getBalance(accountId: accountId);
    } catch (e) {
      throw Exception('Failed to fetch Stripe balance: $e');
    }
  }

  /// Get payout history
  Future<List<Map<String, dynamic>>> getPayoutHistory(String vendorId) async {
    try {
      final response = await _supabase
          .from('payout_records')
          .select()
          .eq('vendor_id', vendorId)
          .order('created_at', ascending: false)
          .limit(50);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch payout history: $e');
    }
  }

  /// Request a payout
  Future<Map<String, dynamic>> requestPayout({
    required String vendorId,
    required String accountId,
    required double amount,
  }) async {
    try {
      return await _stripeService.createPayout(
        vendorId: vendorId,
        accountId: accountId,
        amount: amount,
      );
    } catch (e) {
      throw Exception('Failed to request payout: $e');
    }
  }

  /// Setup Stripe Connect account
  Future<Map<String, dynamic>> setupStripeConnect({
    required String vendorId,
    required String email,
    required String businessName,
  }) async {
    try {
      return await _stripeService.createConnectAccount(
        vendorId: vendorId,
        email: email,
        businessName: businessName,
        returnUrl: 'myapp://earnings/return',
        refreshUrl: 'myapp://earnings/refresh',
      );
    } catch (e) {
      throw Exception('Failed to setup Stripe Connect: $e');
    }
  }

  /// Get Stripe Connect dashboard link
  Future<String> getConnectDashboardLink(String accountId) async {
    try {
      return await _stripeService.createConnectDashboardLink(
        accountId: accountId,
      );
    } catch (e) {
      throw Exception('Failed to get dashboard link: $e');
    }
  }
}
