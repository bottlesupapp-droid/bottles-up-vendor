class DashboardStats {
  final String vendorId;
  final int totalEvents;
  final int upcomingEvents;
  final int activeEvents;
  final int totalBookings;
  final int monthlyBookings;
  final int confirmedBookings;
  final int inventoryCount;
  final int featuredItems;
  final int lowStockItems;
  final double monthlyRevenue;
  final double confirmedRevenue;
  final DateTime? lastBookingDate;
  final DateTime? lastEventDate;
  final DateTime? lastInventoryUpdate;

  DashboardStats({
    required this.vendorId,
    required this.totalEvents,
    required this.upcomingEvents,
    required this.activeEvents,
    required this.totalBookings,
    required this.monthlyBookings,
    required this.confirmedBookings,
    required this.inventoryCount,
    required this.featuredItems,
    required this.lowStockItems,
    required this.monthlyRevenue,
    required this.confirmedRevenue,
    this.lastBookingDate,
    this.lastEventDate,
    this.lastInventoryUpdate,
  });

  factory DashboardStats.fromJson(Map<String, dynamic> json) {
    return DashboardStats(
      vendorId: json['vendor_id'],
      totalEvents: json['total_events'] ?? 0,
      upcomingEvents: json['upcoming_events'] ?? 0,
      activeEvents: json['active_events'] ?? 0,
      totalBookings: json['total_bookings'] ?? 0,
      monthlyBookings: json['monthly_bookings'] ?? 0,
      confirmedBookings: json['confirmed_bookings'] ?? 0,
      inventoryCount: json['inventory_count'] ?? 0,
      featuredItems: json['featured_items'] ?? 0,
      lowStockItems: json['low_stock_items'] ?? 0,
      monthlyRevenue: (json['monthly_revenue'] ?? 0).toDouble(),
      confirmedRevenue: (json['confirmed_revenue'] ?? 0).toDouble(),
      lastBookingDate: json['last_booking_date'] != null 
          ? DateTime.parse(json['last_booking_date']) 
          : null,
      lastEventDate: json['last_event_date'] != null 
          ? DateTime.parse(json['last_event_date']) 
          : null,
      lastInventoryUpdate: json['last_inventory_update'] != null 
          ? DateTime.parse(json['last_inventory_update']) 
          : null,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'vendor_id': vendorId,
      'total_events': totalEvents,
      'upcoming_events': upcomingEvents,
      'active_events': activeEvents,
      'total_bookings': totalBookings,
      'monthly_bookings': monthlyBookings,
      'confirmed_bookings': confirmedBookings,
      'inventory_count': inventoryCount,
      'featured_items': featuredItems,
      'low_stock_items': lowStockItems,
      'monthly_revenue': monthlyRevenue,
      'confirmed_revenue': confirmedRevenue,
      'last_booking_date': lastBookingDate?.toIso8601String(),
      'last_event_date': lastEventDate?.toIso8601String(),
      'last_inventory_update': lastInventoryUpdate?.toIso8601String(),
    };
  }
}
