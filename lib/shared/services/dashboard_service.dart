import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/dashboard_stats.dart';

class DashboardService {
  final SupabaseClient _supabase = Supabase.instance.client;

  // Get dashboard statistics for the current vendor
  Future<DashboardStats> getDashboardStats() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final now = DateTime.now();
      final monthStart = DateTime(now.year, now.month, 1).toIso8601String();
      final todayIso = now.toIso8601String();

      // ── Events ──────────────────────────────────────────────────────────────
      // All events owned by this vendor
      final allEventsResp = await _supabase
          .from('events')
          .select('id, event_date, status, is_active, created_at')
          .eq('user_id', userId)
          .order('event_date', ascending: false);

      final allEvents = (allEventsResp as List);
      final totalEvents = allEvents.length;

      // Upcoming: event_date in the future
      final upcomingEvents = allEvents
          .where((e) {
            final d = e['event_date'];
            if (d == null) return false;
            return DateTime.tryParse(d.toString())?.isAfter(now) ?? false;
          })
          .length;

      // Active: is_active = true OR status == 'active' / 'published'
      final activeEvents = allEvents
          .where((e) =>
              e['is_active'] == true ||
              e['status'] == 'active' ||
              e['status'] == 'published')
          .length;

      DateTime? lastEventDate;
      if (allEvents.isNotEmpty && allEvents.first['created_at'] != null) {
        lastEventDate = DateTime.tryParse(allEvents.first['created_at']);
      }

      // ── Bookings ─────────────────────────────────────────────────────────────
      int totalBookings = 0;
      int confirmedBookings = 0;
      int pendingBookings = 0;
      double monthlyRevenue = 0.0;
      double totalRevenue = 0.0;
      DateTime? lastBookingDate;

      try {
        // All bookings for this vendor's events
        final bookingsResp = await _supabase
            .from('events_bookings')
            .select(
                'id, status, total_amount, created_at, event_id, events!inner(user_id)')
            .eq('events.user_id', userId)
            .order('created_at', ascending: false);

        final bookings = (bookingsResp as List);
        totalBookings = bookings.length;

        confirmedBookings =
            bookings.where((b) => b['status'] == 'confirmed').length;
        pendingBookings =
            bookings.where((b) => b['status'] == 'pending').length;

        // Total revenue (all time)
        totalRevenue = bookings.fold<double>(
          0.0,
          (sum, b) => sum + ((b['total_amount'] ?? 0) as num).toDouble(),
        );

        // Monthly revenue (bookings created this calendar month)
        monthlyRevenue = bookings
            .where((b) {
              final d = b['created_at'];
              if (d == null) return false;
              final date = DateTime.tryParse(d.toString());
              return date != null && date.isAfter(DateTime.parse(monthStart));
            })
            .fold<double>(
              0.0,
              (sum, b) =>
                  sum + ((b['total_amount'] ?? 0) as num).toDouble(),
            );

        if (bookings.isNotEmpty && bookings.first['created_at'] != null) {
          lastBookingDate = DateTime.tryParse(bookings.first['created_at']);
        }
      } catch (_) {
        // Bookings table might not exist yet
      }

      // ── Inventory ────────────────────────────────────────────────────────────
      int inventoryCount = 0;
      int lowStockItems = 0;
      DateTime? lastInventoryUpdate;

      try {
        final inventoryResp = await _supabase
            .from('vendor_inventory')
            .select('id, stock, min_stock, updated_at')
            .eq('vendor_id', userId)
            .order('updated_at', ascending: false);

        final inventory = (inventoryResp as List);
        inventoryCount = inventory.length;
        lowStockItems = inventory
            .where((i) {
              final stock = (i['stock'] ?? 0) as int;
              final minStock = (i['min_stock'] ?? 0) as int;
              return stock <= minStock;
            })
            .length;

        if (inventory.isNotEmpty && inventory.first['updated_at'] != null) {
          lastInventoryUpdate =
              DateTime.tryParse(inventory.first['updated_at']);
        }
      } catch (_) {
        // Inventory table might not exist yet
      }

      return DashboardStats(
        vendorId: userId,
        totalEvents: totalEvents,
        upcomingEvents: upcomingEvents,
        activeEvents: activeEvents,
        totalBookings: totalBookings,
        monthlyBookings: pendingBookings, // reuse field for pending count
        confirmedBookings: confirmedBookings,
        inventoryCount: inventoryCount,
        featuredItems: 0,
        lowStockItems: lowStockItems,
        monthlyRevenue: monthlyRevenue,
        confirmedRevenue: totalRevenue * 0.85, // estimated payout (85%)
        lastEventDate: lastEventDate,
        lastBookingDate: lastBookingDate,
        lastInventoryUpdate: lastInventoryUpdate,
      );
    } catch (e) {
      final userId = _supabase.auth.currentUser?.id ?? '';
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

  // Get recent activity (real bookings & events)
  Future<Map<String, dynamic>> getRecentActivity() async {
    try {
      final userId = _supabase.auth.currentUser!.id;

      final recentEvents = await _supabase
          .from('events')
          .select('id, name, event_date, status')
          .eq('user_id', userId)
          .order('created_at', ascending: false)
          .limit(5);

      List recentBookings = [];
      try {
        recentBookings = await _supabase
            .from('events_bookings')
            .select(
                'id, total_amount, status, created_at, events!inner(user_id, name)')
            .eq('events.user_id', userId)
            .order('created_at', ascending: false)
            .limit(5);
      } catch (_) {}

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
      return {'recent_events': [], 'recent_bookings': [], 'recent_inventory': []};
    }
  }

  // Revenue trends (last 6 months) via RPC if available
  Future<List<Map<String, dynamic>>> getRevenueTrends() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response =
          await _supabase.rpc('get_revenue_trends', params: {'vendor_id': userId});
      return List<Map<String, dynamic>>.from(response);
    } catch (_) {
      return [];
    }
  }

  // Top performing events (by current_bookings)
  Future<List<Map<String, dynamic>>> getTopPerformingEvents() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('events')
          .select('id, name, current_bookings, max_capacity, ticket_price')
          .eq('user_id', userId)
          .order('current_bookings', ascending: false)
          .limit(5);
      return List<Map<String, dynamic>>.from(response);
    } catch (e) {
      return [];
    }
  }

  // Low stock alerts
  Future<List<Map<String, dynamic>>> getLowStockAlerts() async {
    try {
      final userId = _supabase.auth.currentUser!.id;
      final response = await _supabase
          .from('vendor_inventory')
          .select('id, name, stock, min_stock, category')
          .eq('vendor_id', userId)
          .order('stock', ascending: true);
      return (response as List)
          .where((i) => (i['stock'] ?? 0) <= (i['min_stock'] ?? 0))
          .toList()
          .cast<Map<String, dynamic>>();
    } catch (_) {
      return [];
    }
  }
}
