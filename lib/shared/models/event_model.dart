// Event model matching Supabase database schema

enum EventStatus {
  draft,
  published,
  upcoming,
  live,
  ongoing,
  completed,
  cancelled,
}

class EventModel {
  final String id;
  final String name;
  final String? description;
  final String? categoryId;
  final String? clubId;
  final String? zoneId;
  final DateTime eventDate;
  final String? startTime;
  final String? endTime;
  final double ticketPrice;
  final int maxCapacity;
  final int currentBookings;
  final int rsvpCount;
  final int tableBookingCount;
  final double revenue;
  final int salesCount;
  final List<String> images;
  final String? flyerImageUrl;
  final String? tableArrangementImageUrl;
  final EventStatus status;
  final bool isFeatured;
  final bool isActive;
  final bool isPrivate;
  final bool locationHidden;
  final String? invitationCode;
  final String? city;
  final String? dressCode;
  final String? termsAndConditions;
  final String? specialInstructions;
  final String userId; // Event organizer
  final String? templateId;
  final DateTime createdAt;
  final DateTime updatedAt;

  const EventModel({
    required this.id,
    required this.name,
    this.description,
    this.categoryId,
    this.clubId,
    this.zoneId,
    required this.eventDate,
    this.startTime,
    this.endTime,
    this.ticketPrice = 0,
    this.maxCapacity = 100,
    this.currentBookings = 0,
    this.rsvpCount = 0,
    this.tableBookingCount = 0,
    this.revenue = 0,
    this.salesCount = 0,
    this.images = const [],
    this.flyerImageUrl,
    this.tableArrangementImageUrl,
    this.status = EventStatus.draft,
    this.isFeatured = false,
    this.isActive = true,
    this.isPrivate = false,
    this.locationHidden = false,
    this.invitationCode,
    this.city,
    this.dressCode,
    this.termsAndConditions,
    this.specialInstructions,
    required this.userId,
    this.templateId,
    required this.createdAt,
    required this.updatedAt,
  });

  factory EventModel.fromJson(Map<String, dynamic> json) {
    return EventModel(
      id: json['id'] as String,
      name: json['name'] as String,
      description: json['description'] as String?,
      categoryId: json['category_id'] as String?,
      clubId: json['club_id'] as String?,
      zoneId: json['zone_id'] as String?,
      eventDate: DateTime.parse(json['event_date'] as String),
      startTime: json['start_time'] as String?,
      endTime: json['end_time'] as String?,
      ticketPrice: (json['ticket_price'] as num?)?.toDouble() ?? 0,
      maxCapacity: json['max_capacity'] as int? ?? 100,
      currentBookings: json['current_bookings'] as int? ?? 0,
      rsvpCount: json['rsvp_count'] as int? ?? 0,
      tableBookingCount: json['table_booking_count'] as int? ?? 0,
      revenue: (json['revenue'] as num?)?.toDouble() ?? 0,
      salesCount: json['sales_count'] as int? ?? 0,
      images: json['images'] != null ? List<String>.from(json['images']) : [],
      flyerImageUrl: json['flyer_image_url'] as String?,
      tableArrangementImageUrl: json['table_arrangement_image_url'] as String?,
      status: _parseEventStatus(json['status'] as String?),
      isFeatured: json['is_featured'] as bool? ?? false,
      isActive: json['is_active'] as bool? ?? true,
      isPrivate: json['is_private'] as bool? ?? false,
      locationHidden: json['location_hidden'] as bool? ?? false,
      invitationCode: json['invitation_code'] as String?,
      city: json['city'] as String?,
      dressCode: json['dress_code'] as String?,
      termsAndConditions: json['terms_and_conditions'] as String?,
      specialInstructions: json['special_instructions'] as String?,
      userId: json['user_id'] as String,
      templateId: json['template_id'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
      updatedAt: DateTime.parse(json['updated_at'] as String),
    );
  }

  static EventStatus _parseEventStatus(String? status) {
    if (status == null) return EventStatus.draft;
    try {
      return EventStatus.values.firstWhere((e) => e.name == status);
    } catch (_) {
      return EventStatus.draft;
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'category_id': categoryId,
      'club_id': clubId,
      'zone_id': zoneId,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'ticket_price': ticketPrice,
      'max_capacity': maxCapacity,
      'current_bookings': currentBookings,
      'rsvp_count': rsvpCount,
      'table_booking_count': tableBookingCount,
      'revenue': revenue,
      'sales_count': salesCount,
      'images': images,
      'flyer_image_url': flyerImageUrl,
      'table_arrangement_image_url': tableArrangementImageUrl,
      'status': status.name,
      'is_featured': isFeatured,
      'is_active': isActive,
      'is_private': isPrivate,
      'location_hidden': locationHidden,
      'invitation_code': invitationCode,
      'city': city,
      'dress_code': dressCode,
      'terms_and_conditions': termsAndConditions,
      'special_instructions': specialInstructions,
      'user_id': userId,
      'template_id': templateId,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }

  // Helper getters
  bool get isDraft => status == EventStatus.draft;
  bool get isPublished => status == EventStatus.published;
  bool get isUpcoming => status == EventStatus.upcoming;
  bool get isLive => status == EventStatus.live;
  bool get isOngoing => status == EventStatus.ongoing;
  bool get isCompleted => status == EventStatus.completed;
  bool get isCancelled => status == EventStatus.cancelled;

  bool get isPast => isCompleted || isCancelled;
  bool get isActiveEvent => isPublished || isUpcoming || isLive || isOngoing;

  double get occupancyRate => maxCapacity > 0 ? (currentBookings / maxCapacity) * 100 : 0;
  int get availableCapacity => maxCapacity - currentBookings;

  EventModel copyWith({
    String? id,
    String? name,
    String? description,
    String? categoryId,
    String? clubId,
    String? zoneId,
    DateTime? eventDate,
    String? startTime,
    String? endTime,
    double? ticketPrice,
    int? maxCapacity,
    int? currentBookings,
    int? rsvpCount,
    int? tableBookingCount,
    double? revenue,
    int? salesCount,
    List<String>? images,
    String? flyerImageUrl,
    String? tableArrangementImageUrl,
    EventStatus? status,
    bool? isFeatured,
    bool? isActive,
    bool? isPrivate,
    bool? locationHidden,
    String? invitationCode,
    String? city,
    String? dressCode,
    String? termsAndConditions,
    String? specialInstructions,
    String? userId,
    String? templateId,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EventModel(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      categoryId: categoryId ?? this.categoryId,
      clubId: clubId ?? this.clubId,
      zoneId: zoneId ?? this.zoneId,
      eventDate: eventDate ?? this.eventDate,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      ticketPrice: ticketPrice ?? this.ticketPrice,
      maxCapacity: maxCapacity ?? this.maxCapacity,
      currentBookings: currentBookings ?? this.currentBookings,
      rsvpCount: rsvpCount ?? this.rsvpCount,
      tableBookingCount: tableBookingCount ?? this.tableBookingCount,
      revenue: revenue ?? this.revenue,
      salesCount: salesCount ?? this.salesCount,
      images: images ?? this.images,
      flyerImageUrl: flyerImageUrl ?? this.flyerImageUrl,
      tableArrangementImageUrl: tableArrangementImageUrl ?? this.tableArrangementImageUrl,
      status: status ?? this.status,
      isFeatured: isFeatured ?? this.isFeatured,
      isActive: isActive ?? this.isActive,
      isPrivate: isPrivate ?? this.isPrivate,
      locationHidden: locationHidden ?? this.locationHidden,
      invitationCode: invitationCode ?? this.invitationCode,
      city: city ?? this.city,
      dressCode: dressCode ?? this.dressCode,
      termsAndConditions: termsAndConditions ?? this.termsAndConditions,
      specialInstructions: specialInstructions ?? this.specialInstructions,
      userId: userId ?? this.userId,
      templateId: templateId ?? this.templateId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  String toString() {
    return 'EventModel(id: $id, name: $name, status: ${status.name}, date: $eventDate)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is EventModel && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;
}

class CreateEventRequest {
  final String title;
  final String description;
  final String clubId;
  final DateTime startDateTime;
  final DateTime endDateTime;
  final String location;
  final String address;
  final String? ticketUrl;
  final double ticketPrice;
  final int maxCapacity;
  final List<String> tags;

  const CreateEventRequest({
    required this.title,
    required this.description,
    required this.clubId,
    required this.startDateTime,
    required this.endDateTime,
    required this.location,
    required this.address,
    this.ticketUrl,
    this.ticketPrice = 0.0,
    required this.maxCapacity,
    this.tags = const [],
  });

  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'description': description,
      'clubId': clubId,
      'startDateTime': startDateTime.toIso8601String(),
      'endDateTime': endDateTime.toIso8601String(),
      'location': location,
      'address': address,
      'ticketUrl': ticketUrl,
      'ticketPrice': ticketPrice,
      'maxCapacity': maxCapacity,
      'tags': tags,
    };
  }
} 