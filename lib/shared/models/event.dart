class Event {
  final String id;
  final String name;
  final String? description;
  final String userId;
  final String? categoryId;
  final String? clubId;
  final String zoneId;
  final List<String>? images;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final double ticketPrice;
  final int maxCapacity;
  final int currentBookings;
  final bool isFeatured;
  final String status;
  final String? termsAndConditions;
  final String? specialInstructions;
  final bool isActive;
  final DateTime createdAt;
  final DateTime updatedAt;

  Event({
    required this.id,
    required this.name,
    this.description,
    required this.userId,
    this.categoryId,
    this.clubId,
    required this.zoneId,
    this.images,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.ticketPrice,
    required this.maxCapacity,
    this.currentBookings = 0,
    this.isFeatured = false,
    this.status = 'upcoming',
    this.termsAndConditions,
    this.specialInstructions,
    this.isActive = true,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Event.fromJson(Map<String, dynamic> json) {
    return Event(
      id: json['id'],
      name: json['name'],
      description: json['description'],
      userId: json['user_id'],
      categoryId: json['category_id'],
      clubId: json['club_id'],
      zoneId: json['zone_id'],
      images: json['images'] != null ? List<String>.from(json['images']) : null,
      eventDate: DateTime.parse(json['event_date']),
      startTime: json['start_time'],
      endTime: json['end_time'],
      ticketPrice: json['ticket_price'].toDouble(),
      maxCapacity: json['max_capacity'],
      currentBookings: json['current_bookings'] ?? 0,
      isFeatured: json['is_featured'] ?? false,
      status: json['status'] ?? 'upcoming',
      termsAndConditions: json['terms_and_conditions'],
      specialInstructions: json['special_instructions'],
      isActive: json['is_active'] ?? true,
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'user_id': userId,
      'category_id': categoryId,
      'club_id': clubId,
      'zone_id': zoneId,
      'images': images,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'ticket_price': ticketPrice,
      'max_capacity': maxCapacity,
      'current_bookings': currentBookings,
      'is_featured': isFeatured,
      'status': status,
      'terms_and_conditions': termsAndConditions,
      'special_instructions': specialInstructions,
      'is_active': isActive,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
    };
  }
}

class CreateEventRequest {
  final String name;
  final String? description;
  final String? categoryId;
  final String? clubId;
  final String zoneId;
  final List<String>? images;
  final DateTime eventDate;
  final String startTime;
  final String endTime;
  final double ticketPrice;
  final int maxCapacity;
  final String? termsAndConditions;
  final String? specialInstructions;

  CreateEventRequest({
    required this.name,
    this.description,
    this.categoryId,
    this.clubId,
    required this.zoneId,
    this.images,
    required this.eventDate,
    required this.startTime,
    required this.endTime,
    required this.ticketPrice,
    required this.maxCapacity,
    this.termsAndConditions,
    this.specialInstructions,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'description': description,
      'category_id': categoryId,
      'club_id': clubId,
      'zone_id': zoneId,
      'images': images,
      'event_date': eventDate.toIso8601String().split('T')[0],
      'start_time': startTime,
      'end_time': endTime,
      'ticket_price': ticketPrice,
      'max_capacity': maxCapacity,
      'terms_and_conditions': termsAndConditions,
      'special_instructions': specialInstructions,
    };
  }
}

class UpdateEventRequest {
  final String? name;
  final String? description;
  final String? categoryId;
  final String? clubId;
  final String? zoneId;
  final List<String>? images;
  final DateTime? eventDate;
  final String? startTime;
  final String? endTime;
  final double? ticketPrice;
  final int? maxCapacity;
  final int? currentBookings;
  final bool? isFeatured;
  final String? status;
  final String? termsAndConditions;
  final String? specialInstructions;
  final bool? isActive;

  UpdateEventRequest({
    this.name,
    this.description,
    this.categoryId,
    this.clubId,
    this.zoneId,
    this.images,
    this.eventDate,
    this.startTime,
    this.endTime,
    this.ticketPrice,
    this.maxCapacity,
    this.currentBookings,
    this.isFeatured,
    this.status,
    this.termsAndConditions,
    this.specialInstructions,
    this.isActive,
  });

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> json = {};
    if (name != null) json['name'] = name;
    if (description != null) json['description'] = description;
    if (categoryId != null) json['category_id'] = categoryId;
    if (clubId != null) json['club_id'] = clubId;
    if (zoneId != null) json['zone_id'] = zoneId;
    if (images != null) json['images'] = images;
    if (eventDate != null) json['event_date'] = eventDate!.toIso8601String().split('T')[0];
    if (startTime != null) json['start_time'] = startTime;
    if (endTime != null) json['end_time'] = endTime;
    if (ticketPrice != null) json['ticket_price'] = ticketPrice;
    if (maxCapacity != null) json['max_capacity'] = maxCapacity;
    if (currentBookings != null) json['current_bookings'] = currentBookings;
    if (isFeatured != null) json['is_featured'] = isFeatured;
    if (status != null) json['status'] = status;
    if (termsAndConditions != null) json['terms_and_conditions'] = termsAndConditions;
    if (specialInstructions != null) json['special_instructions'] = specialInstructions;
    if (isActive != null) json['is_active'] = isActive;
    return json;
  }
}
