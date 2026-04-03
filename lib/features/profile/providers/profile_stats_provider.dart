import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/supabase_service.dart';
import '../../auth/providers/supabase_auth_provider.dart';

class ProfileStats {
  final int totalEvents;
  final int activeEvents;
  final int totalInventoryItems;
  final int lowStockItems;
  final int totalBookings;
  final int pendingBookings;
  final double averageRating;
  final int totalRatings;

  ProfileStats({
    required this.totalEvents,
    required this.activeEvents,
    required this.totalInventoryItems,
    required this.lowStockItems,
    required this.totalBookings,
    required this.pendingBookings,
    required this.averageRating,
    required this.totalRatings,
  });

  ProfileStats copyWith({
    int? totalEvents,
    int? activeEvents,
    int? totalInventoryItems,
    int? lowStockItems,
    int? totalBookings,
    int? pendingBookings,
    double? averageRating,
    int? totalRatings,
  }) {
    return ProfileStats(
      totalEvents: totalEvents ?? this.totalEvents,
      activeEvents: activeEvents ?? this.activeEvents,
      totalInventoryItems: totalInventoryItems ?? this.totalInventoryItems,
      lowStockItems: lowStockItems ?? this.lowStockItems,
      totalBookings: totalBookings ?? this.totalBookings,
      pendingBookings: pendingBookings ?? this.pendingBookings,
      averageRating: averageRating ?? this.averageRating,
      totalRatings: totalRatings ?? this.totalRatings,
    );
  }
}

final profileStatsProvider = FutureProvider<ProfileStats>((ref) async {
  final supabaseService = ref.read(supabaseServiceProvider);
  final user = ref.watch(currentUserProvider);

  if (user == null) {
    return ProfileStats(
      totalEvents: 0,
      activeEvents: 0,
      totalInventoryItems: 0,
      lowStockItems: 0,
      totalBookings: 0,
      pendingBookings: 0,
      averageRating: 0.0,
      totalRatings: 0,
    );
  }

  try {
    // Fetch all data in parallel
    final results = await Future.wait([
      supabaseService.getAllEvents(),
      supabaseService.getAllInventory(),
      supabaseService.getAllBookings(),
    ]);

    final events = results[0];
    final inventory = results[1];
    final bookings = results[2];

    // Calculate stats
    final now = DateTime.now();
    final activeEvents = events.where((event) {
      final eventDate = event['date'] != null
          ? DateTime.parse(event['date'])
          : null;
      return eventDate != null && eventDate.isAfter(now);
    }).length;

    final lowStockItems = inventory.where((item) {
      final quantity = item['quantity'] ?? 0;
      final minQuantity = item['min_quantity'] ?? 10;
      return quantity < minQuantity;
    }).length;

    final pendingBookings = bookings.where((booking) {
      final status = booking['status'] ?? 'pending';
      return status == 'pending';
    }).length;

    // Calculate average rating (mock data for now, you can add real ratings later)
    double averageRating = 0.0;
    int totalRatings = 0;

    // If you have ratings in your database, calculate here
    // For now, using mock calculation based on confirmed bookings
    final confirmedBookings = bookings.where((b) => b['status'] == 'confirmed').length;
    if (confirmedBookings > 0) {
      averageRating = 4.5 + (confirmedBookings % 10) * 0.05; // Mock calculation
      totalRatings = confirmedBookings;
    }

    return ProfileStats(
      totalEvents: events.length,
      activeEvents: activeEvents,
      totalInventoryItems: inventory.length,
      lowStockItems: lowStockItems,
      totalBookings: bookings.length,
      pendingBookings: pendingBookings,
      averageRating: averageRating.clamp(0.0, 5.0),
      totalRatings: totalRatings,
    );
  } catch (e) {
    // Log error - consider using a logging framework in production
    return ProfileStats(
      totalEvents: 0,
      activeEvents: 0,
      totalInventoryItems: 0,
      lowStockItems: 0,
      totalBookings: 0,
      pendingBookings: 0,
      averageRating: 0.0,
      totalRatings: 0,
    );
  }
});
