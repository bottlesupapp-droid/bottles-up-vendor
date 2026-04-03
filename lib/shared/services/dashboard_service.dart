import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_stats.dart';

class DashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get dashboard statistics for the current vendor
  Future<DashboardStats> getDashboardStats() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      // Calculate stats manually from events, bookings, and inventory tables
      // Count events from events table
      final eventsResponse = await _supabase
          .from('events')
          .select('id, user_id, created_at')
          .eq('user_id', userId)
          .order('created_at', ascending: false);

      final totalEvents = (eventsResponse as List).length;
      final activeEvents = totalEvents; // For now, consider all events as active

      // Get last event date
      DateTime? lastEventDate;
      if (eventsResponse.isNotEmpty) {
        final lastEvent = eventsResponse.first;
        if (lastEvent['created_at'] != null) {
          lastEventDate = DateTime.parse(lastEvent['created_at']);
        }
      }

      // Count bookings from events_bookings (join with events to get vendor's bookings)
      int totalBookings = 0;
      int confirmedBookings = 0;
      double monthlyRevenue = 0.0;
      DateTime? lastBookingDate;

      try {
        final bookingsResponse = await _supabase
            .from('events_bookings')
            .select('id, status, total_amount, created_at, event_id, events!inner(user_id)')
            .eq('events.user_id', userId)
            .order('created_at', ascending: false);

        totalBookings = (bookingsResponse as List).length;
        confirmedBookings = bookingsResponse
            .where((b) => b['status'] == 'confirmed')
            .length;

        monthlyRevenue = bookingsResponse.fold<double>(
          0.0,
          (sum, b) => sum + ((b['total_amount'] ?? 0) as num).toDouble(),
        );

        // Get last booking date
        if (bookingsResponse.isNotEmpty) {
          final lastBooking = bookingsResponse.first;
          if (lastBooking['created_at'] != null) {
            lastBookingDate = DateTime.parse(lastBooking['created_at']);
          }
        }
      } catch (e) {
        // Bookings table might not exist yet or query failed
      }

      // Count inventory items from vendor_inventory
      int inventoryCount = 0;
      int lowStockItems = 0;
      DateTime? lastInventoryUpdate;

      try {
        final inventoryResponse = await _supabase
            .from('vendor_inventory')
            .select('id, stock, min_stock, updated_at')
            .eq('vendor_id', userId)
            .order('updated_at', ascending: false);

        inventoryCount = (inventoryResponse as List).length;
        lowStockItems = inventoryResponse
            .where((i) =>
              (i['stock'] ?? 0) <= (i['min_stock'] ?? 0))
            .length;

        // Get last inventory update date
        if (inventoryResponse.isNotEmpty) {
          final lastItem = inventoryResponse.first;
          if (lastItem['updated_at'] != null) {
            lastInventoryUpdate = DateTime.parse(lastItem['updated_at']);
          }
        }
      } catch (e) {
        // Inventory table might not exist yet
      }

      return DashboardStats(
        vendorId: userId,
        totalEvents: totalEvents,
        upcomingEvents: totalEvents, // For now, consider all as upcoming
        activeEvents: activeEvents,
        totalBookings: totalBookings,
        monthlyBookings: totalBookings,
        confirmedBookings: confirmedBookings,
        inventoryCount: inventoryCount,
        featuredItems: 0,
        lowStockItems: lowStockItems,
        monthlyRevenue: monthlyRevenue,
        confirmedRevenue: monthlyRevenue * 0.85, // 85% after fees
        lastEventDate: lastEventDate,
        lastBookingDate: lastBookingDate,
        lastInventoryUpdate: lastInventoryUpdate,
      );
    } catch (e) {
      // If all fails, return default stats
      final userId = _supabase.auth.currentUser!.id;
      return DashboardStats(
        vendorId: userId,
        totalEvents: 0,
        upcomingEvents: 0,
        activeEvents: 0,
        totalBookings: 0,
        monthlyBookings: 0,
        confirmedBookings: 0,
        inventoryCount: 0,
        featuredItems: 0,
        lowStockItems: 0,
        monthlyRevenue: 0.0,
        confirmedRevenue: 0.0,
      );
    }
  }

  // Get recent activity
  Future<Map<String, dynamic>> getRecentActivity() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      // Get recent events
      final recentEvents = await _supabase
          .from('vendor_events')
          .select('id, title, date, status')
          .eq('vendor_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      // Get recent bookings
      final recentBookings = await _supabase
          .from('vendor_bookings')
          .select('id, customer_name, total_amount, status, created_at')
          .eq('vendor_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      // Get recent inventory updates
      final recentInventory = await _supabase
          .from('vendor_inventory')
          .select('id, name, stock, updated_at')
          .eq('vendor_id', userId)
          .order('updated_at', ascending: false)
          .limit(5);

      return {
        'recent_events': recentEvents,
        'recent_bookings': recentBookings,
        'recent_inventory': recentInventory,
      };
    } catch (e) {
      throw Exception('Failed to fetch recent activity: $e');
    }
  }

  // Get revenue trends (last 6 months)
  Future<List<Map<String, dynamic>>> getRevenueTrends() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .rpc('get_revenue_trends', params: {'vendor_id': userId});

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      // If function doesn't exist, return empty list
      return [];
    }
  }

  // Get top performing events
  Future<List<Map<String, dynamic>>> getTopPerformingEvents() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('vendor_events')
          .select('id, title, booked_seats, capacity, price')
          .eq('vendor_id', userId)
          .order('booked_seats', ascending: false)
          .limit(5);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch top performing events: $e');
    }
  }

  // Get low stock alerts
  Future<List<Map<String, dynamic>>> getLowStockAlerts() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      
      final response = await _supabase
          .from('vendor_inventory')
          .select('id, name, stock, min_stock, category')
          .eq('vendor_id', userId)
          .lte('stock', 'min_stock')
          .order('stock', ascending: true);

      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      throw Exception('Failed to fetch low stock alerts: $e');
    }
  }
}
