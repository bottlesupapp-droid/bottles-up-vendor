// Analytics and reporting models for the Bottles Up Vendor app

class OrganizerAnalytics {
  final int totalInquiries;
  final int pendingInquiries;
  final int acceptedInquiries;
  final int rejectedInquiries;
  final int totalBookings;
  final int confirmedBookings;
  final int pendingBookings;
  final int cancelledBookings;
  final double totalRevenue;
  final double pendingRevenue;
  final List<InquiryModel> recentInquiries;
  final List<BookingTrend> bookingTrends;

  const OrganizerAnalytics({
    this.totalInquiries = 0,
    this.pendingInquiries = 0,
    this.acceptedInquiries = 0,
    this.rejectedInquiries = 0,
    this.totalBookings = 0,
    this.confirmedBookings = 0,
    this.pendingBookings = 0,
    this.cancelledBookings = 0,
    this.totalRevenue = 0,
    this.pendingRevenue = 0,
    this.recentInquiries = const [],
    this.bookingTrends = const [],
  });

  factory OrganizerAnalytics.fromJson(Map<String, dynamic> json) {
    return OrganizerAnalytics(
      totalInquiries: json['total_inquiries'] as int? ?? 0,
      pendingInquiries: json['pending_inquiries'] as int? ?? 0,
      acceptedInquiries: json['accepted_inquiries'] as int? ?? 0,
      rejectedInquiries: json['rejected_inquiries'] as int? ?? 0,
      totalBookings: json['total_bookings'] as int? ?? 0,
      confirmedBookings: json['confirmed_bookings'] as int? ?? 0,
      pendingBookings: json['pending_bookings'] as int? ?? 0,
      cancelledBookings: json['cancelled_bookings'] as int? ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      pendingRevenue: (json['pending_revenue'] as num?)?.toDouble() ?? 0,
      recentInquiries: json['recent_inquiries'] != null
          ? (json['recent_inquiries'] as List)
              .map((e) => InquiryModel.fromJson(e))
              .toList()
          : [],
      bookingTrends: json['booking_trends'] != null
          ? (json['booking_trends'] as List)
              .map((e) => BookingTrend.fromJson(e))
              .toList()
          : [],
    );
  }
}

class InquiryModel {
  final String id;
  final String eventId;
  final String eventName;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final String message;
  final String status; // pending, accepted, rejected
  final DateTime createdAt;

  const InquiryModel({
    required this.id,
    required this.eventId,
    required this.eventName,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.message,
    required this.status,
    required this.createdAt,
  });

  factory InquiryModel.fromJson(Map<String, dynamic> json) {
    return InquiryModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      eventName: json['event_name'] as String? ?? 'Unknown Event',
      customerName: json['customer_name'] as String,
      customerEmail: json['customer_email'] as String,
      customerPhone: json['customer_phone'] as String?,
      message: json['message'] as String,
      status: json['status'] as String? ?? 'pending',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}

class BookingTrend {
  final DateTime date;
  final int bookings;
  final double revenue;

  const BookingTrend({
    required this.date,
    required this.bookings,
    required this.revenue,
  });

  factory BookingTrend.fromJson(Map<String, dynamic> json) {
    return BookingTrend(
      date: DateTime.parse(json['date'] as String),
      bookings: json['bookings'] as int,
      revenue: (json['revenue'] as num).toDouble(),
    );
  }
}

class RevenueBreakdown {
  final double ticketSales;
  final double tableSales;
  final double bottleSales;
  final double otherSales;
  final double totalRevenue;
  final List<RevenueByEvent> revenueByEvent;
  final List<RevenueByMonth> revenueByMonth;

  const RevenueBreakdown({
    required this.ticketSales,
    required this.tableSales,
    required this.bottleSales,
    required this.otherSales,
    required this.totalRevenue,
    this.revenueByEvent = const [],
    this.revenueByMonth = const [],
  });

  factory RevenueBreakdown.fromJson(Map<String, dynamic> json) {
    return RevenueBreakdown(
      ticketSales: (json['ticket_sales'] as num?)?.toDouble() ?? 0,
      tableSales: (json['table_sales'] as num?)?.toDouble() ?? 0,
      bottleSales: (json['bottle_sales'] as num?)?.toDouble() ?? 0,
      otherSales: (json['other_sales'] as num?)?.toDouble() ?? 0,
      totalRevenue: (json['total_revenue'] as num?)?.toDouble() ?? 0,
      revenueByEvent: json['revenue_by_event'] != null
          ? (json['revenue_by_event'] as List)
              .map((e) => RevenueByEvent.fromJson(e))
              .toList()
          : [],
      revenueByMonth: json['revenue_by_month'] != null
          ? (json['revenue_by_month'] as List)
              .map((e) => RevenueByMonth.fromJson(e))
              .toList()
          : [],
    );
  }
}

class RevenueByEvent {
  final String eventId;
  final String eventName;
  final double revenue;
  final int bookings;

  const RevenueByEvent({
    required this.eventId,
    required this.eventName,
    required this.revenue,
    required this.bookings,
  });

  factory RevenueByEvent.fromJson(Map<String, dynamic> json) {
    return RevenueByEvent(
      eventId: json['event_id'] as String,
      eventName: json['event_name'] as String,
      revenue: (json['revenue'] as num).toDouble(),
      bookings: json['bookings'] as int,
    );
  }
}

class RevenueByMonth {
  final String month;
  final double revenue;
  final int bookings;

  const RevenueByMonth({
    required this.month,
    required this.revenue,
    required this.bookings,
  });

  factory RevenueByMonth.fromJson(Map<String, dynamic> json) {
    return RevenueByMonth(
      month: json['month'] as String,
      revenue: (json['revenue'] as num).toDouble(),
      bookings: json['bookings'] as int,
    );
  }
}

class EventPerformanceInsights {
  final String eventId;
  final String eventName;
  final int totalTickets;
  final int soldTickets;
  final int rsvpCount;
  final int checkedInCount;
  final double conversionRate;
  final double attendanceRate;
  final double revenuePerTicket;
  final List<SalesByHour> salesByHour;
  final List<SalesByDay> salesByDay;

  const EventPerformanceInsights({
    required this.eventId,
    required this.eventName,
    required this.totalTickets,
    required this.soldTickets,
    required this.rsvpCount,
    required this.checkedInCount,
    required this.conversionRate,
    required this.attendanceRate,
    required this.revenuePerTicket,
    this.salesByHour = const [],
    this.salesByDay = const [],
  });

  factory EventPerformanceInsights.fromJson(Map<String, dynamic> json) {
    return EventPerformanceInsights(
      eventId: json['event_id'] as String,
      eventName: json['event_name'] as String,
      totalTickets: json['total_tickets'] as int,
      soldTickets: json['sold_tickets'] as int,
      rsvpCount: json['rsvp_count'] as int? ?? 0,
      checkedInCount: json['checked_in_count'] as int? ?? 0,
      conversionRate: (json['conversion_rate'] as num?)?.toDouble() ?? 0,
      attendanceRate: (json['attendance_rate'] as num?)?.toDouble() ?? 0,
      revenuePerTicket: (json['revenue_per_ticket'] as num?)?.toDouble() ?? 0,
      salesByHour: json['sales_by_hour'] != null
          ? (json['sales_by_hour'] as List)
              .map((e) => SalesByHour.fromJson(e))
              .toList()
          : [],
      salesByDay: json['sales_by_day'] != null
          ? (json['sales_by_day'] as List)
              .map((e) => SalesByDay.fromJson(e))
              .toList()
          : [],
    );
  }
}

class SalesByHour {
  final int hour;
  final int sales;

  const SalesByHour({required this.hour, required this.sales});

  factory SalesByHour.fromJson(Map<String, dynamic> json) {
    return SalesByHour(
      hour: json['hour'] as int,
      sales: json['sales'] as int,
    );
  }
}

class SalesByDay {
  final DateTime date;
  final int sales;

  const SalesByDay({required this.date, required this.sales});

  factory SalesByDay.fromJson(Map<String, dynamic> json) {
    return SalesByDay(
      date: DateTime.parse(json['date'] as String),
      sales: json['sales'] as int,
    );
  }
}

class GuestListEntry {
  final String id;
  final String name;
  final String? email;
  final String? phone;
  final String? ticketType;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final String? notes;

  const GuestListEntry({
    required this.id,
    required this.name,
    this.email,
    this.phone,
    this.ticketType,
    this.checkedIn = false,
    this.checkedInAt,
    this.notes,
  });

  factory GuestListEntry.fromJson(Map<String, dynamic> json) {
    return GuestListEntry(
      id: json['id'] as String,
      name: json['name'] as String,
      email: json['email'] as String?,
      phone: json['phone'] as String?,
      ticketType: json['ticket_type'] as String?,
      checkedIn: json['checked_in'] as bool? ?? false,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
      notes: json['notes'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'email': email,
      'phone': phone,
      'ticket_type': ticketType,
      'checked_in': checkedIn,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'notes': notes,
    };
  }
}

class ScheduledTicketRelease {
  final String id;
  final String eventId;
  final String name;
  final DateTime releaseDate;
  final int ticketQuantity;
  final double price;
  final bool isActive;
  final DateTime createdAt;

  const ScheduledTicketRelease({
    required this.id,
    required this.eventId,
    required this.name,
    required this.releaseDate,
    required this.ticketQuantity,
    required this.price,
    this.isActive = true,
    required this.createdAt,
  });

  factory ScheduledTicketRelease.fromJson(Map<String, dynamic> json) {
    return ScheduledTicketRelease(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      name: json['name'] as String,
      releaseDate: DateTime.parse(json['release_date'] as String),
      ticketQuantity: json['ticket_quantity'] as int,
      price: (json['price'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'name': name,
      'release_date': releaseDate.toIso8601String(),
      'ticket_quantity': ticketQuantity,
      'price': price,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
    };
  }
}

class VenueBoostPackage {
  final String id;
  final String venueId;
  final String packageType; // basic, premium, featured
  final DateTime startDate;
  final DateTime endDate;
  final double cost;
  final bool isActive;
  final int impressions;
  final int clicks;

  const VenueBoostPackage({
    required this.id,
    required this.venueId,
    required this.packageType,
    required this.startDate,
    required this.endDate,
    required this.cost,
    this.isActive = true,
    this.impressions = 0,
    this.clicks = 0,
  });

  factory VenueBoostPackage.fromJson(Map<String, dynamic> json) {
    return VenueBoostPackage(
      id: json['id'] as String,
      venueId: json['venue_id'] as String,
      packageType: json['package_type'] as String,
      startDate: DateTime.parse(json['start_date'] as String),
      endDate: DateTime.parse(json['end_date'] as String),
      cost: (json['cost'] as num).toDouble(),
      isActive: json['is_active'] as bool? ?? true,
      impressions: json['impressions'] as int? ?? 0,
      clicks: json['clicks'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'venue_id': venueId,
      'package_type': packageType,
      'start_date': startDate.toIso8601String(),
      'end_date': endDate.toIso8601String(),
      'cost': cost,
      'is_active': isActive,
      'impressions': impressions,
      'clicks': clicks,
    };
  }
}
