import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../shared/models/analytics_models.dart';
import '../../auth/providers/supabase_auth_provider.dart';

final organizerAnalyticsProvider = FutureProvider<OrganizerAnalytics>((ref) async {
  final user = ref.watch(currentVendorUserProvider);

  if (user == null) {
    throw Exception('User not authenticated');
  }

  final supabase = Supabase.instance.client;
  final userId = user.id;

  // Fetch data from v_organizer_analytics view
  final analyticsData = await supabase
      .from('v_organizer_analytics')
      .select()
      .eq('organizer_id', userId)
      .maybeSingle();

  // If no data exists (user has no events), return empty analytics
  if (analyticsData == null) {
    return const OrganizerAnalytics();
  }

  // Fetch recent inquiries
  final inquiriesData = await supabase
      .from('inquiries')
      .select('''
        id,
        event_id,
        customer_name,
        customer_email,
        customer_phone,
        message,
        status,
        created_at,
        events!inner(id, name)
      ''')
      .eq('events.user_id', userId)
      .order('created_at', ascending: false)
      .limit(10);

  // Fetch booking trends (last 7 days)
  final sevenDaysAgo = DateTime.now().subtract(const Duration(days: 6));
  final bookingTrendsData = await supabase
      .from('events_bookings')
      .select('created_at, total_amount, event_id, events!inner(user_id)')
      .eq('events.user_id', userId)
      .gte('created_at', sevenDaysAgo.toIso8601String())
      .order('created_at', ascending: true);

  // Process booking trends by day
  final Map<String, BookingTrend> trendsByDay = {};
  for (var booking in bookingTrendsData) {
    final date = DateTime.parse(booking['created_at']);
    final dateKey = DateTime(date.year, date.month, date.day).toIso8601String();

    if (!trendsByDay.containsKey(dateKey)) {
      trendsByDay[dateKey] = BookingTrend(
        date: DateTime.parse(dateKey),
        bookings: 0,
        revenue: 0,
      );
    }

    trendsByDay[dateKey] = BookingTrend(
      date: trendsByDay[dateKey]!.date,
      bookings: trendsByDay[dateKey]!.bookings + 1,
      revenue: trendsByDay[dateKey]!.revenue + (booking['total_amount'] ?? 0),
    );
  }

  // Convert inquiries data to model
  final recentInquiries = (inquiriesData as List).map((inq) {
    return InquiryModel(
      id: inq['id'],
      eventId: inq['event_id'],
      eventName: inq['events']['name'] ?? 'Unknown Event',
      customerName: inq['customer_name'],
      customerEmail: inq['customer_email'],
      customerPhone: inq['customer_phone'],
      message: inq['message'],
      status: inq['status'],
      createdAt: DateTime.parse(inq['created_at']),
    );
  }).toList();

  return OrganizerAnalytics(
    totalInquiries: analyticsData['total_inquiries'] ?? 0,
    pendingInquiries: analyticsData['pending_inquiries'] ?? 0,
    acceptedInquiries: analyticsData['accepted_inquiries'] ?? 0,
    rejectedInquiries: analyticsData['rejected_inquiries'] ?? 0,
    totalBookings: analyticsData['total_bookings'] ?? 0,
    confirmedBookings: analyticsData['confirmed_bookings'] ?? 0,
    pendingBookings: analyticsData['pending_bookings'] ?? 0,
    cancelledBookings: analyticsData['cancelled_bookings'] ?? 0,
    totalRevenue: (analyticsData['total_revenue'] ?? 0).toDouble(),
    pendingRevenue: (analyticsData['pending_revenue'] ?? 0).toDouble(),
    recentInquiries: recentInquiries,
    bookingTrends: trendsByDay.values.toList()..sort((a, b) => a.date.compareTo(b.date)),
  );
});

final revenueBreakdownProvider = FutureProvider<RevenueBreakdown>((ref) async {
  final user = ref.watch(currentVendorUserProvider);

  if (user == null) {
    throw Exception('User not authenticated');
  }

  final supabase = Supabase.instance.client;
  final userId = user.id;

  // Fetch revenue by event from view
  final revenueByEventData = await supabase
      .from('v_revenue_by_event')
      .select()
      .eq('organizer_id', userId);

  // Calculate totals by booking type
  double ticketSales = 0;
  double tableSales = 0;
  double bottleSales = 0;
  double vipSales = 0;

  for (var event in revenueByEventData) {
    ticketSales += (event['ticket_revenue'] ?? 0).toDouble();
    tableSales += (event['table_revenue'] ?? 0).toDouble();
    bottleSales += (event['bottle_revenue'] ?? 0).toDouble();
    vipSales += (event['vip_revenue'] ?? 0).toDouble();
  }

  // Convert to revenue by event model
  final revenueByEvent = (revenueByEventData as List).map((event) {
    return RevenueByEvent(
      eventId: event['event_id'],
      eventName: event['event_name'],
      revenue: (event['total_revenue'] ?? 0).toDouble(),
      bookings: event['booking_count'] ?? 0,
    );
  }).toList();

  // Fetch revenue by month (last 3 months)
  final threeMonthsAgo = DateTime.now().subtract(const Duration(days: 90));
  final bookingsByMonth = await supabase
      .from('events_bookings')
      .select('created_at, total_amount, status, event_id, events!inner(user_id)')
      .eq('events.user_id', userId)
      .eq('status', 'confirmed')
      .gte('created_at', threeMonthsAgo.toIso8601String())
      .order('created_at', ascending: true);

  // Group by month
  final Map<String, RevenueByMonth> monthlyRevenue = {};
  for (var booking in bookingsByMonth) {
    final date = DateTime.parse(booking['created_at']);
    final monthKey = '${date.year}-${date.month.toString().padLeft(2, '0')}';
    final monthName = _getMonthName(date.month);

    if (!monthlyRevenue.containsKey(monthKey)) {
      monthlyRevenue[monthKey] = RevenueByMonth(
        month: monthName,
        revenue: 0,
        bookings: 0,
      );
    }

    monthlyRevenue[monthKey] = RevenueByMonth(
      month: monthName,
      revenue: monthlyRevenue[monthKey]!.revenue + (booking['total_amount'] ?? 0).toDouble(),
      bookings: monthlyRevenue[monthKey]!.bookings + 1,
    );
  }

  final totalRevenue = ticketSales + tableSales + bottleSales + vipSales;

  return RevenueBreakdown(
    ticketSales: ticketSales,
    tableSales: tableSales,
    bottleSales: bottleSales,
    otherSales: vipSales,
    totalRevenue: totalRevenue,
    revenueByEvent: revenueByEvent,
    revenueByMonth: monthlyRevenue.values.toList(),
  );
});

final eventPerformanceInsightsProvider = FutureProvider<List<EventPerformanceInsights>>((ref) async {
  final user = ref.watch(currentVendorUserProvider);

  if (user == null) {
    throw Exception('User not authenticated');
  }

  final supabase = Supabase.instance.client;
  final userId = user.id;

  // Fetch event performance from view
  final performanceData = await supabase
      .from('v_event_performance')
      .select('''
        event_id,
        event_name,
        total_tickets,
        sold_tickets,
        rsvp_count,
        checked_in_count,
        conversion_rate,
        attendance_rate,
        revenue_per_ticket
      ''')
      .eq('user_id', userId);

  return (performanceData as List).map((event) {
    return EventPerformanceInsights(
      eventId: event['event_id'],
      eventName: event['event_name'],
      totalTickets: event['total_tickets'] ?? 0,
      soldTickets: event['sold_tickets'] ?? 0,
      rsvpCount: event['rsvp_count'] ?? 0,
      checkedInCount: event['checked_in_count'] ?? 0,
      conversionRate: (event['conversion_rate'] ?? 0).toDouble(),
      attendanceRate: (event['attendance_rate'] ?? 0).toDouble(),
      revenuePerTicket: (event['revenue_per_ticket'] ?? 0).toDouble(),
      salesByHour: const [],
      salesByDay: const [],
    );
  }).toList();
});

// Helper function to get month name
String _getMonthName(int month) {
  const months = [
    'January', 'February', 'March', 'April', 'May', 'June',
    'July', 'August', 'September', 'October', 'November', 'December'
  ];
  return months[month - 1];
}
