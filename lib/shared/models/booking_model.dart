// Booking model for ticket purchases and table reservations

enum BookingStatus {
  pending,
  confirmed,
  checkedIn,
  cancelled,
  refunded,
}

enum BookingType {
  ticket,
  table,
  bottle,
  vip,
}

class BookingModel {
  final String id;
  final String eventId;
  final String? eventName;
  final String userId;
  final String customerName;
  final String customerEmail;
  final String? customerPhone;
  final BookingType bookingType;
  final BookingStatus status;
  final int quantity;
  final double totalAmount;
  final double paidAmount;
  final String? ticketCode;
  final String? qrCode;
  final bool checkedIn;
  final DateTime? checkedInAt;
  final String? checkedInBy;
  final String? notes;
  final DateTime createdAt;
  final DateTime updatedAt;

  const BookingModel({
    required this.id,
    required this.eventId,
    this.eventName,
    required this.userId,
    required this.customerName,
    required this.customerEmail,
    this.customerPhone,
    required this.bookingType,
    required this.status,
    required this.quantity,
    required this.totalAmount,
    required this.paidAmount,
    this.ticketCode,
    this.qrCode,
    this.checkedIn = false,
    this.checkedInAt,
    this.checkedInBy,
    this.notes,
    required this.createdAt,
    required this.updatedAt,
  });

  factory BookingModel.fromJson(Map<String, dynamic> json) {
    return BookingModel(
      id: json['id'] as String,
      eventId: json['event_id'] as String,
      eventName: json['event_name'] as String?,
      userId: json['user_id'] as String,
      customerName: json['customer_name'] as String,
      customerEmail: json['customer_email'] as String,
      customerPhone: json['customer_phone'] as String?,
      bookingType: _parseBookingType(json['booking_type'] as String?),
      status: _parseBookingStatus(json['status'] as String?),
      quantity: json['quantity'] as int? ?? 1,
      totalAmount: (json['total_amount'] as num?)?.toDouble() ?? 0,
      paidAmount: (json['paid_amount'] as num?)?.toDouble() ?? 0,
      ticketCode: json['ticket_code'] as String?,
      qrCode: json['qr_code'] as String?,
      checkedIn: json['checked_in'] as bool? ?? false,
      checkedInAt: json['checked_in_at'] != null
          ? DateTime.parse(json['checked_in_at'] as String)
          : null,
      checkedInBy: json['checked_in_by'] as String?,
      notes: json['notes'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static BookingType _parseBookingType(String? type) {
    if (type == null) return BookingType.ticket;
    try {
      return BookingType.values.firstWhere((e) => e.name == type);
    } catch (_) {
      return BookingType.ticket;
    }
  }

  static BookingStatus _parseBookingStatus(String? status) {
    if (status == null) return BookingStatus.pending;
    try {
      return BookingStatus.values.firstWhere((e) => e.name == status);
    } catch (_) {
      return BookingStatus.pending;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'event_id': eventId,
      'event_name': eventName,
      'user_id': userId,
      'customer_name': customerName,
      'customer_email': customerEmail,
      'customer_phone': customerPhone,
      'booking_type': bookingType.name,
      'status': status.name,
      'quantity': quantity,
      'total_amount': totalAmount,
      'paid_amount': paidAmount,
      'ticket_code': ticketCode,
      'qr_code': qrCode,
      'checked_in': checkedIn,
      'checked_in_at': checkedInAt?.toIso8601String(),
      'checked_in_by': checkedInBy,
      'notes': notes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  BookingModel copyWith({
    String? id,
    String? eventId,
    String? eventName,
    String? userId,
    String? customerName,
    String? customerEmail,
    String? customerPhone,
    BookingType? bookingType,
    BookingStatus? status,
    int? quantity,
    double? totalAmount,
    double? paidAmount,
    String? ticketCode,
    String? qrCode,
    bool? checkedIn,
    DateTime? checkedInAt,
    String? checkedInBy,
    String? notes,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return BookingModel(
      id: id ?? this.id,
      eventId: eventId ?? this.eventId,
      eventName: eventName ?? this.eventName,
      userId: userId ?? this.userId,
      customerName: customerName ?? this.customerName,
      customerEmail: customerEmail ?? this.customerEmail,
      customerPhone: customerPhone ?? this.customerPhone,
      bookingType: bookingType ?? this.bookingType,
      status: status ?? this.status,
      quantity: quantity ?? this.quantity,
      totalAmount: totalAmount ?? this.totalAmount,
      paidAmount: paidAmount ?? this.paidAmount,
      ticketCode: ticketCode ?? this.ticketCode,
      qrCode: qrCode ?? this.qrCode,
      checkedIn: checkedIn ?? this.checkedIn,
      checkedInAt: checkedInAt ?? this.checkedInAt,
      checkedInBy: checkedInBy ?? this.checkedInBy,
      notes: notes ?? this.notes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
